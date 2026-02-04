defmodule YoutubeVideoChatApp.Rooms.RoomServer do
  @moduledoc """
  GenServer for managing room state and video synchronization
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

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
    :check_timer      # Timer reference for checking video progress
  ]

  # Client API

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, 
      name: {:global, {:room, room_id}})
  end

  def get_state(room_id) do
    GenServer.call({:global, {:room, room_id}}, :get_state)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def sync_video(room_id, timestamp, state, user_id) do
    GenServer.cast({:global, {:room, room_id}}, 
      {:sync_video, timestamp, state, user_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def add_to_queue(room_id, media_data, user) do
    GenServer.call({:global, {:room, room_id}}, 
      {:add_to_queue, media_data, user})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def play_next(room_id) do
    GenServer.call({:global, {:room, room_id}}, :play_next)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def remove_from_queue(room_id, media_id) do
    GenServer.cast({:global, {:room, room_id}}, {:remove_from_queue, media_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def start_bandcamp_timer(room_id) do
    GenServer.call({:global, {:room, room_id}}, :start_bandcamp_timer)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  def update_video_progress(room_id, current_time, duration) do
    GenServer.cast({:global, {:room, room_id}}, 
      {:update_progress, current_time, duration})
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  # Server Callbacks

  @impl true
  def init(room_id) do
    Logger.info("RoomServer starting for room #{room_id}")
    
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
      check_timer: nil
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(:start_bandcamp_timer, _from, state) do
    Logger.info("\n========================================")
    Logger.info("▶️ START_BANDCAMP_TIMER CALLED")
    Logger.info("========================================")
    
    if state.current_media && state.current_media.type == "bandcamp" do
      # Cancel any existing timer
      cancel_check_timer(state.check_timer)
      
      # Start the duration timer
      duration = state.current_media.duration || 180
      timer_ref = start_duration_timer(state.room_id, duration)
      
      # Update video_started_at to now (for accurate timing)
      new_state = %{state | 
        check_timer: timer_ref,
        video_started_at: DateTime.utc_now()
      }
      
      Logger.info("✅ Bandcamp timer started for #{duration}s")
      Logger.info("========================================\n")
      
      {:reply, :ok, new_state}
    else
      Logger.warning("⚠️ No Bandcamp track currently playing")
      {:reply, {:error, :not_bandcamp}, state}
    end
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
    
    Logger.info("\n=== ADDING TO QUEUE ===")
    Logger.info("🎵 Media: #{media.title} (#{media.type})")
    Logger.info("🕒 Duration: #{media.duration} seconds")
    Logger.info("📊 Current state: #{length(state.queue)} in queue, current_media: #{inspect(state.current_media != nil)}")
    
    # If no media is currently playing, start this one immediately
    new_state = if is_nil(state.current_media) do
      Logger.info("✅ No current media, starting playback immediately")
      
      # Cancel any existing timer
      cancel_check_timer(state.check_timer)
      
      # For Bandcamp tracks, DON'T start timer automatically
      # Wait for user to click "I Started Playing" button
      timer_ref = nil
      
      # Broadcast to all clients in proper order
      broadcast_media_change(state.room_id, media)
      broadcast_queue_update(state.room_id, state.queue)
      broadcast_play_next(state.room_id, media, state.queue)
      
      Logger.info("✅ Now playing: #{media.title}")
      Logger.info("📁 Queue remains: #{length(state.queue)} items\n")
      
      %{state | 
        current_media: media, 
        video_state: "playing",
        video_timestamp: 0,
        video_started_at: DateTime.utc_now(),
        check_timer: timer_ref
      }
    else
      # Add to queue
      position = length(state.queue) + 1
      Logger.info("📁 Adding to queue at position #{position}")
      new_queue = state.queue ++ [media]
      Logger.info("📁 New queue size: #{length(new_queue)}")
      Logger.info("📋 Updated queue contents:")
      Enum.each(new_queue, fn item ->
        Logger.info("   - #{item.title} (#{item.type})")
      end)
      Logger.info("")
      
      broadcast_queue_update(state.room_id, new_queue)
      %{state | queue: new_queue}
    end
    
    {:reply, {:ok, media}, new_state}
  end

  @impl true
  def handle_call(:play_next, _from, state) do
    Logger.info("\n========================================")
    Logger.info("=== PLAY_NEXT CALLED ===")
    Logger.info("========================================")
    Logger.info("🎵 Current: #{inspect(state.current_media && state.current_media.title)}")
    Logger.info("📁 Queue: #{length(state.queue)} items")
    if length(state.queue) > 0 do
      Logger.info("📋 Queue items:")
      Enum.each(state.queue, fn item ->
        Logger.info("   - #{item.title} (#{item.type})")
      end)
    end
    
    # Cancel any existing timer
    cancel_check_timer(state.check_timer)
    
    case state.queue do
      [next | rest] ->
        Logger.info("\n✅ ADVANCING TO NEXT TRACK")
        Logger.info("🎬 Now Playing: #{next.title}")
        Logger.info("🕒 Duration: #{next.duration} seconds")
        Logger.info("🔢 Type: #{next.type}")
        Logger.info("📁 Remaining in queue: #{length(rest)}")
        if length(rest) > 0 do
          Logger.info("📋 Updated queue:")
          Enum.each(rest, fn item ->
            Logger.info("   - #{item.title} (#{item.type})")
          end)
        end
        
        # For Bandcamp tracks, DON'T start timer automatically
        # Wait for user to click "I Started Playing" button  
        timer_ref = nil
        
        # UPDATE STATE FIRST before broadcasting
        new_state = %{state | 
          current_media: next,
          queue: rest,
          video_state: "playing",
          video_timestamp: 0,
          video_started_at: DateTime.utc_now(),
          check_timer: timer_ref
        }
        
        # Now broadcast with the correct updated queue
        Logger.info("📡 Broadcasting to all clients...")
        broadcast_media_change(state.room_id, next)
        broadcast_queue_update(state.room_id, rest)
        broadcast_play_next(state.room_id, next, rest)
        Logger.info("✅ Broadcasts complete - queue now has #{length(rest)} items")
        
        Logger.info("========================================\n")
        {:reply, :ok, new_state}
      
      [] ->
        Logger.info("\n⚠️ Queue is empty")
        Logger.info("🛑 Stopping playback")
        
        # Update state first
        new_state = %{state | 
          current_media: nil,
          video_state: "paused",
          video_timestamp: 0,
          video_started_at: nil,
          check_timer: nil,
          queue: []
        }
        
        # Then broadcast
        broadcast_media_change(state.room_id, nil)
        broadcast_queue_update(state.room_id, [])
        broadcast_play_next(state.room_id, nil, [])
        
        Logger.info("========================================\n")
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_cast({:remove_from_queue, media_id}, state) do
    Logger.info("Removing media from queue: #{media_id}")
    
    new_queue = Enum.reject(state.queue, fn media -> 
      media.id == media_id
    end)
    
    broadcast_queue_update(state.room_id, new_queue)
    {:noreply, %{state | queue: new_queue}}
  end

  @impl true
  def handle_cast({:update_progress, current_time, duration}, state) do
    # Update video progress from client (for UI display only)
    # JavaScript video_ended event handles advancement
    {:noreply, %{state | video_timestamp: current_time}}
  end

  # Duration timer for Bandcamp tracks (which don't have a JS API to detect end)
  @impl true
  def handle_info(:bandcamp_duration_check, state) do
    Logger.info("\n========================================")
    Logger.info("⏰ BANDCAMP DURATION TIMER FIRED")
    Logger.info("========================================")
    
    if state.current_media && state.current_media.type == "bandcamp" do
      Logger.info("🎵 Track finished: #{state.current_media.title}")
      Logger.info("🚀 Auto-advancing to next track...")
      
      # Cancel the timer (it already fired, but clear the reference)
      cancel_check_timer(state.check_timer)
      
      case state.queue do
        [next | rest] ->
          Logger.info("✅ Next track: #{next.title}")
          
          # Start timer for next track if it's also Bandcamp
          timer_ref = if next.type == "bandcamp" do
            start_duration_timer(state.room_id, next.duration)
          else
            nil
          end
          
          new_state = %{state | 
            current_media: next,
            queue: rest,
            video_state: "playing",
            video_timestamp: 0,
            video_started_at: DateTime.utc_now(),
            check_timer: timer_ref
          }
          
          broadcast_media_change(state.room_id, next)
          broadcast_queue_update(state.room_id, rest)
          broadcast_play_next(state.room_id, next, rest)
          
          {:noreply, new_state}
        
        [] ->
          Logger.info("⚠️ Queue is empty, stopping playback")
          
          new_state = %{state | 
            current_media: nil,
            video_state: "paused",
            video_timestamp: 0,
            video_started_at: nil,
            check_timer: nil
          }
          
          broadcast_media_change(state.room_id, nil)
          broadcast_queue_update(state.room_id, [])
          broadcast_play_next(state.room_id, nil, [])
          
          {:noreply, new_state}
      end
    else
      Logger.info("⚠️ Timer fired but current media is not Bandcamp, ignoring")
      {:noreply, state}
    end
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
      }}
    else
      {:noreply, state}
    end
  end

  # Private functions

  defp broadcast_media_change(room_id, media) do
    Logger.info("📡 BROADCASTING media change to ALL clients")
    Logger.info("Media: #{inspect(media && media.title)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:media_changed, media}
    )
  end

  defp broadcast_queue_update(room_id, queue) do
    Logger.info("📡 BROADCASTING queue update to ALL clients")
    Logger.info("Queue size: #{length(queue)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:queue_updated, queue}
    )
  end

  defp broadcast_play_next(room_id, media, queue) do
    Logger.info("📡 BROADCASTING play_next event to ALL clients")
    Logger.info("Next media: #{inspect(media && media.title)}")
    
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:play_next, media, queue}
    )
  end

  # Duration timer for Bandcamp tracks
  # Bandcamp doesn't have a JavaScript API, so we use server-side timing
  defp start_duration_timer(_room_id, duration) do
    # Add a small buffer (5 seconds) to account for loading/buffering
    timer_duration = (duration + 5) * 1000
    Logger.info("⏰ Starting Bandcamp duration timer for #{duration}s (+5s buffer = #{timer_duration}ms)")
    Process.send_after(self(), :bandcamp_duration_check, timer_duration)
  end

  defp cancel_check_timer(nil), do: :ok
  defp cancel_check_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end
end
