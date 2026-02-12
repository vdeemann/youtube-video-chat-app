defmodule YoutubeVideoChatApp.Rooms.RoomServer do
  @moduledoc """
  GenServer for managing room state and video synchronization.
  
  Uses a DJ line system for fair turn-taking:
  - Users join the line when they add their first track
  - Each user gets one track played before the next user's turn
  - After playing, the DJ goes to the back of the line
  - When a user's personal queue is empty, they leave the line
  
  Automatically terminates after 30 minutes of inactivity.
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  # Terminate room server after 30 minutes of no activity
  @idle_timeout :timer.minutes(30)

  defstruct [
    :room_id,
    :current_media,    # Currently playing media
    :current_dj,       # User ID of the current DJ
    :video_state,      # playing/paused
    :video_timestamp,  # current playback position
    :video_started_at, # When the current video started playing
    :dj_line,          # Ordered list of {user_id, username, color} — the turn order
    :user_queues,      # %{user_id => [media, ...]} — each user's personal queue
    :host_id,
    :viewers,
    :last_sync,
    :messages          # Recent chat messages (last 50)
  ]

  # Client API

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, 
      name: via_tuple(room_id))
  end

  defp via_tuple(room_id) do
    {:via, Registry, {YoutubeVideoChatApp.RoomRegistry, room_id}}
  end

  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def sync_video(room_id, timestamp, state, user_id) do
    GenServer.cast(via_tuple(room_id), 
      {:sync_video, timestamp, state, user_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def add_to_queue(room_id, media_data, user) do
    GenServer.call(via_tuple(room_id), 
      {:add_to_queue, media_data, user})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def play_next(room_id) do
    GenServer.call(via_tuple(room_id), :play_next)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def remove_from_queue(room_id, media_id) do
    GenServer.cast(via_tuple(room_id), {:remove_from_queue, media_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def remove_from_queue_by_user(room_id, media_id, user_id) do
    GenServer.cast(via_tuple(room_id), {:remove_from_queue_by_user, media_id, user_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def add_multiple_to_queue(room_id, media_items, user) do
    GenServer.call(via_tuple(room_id), {:add_multiple_to_queue, media_items, user})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def update_video_progress(room_id, current_time, duration) do
    GenServer.cast(via_tuple(room_id), 
      {:update_progress, current_time, duration})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def add_message(room_id, message) do
    GenServer.cast(via_tuple(room_id), {:add_message, message})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def get_messages(room_id) do
    GenServer.call(via_tuple(room_id), :get_messages)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  # Server Callbacks

  @impl true
  def init(room_id) do
    Logger.debug("RoomServer starting for room #{room_id}")
    
    room = YoutubeVideoChatApp.Rooms.get_room!(room_id)
    
    state = %__MODULE__{
      room_id: room_id,
      current_media: nil,
      current_dj: nil,
      video_state: "paused",
      video_timestamp: 0,
      video_started_at: nil,
      dj_line: [],
      user_queues: %{},
      host_id: room.host_id,
      viewers: MapSet.new(),
      last_sync: System.monotonic_time(:second),
      messages: []
    }
    
    {:ok, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Build a flat queue for backward compatibility with the LiveView
    queue = build_flat_queue(state)
    
    dj_line_info = Enum.map(state.dj_line, fn {uid, username, color} ->
      track_count = length(Map.get(state.user_queues, uid, []))
      %{user_id: uid, username: username, color: color, track_count: track_count}
    end)
    
    compat_state = %{
      current_media: state.current_media,
      video_state: state.video_state,
      video_timestamp: state.video_timestamp,
      video_started_at: state.video_started_at,
      queue: queue,
      dj_line: dj_line_info,
      user_queues: state.user_queues,
      current_dj: state.current_dj
    }
    
    {:reply, {:ok, compat_state}, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, {:ok, state.messages || []}, state, @idle_timeout}
  end

  @impl true
  def handle_call({:add_to_queue, media_data, user}, _from, state) do
    media = build_media(media_data, user)
    
    Logger.debug("Adding to queue: #{media.title} by #{user.username}")
    
    # Add track to this user's personal queue
    user_queue = Map.get(state.user_queues, user.id, [])
    new_user_queues = Map.put(state.user_queues, user.id, user_queue ++ [media])
    
    # Add user to DJ line if not already in it
    new_dj_line = if in_dj_line?(state.dj_line, user.id) do
      state.dj_line
    else
      state.dj_line ++ [{user.id, user.username, user.color}]
    end
    
    new_state = %{state | user_queues: new_user_queues, dj_line: new_dj_line}
    
    # If nothing is playing, start immediately
    new_state = if is_nil(state.current_media) do
      play_from_next_dj(new_state)
    else
      broadcast_full_update(new_state)
      new_state
    end
    
    {:reply, {:ok, media}, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:play_next, _from, state) do
    Logger.debug("play_next called")
    
    # Move current DJ to back of line, advance to next
    new_state = advance_to_next(state)
    
    {:reply, :ok, new_state, @idle_timeout}
  end

  @impl true
  def handle_call({:add_multiple_to_queue, media_items, user}, _from, state) do
    Logger.debug("Adding #{length(media_items)} items from playlist by #{user.username}")
    
    converted_items = Enum.map(media_items, fn item -> build_media(item, user) end)
    
    # Add all tracks to this user's personal queue
    user_queue = Map.get(state.user_queues, user.id, [])
    new_user_queues = Map.put(state.user_queues, user.id, user_queue ++ converted_items)
    
    # Add user to DJ line if not already in it
    new_dj_line = if in_dj_line?(state.dj_line, user.id) do
      state.dj_line
    else
      state.dj_line ++ [{user.id, user.username, user.color}]
    end
    
    new_state = %{state | user_queues: new_user_queues, dj_line: new_dj_line}
    
    # If nothing is playing, start immediately
    new_state = if is_nil(state.current_media) do
      play_from_next_dj(new_state)
    else
      broadcast_full_update(new_state)
      new_state
    end
    
    {:reply, {:ok, length(converted_items)}, new_state, @idle_timeout}
  end

  @impl true
  def handle_cast({:remove_from_queue, media_id}, state) do
    Logger.debug("Removing media from queue: #{media_id}")
    
    # Remove from whichever user's queue it belongs to
    new_user_queues = Enum.into(state.user_queues, %{}, fn {uid, tracks} ->
      {uid, Enum.reject(tracks, &(&1.id == media_id))}
    end)
    
    # Clean up: remove users with empty queues from the DJ line
    # (but keep current DJ even if their queue is empty — they're playing)
    new_state = %{state | user_queues: new_user_queues}
    |> cleanup_dj_line()
    
    broadcast_full_update(new_state)
    {:noreply, new_state, @idle_timeout}
  end

  @impl true
  def handle_cast({:remove_from_queue_by_user, media_id, user_id}, state) do
    Logger.debug("User #{user_id} removing media #{media_id}")
    
    user_queue = Map.get(state.user_queues, user_id, [])
    new_queue = Enum.reject(user_queue, &(&1.id == media_id))
    
    if length(new_queue) < length(user_queue) do
      new_user_queues = Map.put(state.user_queues, user_id, new_queue)
      new_state = %{state | user_queues: new_user_queues}
      |> cleanup_dj_line()
      
      broadcast_full_update(new_state)
      {:noreply, new_state, @idle_timeout}
    else
      {:noreply, state, @idle_timeout}
    end
  end

  @impl true
  def handle_cast({:update_progress, current_time, _duration}, state) do
    {:noreply, %{state | video_timestamp: current_time}, @idle_timeout}
  end

  @impl true
  def handle_cast({:add_message, message}, state) do
    messages = [message | (state.messages || [])] |> Enum.take(50)
    {:noreply, %{state | messages: messages}, @idle_timeout}
  end

  @impl true
  def handle_cast({:sync_video, timestamp, video_state, user_id}, state) do
    if user_id == state.host_id do
      now = System.monotonic_time(:second)
      
      PubSub.broadcast(
        YoutubeVideoChatApp.PubSub, 
        "room:#{state.room_id}", 
        {:video_sync, timestamp, video_state}
      )
      
      {:noreply, %{state | 
        video_timestamp: timestamp, 
        video_state: video_state,
        last_sync: now
      }, @idle_timeout}
    else
      {:noreply, state, @idle_timeout}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("RoomServer #{state.room_id} idle timeout - terminating")
    {:stop, :normal, state}
  end

  # ============================================================================
  # Private: DJ Line Logic
  # ============================================================================

  # Play the next track from the first DJ in line
  defp play_from_next_dj(state) do
    case state.dj_line do
      [{user_id, _username, _color} | _rest] ->
        user_queue = Map.get(state.user_queues, user_id, [])
        
        case user_queue do
          [next_track | remaining] ->
            new_user_queues = Map.put(state.user_queues, user_id, remaining)
            
            new_state = %{state | 
              current_media: next_track,
              current_dj: user_id,
              video_state: "playing",
              video_timestamp: 0,
              video_started_at: DateTime.utc_now(),
              user_queues: new_user_queues
            }
            
            queue = build_flat_queue(new_state)
            broadcast_media_change(state.room_id, next_track)
            broadcast_queue_update(state.room_id, queue)
            broadcast_play_next(state.room_id, next_track, queue)
            broadcast_dj_line_update(new_state)
            
            new_state
          
          [] ->
            # This DJ has no tracks, remove them and try next
            new_dj_line = remove_from_dj_line(state.dj_line, user_id)
            new_user_queues = Map.delete(state.user_queues, user_id)
            play_from_next_dj(%{state | dj_line: new_dj_line, user_queues: new_user_queues})
        end
      
      [] ->
        # No DJs in line, stop playback
        new_state = %{state | 
          current_media: nil,
          current_dj: nil,
          video_state: "paused",
          video_timestamp: 0,
          video_started_at: nil
        }
        
        broadcast_media_change(state.room_id, nil)
        broadcast_queue_update(state.room_id, [])
        broadcast_play_next(state.room_id, nil, [])
        broadcast_dj_line_update(new_state)
        
        new_state
    end
  end

  # Current DJ's track ended — move them to back of line, play next DJ
  defp advance_to_next(state) do
    case state.dj_line do
      [current_dj_tuple | rest] ->
        {dj_id, _, _} = current_dj_tuple
        remaining_tracks = Map.get(state.user_queues, dj_id, [])
        
        # If current DJ still has tracks, move to back of line
        # Otherwise, remove them from the line and clean up their queue
        {new_dj_line, new_user_queues} = if length(remaining_tracks) > 0 do
          {rest ++ [current_dj_tuple], state.user_queues}
        else
          {rest, Map.delete(state.user_queues, dj_id)}
        end
        
        new_state = %{state | dj_line: new_dj_line, user_queues: new_user_queues}
        play_from_next_dj(new_state)
      
      [] ->
        play_from_next_dj(state)
    end
  end

  # Build a flat queue for display: walk the DJ line round-robin, 
  # taking one track from each DJ per round
  defp build_flat_queue(state) do
    build_flat_queue_recursive(state.dj_line, state.user_queues, [])
  end

  defp build_flat_queue_recursive(dj_line, user_queues, acc) do
    # One pass through the DJ line, taking 1 track from each
    {round_tracks, remaining_queues, has_more} = 
      Enum.reduce(dj_line, {[], user_queues, false}, fn {uid, _name, _color}, {tracks, queues, more} ->
        case Map.get(queues, uid, []) do
          [track | rest] ->
            {tracks ++ [track], Map.put(queues, uid, rest), true}
          [] ->
            {tracks, queues, more}
        end
      end)
    
    new_acc = acc ++ round_tracks
    
    if has_more do
      build_flat_queue_recursive(dj_line, remaining_queues, new_acc)
    else
      new_acc
    end
  end

  # Remove users from DJ line who have no tracks left (excluding current DJ)
  defp cleanup_dj_line(state) do
    new_dj_line = Enum.filter(state.dj_line, fn {uid, _, _} ->
      uid == state.current_dj || length(Map.get(state.user_queues, uid, [])) > 0
    end)
    %{state | dj_line: new_dj_line}
  end

  defp in_dj_line?(dj_line, user_id) do
    Enum.any?(dj_line, fn {uid, _, _} -> uid == user_id end)
  end

  defp remove_from_dj_line(dj_line, user_id) do
    Enum.reject(dj_line, fn {uid, _, _} -> uid == user_id end)
  end

  defp build_media(media_data, user) do
    %{
      id: Ecto.UUID.generate(),
      type: media_data["type"] || media_data[:type],
      media_id: media_data["media_id"] || media_data[:media_id],
      title: media_data["title"] || media_data[:title] || "Unknown",
      thumbnail: media_data["thumbnail"] || media_data[:thumbnail],
      duration: media_data["duration"] || media_data[:duration] || 300,
      embed_url: media_data["embed_url"] || media_data[:embed_url],
      original_url: media_data["original_url"] || media_data[:original_url],
      added_by_username: user.username,
      added_by_id: user.id,
      added_at: DateTime.utc_now()
    }
  end

  # ============================================================================
  # Broadcasting
  # ============================================================================

  defp broadcast_full_update(state) do
    queue = build_flat_queue(state)
    broadcast_queue_update(state.room_id, queue)
    broadcast_dj_line_update(state)
  end

  defp broadcast_media_change(room_id, media) do
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:media_changed, media}
    )
  end

  defp broadcast_queue_update(room_id, queue) do
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:queue_updated, queue}
    )
  end

  defp broadcast_play_next(room_id, media, queue) do
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:play_next, media, queue}
    )
  end

  defp broadcast_dj_line_update(state) do
    # Send DJ line info along with per-user track counts
    dj_line_info = Enum.map(state.dj_line, fn {uid, username, color} ->
      track_count = length(Map.get(state.user_queues, uid, []))
      %{user_id: uid, username: username, color: color, track_count: track_count}
    end)
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{state.room_id}",
      {:dj_line_updated, dj_line_info, state.current_dj}
    )
  end
end
