defmodule YoutubeVideoChatApp.Rooms.RoomServer do
  @moduledoc """
  GenServer for managing room state and video synchronization.
  
  Automatically terminates after 30 minutes of inactivity (no viewers)
  to prevent memory leaks from orphaned room processes.
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  # Terminate room server after 30 minutes of no activity
  @idle_timeout :timer.minutes(30)

  defstruct [
    :room_id,
    :current_media,    # Currently playing media
    :video_state,      # playing/paused
    :video_timestamp,  # current playback position
    :video_started_at, # When the current video started playing
    :queue,           # upcoming media queue (not including current)
    :host_id,
    :viewers,
    :last_sync,
    :messages         # Recent chat messages (last 50)
  ]

  # Client API

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, 
      name: via_tuple(room_id))
  end

  # Use Registry for faster process lookup (vs :global)
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
    
    # Load room from database if exists
    room = YoutubeVideoChatApp.Rooms.get_room!(room_id)
    
    state = %__MODULE__{
      room_id: room_id,
      current_media: nil,
      video_state: "paused",
      video_timestamp: 0,
      video_started_at: nil,
      queue: [],
      host_id: room.host_id,
      viewers: MapSet.new(),
      last_sync: System.monotonic_time(:second),
      messages: []
    }
    
    # Start with idle timeout - will terminate if no activity
    {:ok, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, {:ok, state.messages || []}, state, @idle_timeout}
  end

  @impl true
  def handle_call({:add_to_queue, media_data, user}, _from, state) do
    # Convert all keys to atoms for consistency
    media = %{
      id: Ecto.UUID.generate(),
      type: media_data["type"] || media_data[:type],
      media_id: media_data["media_id"] || media_data[:media_id],
      title: media_data["title"] || media_data[:title] || "Unknown",
      thumbnail: media_data["thumbnail"] || media_data[:thumbnail],
      duration: media_data["duration"] || media_data[:duration] || 180,
      embed_url: media_data["embed_url"] || media_data[:embed_url],
      original_url: media_data["original_url"] || media_data[:original_url],
      added_by_username: user.username,
      added_by_id: user.id,
      added_at: DateTime.utc_now()
    }
    
    Logger.debug("Adding to queue: #{media.title} (#{media.type})")
    
    # If no media is currently playing, start this one immediately
    new_state = if is_nil(state.current_media) do
      # Broadcast to all clients in proper order
      broadcast_media_change(state.room_id, media)
      broadcast_queue_update(state.room_id, state.queue)
      broadcast_play_next(state.room_id, media, state.queue)
      
      Logger.debug("Now playing: #{media.title}")
      
      %{state | 
        current_media: media, 
        video_state: "playing",
        video_timestamp: 0,
        video_started_at: DateTime.utc_now()
      }
    else
      # Add to queue (prepend for O(1), reverse when reading)
      new_queue = state.queue ++ [media]
      Logger.debug("Queue size: #{length(new_queue)}")
      
      broadcast_queue_update(state.room_id, new_queue)
      %{state | queue: new_queue}
    end
    
    {:reply, {:ok, media}, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:play_next, _from, state) do
    Logger.debug("play_next called, queue size: #{length(state.queue)}")
    
    case state.queue do
      [next | rest] ->
        Logger.debug("Advancing to: #{next.title}")
        
        # UPDATE STATE FIRST before broadcasting
        new_state = %{state | 
          current_media: next,
          queue: rest,
          video_state: "playing",
          video_timestamp: 0,
          video_started_at: DateTime.utc_now()
        }
        
        # Now broadcast with the correct updated queue
        broadcast_media_change(state.room_id, next)
        broadcast_queue_update(state.room_id, rest)
        broadcast_play_next(state.room_id, next, rest)
        
        {:reply, :ok, new_state, @idle_timeout}
      
      [] ->
        Logger.debug("Queue empty, stopping playback")
        
        # Update state first
        new_state = %{state | 
          current_media: nil,
          video_state: "paused",
          video_timestamp: 0,
          video_started_at: nil,
          queue: []
        }
        
        # Then broadcast
        broadcast_media_change(state.room_id, nil)
        broadcast_queue_update(state.room_id, [])
        broadcast_play_next(state.room_id, nil, [])
        
        {:reply, :ok, new_state, @idle_timeout}
    end
  end

  @impl true
  def handle_call({:add_multiple_to_queue, media_items, user}, _from, state) do
    Logger.debug("Adding #{length(media_items)} items from playlist")
    
    # Convert all items to the proper format
    converted_items = Enum.map(media_items, fn item ->
      %{
        id: Ecto.UUID.generate(),
        type: item[:type] || item["type"],
        media_id: item[:media_id] || item["media_id"],
        title: item[:title] || item["title"] || "Unknown",
        thumbnail: item[:thumbnail] || item["thumbnail"],
        duration: item[:duration] || item["duration"] || 180,
        embed_url: item[:embed_url] || item["embed_url"],
        original_url: item[:original_url] || item["original_url"],
        added_by_username: user.username,
        added_by_id: user.id,
        added_at: DateTime.utc_now()
      }
    end)
    
    # If nothing is playing, start the first one immediately
    new_state = if is_nil(state.current_media) and length(converted_items) > 0 do
      [first | rest] = converted_items
      new_queue = state.queue ++ rest
      
      Logger.debug("Starting first track: #{first.title}, #{length(rest)} more queued")
      
      broadcast_media_change(state.room_id, first)
      broadcast_queue_update(state.room_id, new_queue)
      broadcast_play_next(state.room_id, first, new_queue)
      
      %{state | 
        current_media: first, 
        video_state: "playing",
        video_timestamp: 0,
        video_started_at: DateTime.utc_now(),
        queue: new_queue
      }
    else
      # Add all to queue
      new_queue = state.queue ++ converted_items
      Logger.debug("Queue size now: #{length(new_queue)}")
      
      broadcast_queue_update(state.room_id, new_queue)
      %{state | queue: new_queue}
    end
    
    {:reply, {:ok, length(converted_items)}, new_state, @idle_timeout}
  end

  @impl true
  def handle_cast({:remove_from_queue, media_id}, state) do
    Logger.debug("Removing media from queue: #{media_id}")
    
    new_queue = Enum.reject(state.queue, fn media -> 
      media.id == media_id
    end)
    
    broadcast_queue_update(state.room_id, new_queue)
    {:noreply, %{state | queue: new_queue}, @idle_timeout}
  end

  @impl true
  def handle_cast({:update_progress, current_time, _duration}, state) do
    # Update video progress from client (for UI display only)
    # JavaScript video_ended event handles advancement
    {:noreply, %{state | video_timestamp: current_time}, @idle_timeout}
  end

  @impl true
  def handle_cast({:add_message, message}, state) do
    # Add message to the front, keep only last 50
    messages = [message | (state.messages || [])] |> Enum.take(50)
    {:noreply, %{state | messages: messages}, @idle_timeout}
  end

  @impl true
  def handle_cast({:sync_video, timestamp, video_state, user_id}, state) do
    # Only allow host to sync
    if user_id == state.host_id do
      now = System.monotonic_time(:second)
      
      # Always broadcast sync for real-time updates
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

  # Handle idle timeout - terminate if no activity
  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("RoomServer #{state.room_id} idle timeout - terminating")
    {:stop, :normal, state}
  end

  # Private functions

  defp broadcast_media_change(room_id, media) do
    Logger.debug("Broadcasting media change: #{inspect(media && media.title)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:media_changed, media}
    )
  end

  defp broadcast_queue_update(room_id, queue) do
    Logger.debug("Broadcasting queue update, size: #{length(queue)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:queue_updated, queue}
    )
  end

  defp broadcast_play_next(room_id, media, queue) do
    Logger.debug("Broadcasting play_next: #{inspect(media && media.title)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:play_next, media, queue}
    )
  end
end
