defmodule YoutubeVideoChatAppWeb.RoomLive.Show do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.{Rooms, Accounts}
  alias YoutubeVideoChatApp.Rooms.RoomServer
  alias YoutubeVideoChatAppWeb.Presence
  alias Phoenix.PubSub
  require Logger

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    room = Rooms.get_room_by_slug!(slug)
    
    # Create or get user
    user = Accounts.create_guest_user()
    
    # Ensure room server is running BEFORE trying to get state
    Rooms.ensure_room_server(room.id)
    
    # Check presence BEFORE we join - this determines if we're first
    presence_before_join = if connected?(socket) do
      existing = Presence.list("room:#{room.id}")
      Logger.info("👤 User #{user.username} checking room #{room.name}")
      Logger.info("   Existing presences: #{map_size(existing)}")
      Logger.info("   Existing IDs: #{inspect(Map.keys(existing))}")
      map_size(existing)
    else
      0
    end
    
    if connected?(socket) do
      # Subscribe to room updates
      PubSub.subscribe(YoutubeVideoChatApp.PubSub, "room:#{room.id}")
      
      # Track presence AFTER checking count
      {:ok, _} = Presence.track(self(), "room:#{room.id}", user.id, %{
        username: user.username,
        color: user.color,
        joined_at: System.system_time(:second)
      })
      
      Logger.info("   Tracked user, now presence: #{map_size(Presence.list("room:#{room.id}"))}")
    end
    
    # Get initial room state (now the server should be running)
    room_state = case RoomServer.get_state(room.id) do
      {:ok, state} -> 
        state
      {:error, :room_not_found} ->
        Logger.warning("Room server not found for room #{room.id}, using defaults")
        # Return default state if server isn't ready
        %{
          current_media: nil,
          video_state: "paused",
          video_timestamp: 0,
          video_started_at: nil,
          queue: []
        }
    end
    
    # Calculate the current playback position for syncing new users
    current_timestamp = calculate_current_timestamp(room_state)
    
    Logger.info("🎬 Playback sync for new user:")
    Logger.info("   Current media: #{inspect(room_state.current_media && room_state.current_media.title)}")
    Logger.info("   Video started at: #{inspect(room_state.video_started_at)}")
    Logger.info("   Stored timestamp: #{room_state.video_timestamp}")
    Logger.info("   Calculated current position: #{current_timestamp}s")
    
    # User is host if: they created the room OR they're the first one in the room
    is_host = user.id == room.host_id or presence_before_join == 0
    
    Logger.info("👑 Host determination for #{user.username}:")
    Logger.info("   Room host_id: #{inspect(room.host_id)}")
    Logger.info("   User id: #{inspect(user.id)}")
    Logger.info("   IDs match: #{user.id == room.host_id}")
    Logger.info("   Presence before join: #{presence_before_join}")
    Logger.info("   → IS HOST: #{is_host}")
    
    socket = socket
    |> assign(:room, room)
    |> assign(:user, user)
    |> assign(:messages, [])
    |> assign(:current_media, room_state.current_media)
    |> assign(:video_state, room_state.video_state)
    |> assign(:video_timestamp, current_timestamp)
    |> assign(:queue, room_state.queue)
    |> assign(:is_host, is_host)
    |> assign(:show_chat, true)
    |> assign(:presences, %{})
    |> assign(:show_queue, false)
    |> assign(:add_video_url, "")
    |> assign(:last_played_track_id, room_state.current_media && (room_state.current_media[:id] || room_state.current_media.id))
    |> push_event("set_host_status", %{is_host: is_host})
    
    # Always send create_player event if there's media
    # This will be received by JS after the page loads
    socket = if room_state.current_media do
      media = room_state.current_media
      media_for_js = %{
        "type" => media[:type] || media.type,
        "media_id" => media[:media_id] || media.media_id,
        "embed_url" => media[:embed_url] || media.embed_url,
        "title" => media[:title] || media.title
      }
      
      Logger.info("📺 Pushing create_player event for: #{media_for_js["title"]}")
      
      push_event(socket, "create_player", %{
        media: media_for_js,
        timestamp: current_timestamp,
        started_at: room_state.video_started_at && DateTime.to_unix(room_state.video_started_at, :millisecond),
        is_host: is_host
      })
    else
      socket
    end
    
    {:ok, socket |> handle_joins(Presence.list("room:#{room.id}"))}
  end

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket) do
    # Ignore empty messages
    {:noreply, socket}
  end
  
  def handle_event("send_message", %{"message" => msg}, socket) do
    message = %{
      id: Ecto.UUID.generate(),
      text: msg,
      username: socket.assigns.user.username,
      color: socket.assigns.user.color,
      timestamp: DateTime.utc_now()
    }
    
    # Broadcast to all viewers
    PubSub.broadcast(
      YoutubeVideoChatApp.PubSub, 
      "room:#{socket.assigns.room.id}", 
      {:new_message, message}
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("send_reaction", %{"emoji" => emoji}, socket) do
    # Broadcast reaction event
    PubSub.broadcast(
      YoutubeVideoChatApp.PubSub,
      "room:#{socket.assigns.room.id}",
      {:reaction, %{
        id: Ecto.UUID.generate(),
        emoji: emoji,
        username: socket.assigns.user.username
      }}
    )
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_state_change", _params, socket) do
    # Video sync disabled for iframe mode
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :show_chat, !socket.assigns.show_chat)}
  end

  @impl true
  def handle_event("toggle_queue", _params, socket) do
    {:noreply, assign(socket, :show_queue, !socket.assigns.show_queue)}
  end

  @impl true
  def handle_event("add_video", %{"url" => url}, socket) do
    Logger.info("=== ADD VIDEO EVENT ===")
    Logger.info("Raw URL received: #{url}")
    
    # Clean the URL
    cleaned_url = String.trim(url)
    Logger.info("Cleaned URL: #{cleaned_url}")
    
    # Parse the URL
    media_data = parse_media_url(cleaned_url)
    Logger.info("Parse result: #{inspect(media_data)}")
    
    if media_data do
      Logger.info("Media parsed successfully, adding to queue...")
      
      {:ok, _media} = RoomServer.add_to_queue(
        socket.assigns.room.id,
        media_data,
        socket.assigns.user
      )
      
      {:noreply, assign(socket, :add_video_url, "")}
    else
      Logger.error("Failed to parse URL as media")
      {:noreply, put_flash(socket, :error, "Invalid YouTube or SoundCloud URL")}
    end
  end

  @impl true
  def handle_event("play_next", _params, socket) do
    Logger.info("\n" <> String.duplicate("=", 50))
    Logger.info("=== PLAY_NEXT EVENT (Manual Skip) ===")
    Logger.info(String.duplicate("=", 50))
    Logger.info("Is host: #{socket.assigns.is_host}")
    Logger.info("Current media: #{inspect(socket.assigns.current_media && (socket.assigns.current_media[:title] || socket.assigns.current_media.title))}")
    Logger.info("Queue length: #{length(socket.assigns.queue)}")
    
    if socket.assigns.is_host do
      Logger.info("🚀 Host triggering play_next")
      result = RoomServer.play_next(socket.assigns.room.id)
      Logger.info("✅ play_next result: #{inspect(result)}")
    else
      Logger.warning("Non-host tried to skip")
    end
    
    Logger.info(String.duplicate("=", 50) <> "\n")
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_from_queue", %{"id" => media_id}, socket) do
    if socket.assigns.is_host do
      RoomServer.remove_from_queue(socket.assigns.room.id, media_id)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_ended", params, socket) do
    Logger.info("\n" <> String.duplicate("=", 50))
    Logger.info("🎬 VIDEO_ENDED EVENT RECEIVED")
    Logger.info(String.duplicate("=", 50))
    Logger.info("Params: #{inspect(params)}")
    Logger.info("Is host: #{socket.assigns.is_host}")
    Logger.info("Current media: #{inspect(socket.assigns.current_media && (socket.assigns.current_media[:title] || socket.assigns.current_media.title))}")
    Logger.info("Queue length: #{length(socket.assigns.queue)}")
    
    if socket.assigns.is_host do
      Logger.info("🚀 Host is advancing to next track...")
      result = RoomServer.play_next(socket.assigns.room.id)
      Logger.info("✅ play_next result: #{inspect(result)}")
    else
      Logger.info("⚠️ Not host, ignoring video_ended event")
    end
    
    Logger.info(String.duplicate("=", 50) <> "\n")
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("update_duration", %{"duration" => duration, "media_id" => media_id}, socket) do
    Logger.info("📏 Received real duration: #{duration}s for media #{media_id}")
    
    # Update the duration in RoomServer if this is the current media
    if socket.assigns.current_media && socket.assigns.current_media.media_id == media_id do
      # Update current_media with real duration
      updated_media = Map.put(socket.assigns.current_media, :duration, duration)
      
      # You could also update it in the RoomServer here
      # RoomServer.update_current_media_duration(socket.assigns.room.id, duration)
      
      {:noreply, assign(socket, :current_media, updated_media)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("video_progress", %{"current_time" => current, "duration" => duration}, socket) do
    # Update server with video progress
    if socket.assigns.is_host && socket.assigns.current_media do
      RoomServer.update_video_progress(
        socket.assigns.room.id,
        current,
        duration
      )
    end
    {:noreply, socket}
  end
  
  # New event to manually trigger SoundCloud play
  @impl true
  def handle_event("manual_play_soundcloud", _params, socket) do
    Logger.info("Manual play SoundCloud triggered")
    {:noreply, push_event(socket, "force_play_soundcloud", %{})}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Add to chat history only (no floating messages)
    messages = [message | socket.assigns.messages] |> Enum.take(100)
    
    # Use temporary_assigns to minimize re-renders
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:video_sync, _timestamp, _state}, socket) do
    # Video sync disabled for iframe mode
    {:noreply, socket}
  end

  @impl true
  def handle_info({:media_changed, media}, socket) do
    Logger.info("=== MEDIA_CHANGED received ===")
    Logger.info("New media: #{inspect(media && media.title)}")
    
    # Just update the assign for UI (playlist display)
    # Do NOT create player here - that's handled by play_next
    {:noreply, assign(socket, :current_media, media)}
  end

  @impl true
  def handle_info({:queue_updated, queue}, socket) do
    Logger.info("=== QUEUE_UPDATED received ===")
    Logger.info("New queue length: #{length(queue)}")
    
    # Just update the queue - no events that interrupt playback
    {:noreply, assign(socket, :queue, queue)}
  end

  @impl true
  def handle_info({:play_next, media, queue}, socket) do
    Logger.info("=== PLAY_NEXT received ===")
    Logger.info("New media: #{inspect(media && media.title)}")
    Logger.info("Queue length: #{length(queue)}")
    
    # Compare using the unique track ID (not media_id which can be duplicated)
    old_track_id = socket.assigns[:last_played_track_id]
    new_track_id = media && (media[:id] || media.id)
    
    Logger.info("Old track_id: #{inspect(old_track_id)}, New track_id: #{inspect(new_track_id)}")
    
    # Create player when track changes OR when starting fresh
    should_create_player = (old_track_id != new_track_id)
    
    if should_create_player do
      Logger.info("Creating player for: #{inspect(media && media.title)}")
      
      media_for_js = if media do
        %{
          "type" => media[:type] || media.type,
          "media_id" => media[:media_id] || media.media_id,
          "embed_url" => media[:embed_url] || media.embed_url,
          "title" => media[:title] || media.title
        }
      else
        nil
      end
      
      started_at = if media, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond), else: nil
      
      {:noreply,
       socket
       |> assign(:current_media, media)
       |> assign(:queue, queue)
       |> assign(:video_timestamp, 0)
       |> assign(:last_played_track_id, new_track_id)
       |> push_event("create_player", %{
            media: media_for_js,
            started_at: started_at,
            is_host: socket.assigns.is_host
          })}
    else
      Logger.info("Same track, just updating queue")
      {:noreply, socket |> assign(:queue, queue)}
    end
  end

  @impl true
  def handle_info({:reaction, reaction}, socket) do
    # Push event to show reaction animation
    {:noreply, push_event(socket, "show_reaction", reaction)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    Logger.info("👥 Presence diff received - joins: #{map_size(diff.joins)}, leaves: #{map_size(diff.leaves)}")
    
    # Only update presences, nothing else - this should NOT affect the player
    new_presences = socket.assigns.presences
    |> handle_leaves_map(diff.leaves)
    |> handle_joins_map(diff.joins)
    
    {:noreply, assign(socket, :presences, new_presences)}
  end
  
  defp handle_joins_map(presences, joins) do
    Enum.reduce(joins, presences, fn {user_id, %{metas: [meta | _]}}, acc ->
      Map.put(acc, user_id, meta)
    end)
  end

  defp handle_leaves_map(presences, leaves) do
    Enum.reduce(leaves, presences, fn {user_id, _}, acc ->
      Map.delete(acc, user_id)
    end)
  end
  
  # Socket-based version for initial mount
  defp handle_joins(socket, joins) do
    new_presences = handle_joins_map(socket.assigns.presences, joins)
    assign(socket, :presences, new_presences)
  end

  # Calculate current playback position based on when video started
  defp calculate_current_timestamp(room_state) do
    case {room_state.current_media, room_state.video_started_at, room_state.video_state} do
      {nil, _, _} -> 
        0
      {_, nil, _} -> 
        # No start time recorded, use stored timestamp
        room_state.video_timestamp || 0
      {_, started_at, "playing"} ->
        # Calculate elapsed time since video started
        now = DateTime.utc_now()
        elapsed = DateTime.diff(now, started_at, :second)
        # Add any offset that was stored (in case of pause/resume)
        base_timestamp = room_state.video_timestamp || 0
        base_timestamp + elapsed
      {_, _, "paused"} ->
        # Video is paused, return stored timestamp
        room_state.video_timestamp || 0
      _ ->
        room_state.video_timestamp || 0
    end
  end

  defp parse_media_url(url) do
    url = String.trim(url)
    
    Logger.debug("=== PARSING URL ===")
    Logger.debug("Input: #{url}")
    
    # First check for YouTube
    youtube_result = extract_youtube_id(url)
    Logger.debug("YouTube check result: #{inspect(youtube_result)}")
    
    if youtube_result do
      Logger.debug("Detected as YouTube video")
      %{
        "type" => "youtube",
        "media_id" => youtube_result,
        "title" => "YouTube Video",
        "thumbnail" => "https://img.youtube.com/vi/#{youtube_result}/mqdefault.jpg",
        "duration" => 180,
        "embed_url" => "https://www.youtube.com/embed/#{youtube_result}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000"
      }
    else
      # Check for SoundCloud - VERY permissive
      is_soundcloud = String.contains?(String.downcase(url), "soundcloud.com")
      Logger.debug("SoundCloud check: contains 'soundcloud.com'? #{is_soundcloud}")
      
      if is_soundcloud do
        Logger.debug("Attempting to parse as SoundCloud...")
        extract_soundcloud_data(url)
      else
        # Check if it's a direct YouTube ID
        if String.match?(url, ~r/^[A-Za-z0-9_-]{11}$/) do
          Logger.debug("Detected as direct YouTube ID")
          %{
            "type" => "youtube",
            "media_id" => url,
            "title" => "YouTube Video",
            "thumbnail" => "https://img.youtube.com/vi/#{url}/mqdefault.jpg",
            "duration" => 180,
            "embed_url" => "https://www.youtube.com/embed/#{url}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000"
          }
        else
          Logger.debug("Not recognized as any supported media type")
          nil
        end
      end
    end
  end

  defp extract_youtube_id(url) do
    cond do
      # Standard YouTube URL
      String.contains?(url, "youtube.com/watch?v=") ->
        case Regex.run(~r/[?&]v=([A-Za-z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end
      
      # Short YouTube URL
      String.contains?(url, "youtu.be/") ->
        case Regex.run(~r/youtu\.be\/([A-Za-z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end
      
      # YouTube embed URL
      String.contains?(url, "youtube.com/embed/") ->
        case Regex.run(~r/embed\/([A-Za-z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end
      
      true ->
        nil
    end
  end

  defp extract_soundcloud_data(url) do
    Logger.info("=== EXTRACTING SOUNDCLOUD DATA ===")
    Logger.info("Input URL: #{url}")
    
    try do
      # Remove any whitespace
      url = String.trim(url)
      
      # Find where the actual URL starts (in case there's text before it)
      url = case Regex.run(~r/(https?:\/\/[^\s]+soundcloud\.com[^\s]+)/i, url) do
        [_, found_url] -> 
          Logger.info("Extracted URL from text: #{found_url}")
          found_url
        _ -> 
          Logger.info("Using original URL")
          url
      end
      
      # Parse the URL - handle malformed URLs
      uri = URI.parse(url)
      Logger.info("Parsed URI - host: #{uri.host}, path: #{uri.path}")
      
      # Get the path without query params
      path = case uri.path do
        nil -> 
          Logger.warn("No path found in URL")
          ""
        p -> p
      end
      
      # Verify it's actually SoundCloud
      is_soundcloud = case uri.host do
        "soundcloud.com" -> true
        "www.soundcloud.com" -> true
        "m.soundcloud.com" -> true
        nil ->
          # Malformed URL, check if soundcloud is in there somewhere
          String.contains?(String.downcase(url), "soundcloud.com")
        _ ->
          String.contains?(String.downcase(uri.host || ""), "soundcloud")
      end
      
      unless is_soundcloud do
        Logger.error("Not a SoundCloud URL - host: #{uri.host}")
        throw(:not_soundcloud)
      end
      
      # Build clean URL
      clean_url = "https://soundcloud.com#{path}"
      Logger.info("Clean URL: #{clean_url}")
      
      # Extract artist and track from path
      path_parts = path
      |> String.trim("/")
      |> String.split("/")
      |> Enum.filter(fn part -> part != "" and part != nil end)
      
      Logger.info("Path parts: #{inspect(path_parts)}")
      
      {artist_name, track_name} = case path_parts do
        [artist, track | _] when artist != "" and track != "" ->
          artist_display = format_name(artist)
          track_display = format_name(track)
          {artist_display, track_display}
        
        [single_part] ->
          # Maybe just an artist page or single part
          {format_name(single_part), "Track"}
        
        _ ->
          Logger.warn("Could not parse artist/track from path")
          {"SoundCloud", "Audio"}
      end
      
      title = "#{track_name} by #{artist_name}"
      Logger.info("Title: #{title}")
      
      # Generate unique ID for this track
      media_id = :crypto.hash(:md5, clean_url) 
      |> Base.encode16() 
      |> String.slice(0..10)
      
      # UPDATED: More permissive embed parameters
      encoded_url = URI.encode(clean_url)
      # Changed parameters for better compatibility
      embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=true&buying=false&liking=false&download=false&sharing=false&show_artwork=true&show_comments=false&show_playcount=false&show_user=true&hide_related=true&visual=true&start_track=0&callback=true"
      
      Logger.info("Embed URL: #{String.slice(embed_url, 0..100)}...")
      Logger.info("=== SOUNDCLOUD PARSE SUCCESS ===")
      
      %{
        "type" => "soundcloud",
        "media_id" => media_id,
        "title" => title,
        "thumbnail" => generate_soundcloud_thumbnail(),
        "duration" => 180,
        "embed_url" => embed_url,
        "original_url" => clean_url
      }
    catch
      :not_soundcloud -> 
        Logger.error("URL is not a SoundCloud URL")
        nil
      e ->
        Logger.error("Error parsing SoundCloud URL: #{inspect(e)}")
        nil
    rescue
      e ->
        Logger.error("Exception parsing SoundCloud URL: #{inspect(e)}")
        Logger.error("Stack: #{inspect(__STACKTRACE__)}")
        nil
    end
  end
  
  defp format_name(name) do
    name
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp generate_soundcloud_thumbnail do
    # Return a data URI with an SVG SoundCloud logo on gradient background
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 180' fill='none'%3E%3Crect width='320' height='180' fill='url(%23gradient)'/%3E%3Cg transform='translate(160, 90)'%3E%3Cpath d='M-60 -20 Q-60 -30, -50 -30 L50 -30 Q60 -30, 60 -20 L60 20 Q60 30, 50 30 L-50 30 Q-60 30, -60 20 Z' fill='white' fill-opacity='0.2'/%3E%3Cpath d='M-30 -5v20h4V-12c-1.2-0.8-2.8-1.2-4-2zm-8 10v8h4V-8c-1.6 0.4-2.8 1.2-4 2zm16 0v10h4V-10c-1.2-0.8-2.8-1.6-4-2zm8 2v8h4V-8c-1.2-0.4-2.8-0.8-4-1.2zm8 2v6h4v-6c-1.2-0.4-2.8-0.4-4-0.8zm8 2V15h4V-5c-1.2 0-2.8 0-4 0zm8 0V15h4c0-2-1.6-3.6-4-5z' fill='white'/%3E%3C/g%3E%3Cdefs%3E%3ClinearGradient id='gradient' x1='0' y1='0' x2='320' y2='180'%3E%3Cstop offset='0%25' stop-color='%23ff5500'/%3E%3Cstop offset='100%25' stop-color='%23ff8800'/%3E%3C/linearGradient%3E%3C/defs%3E%3C/svg%3E"
  end

  # Enhanced linkify_text function with image support
  defp linkify_text(text) do
    # Regex patterns
    url_regex = ~r/(https?:\/\/[^\s]+)/
    image_regex = ~r/\.(jpg|jpeg|png|gif|webp)(\?[^\s]*)?$/i
    
    parts = String.split(text, url_regex, include_captures: true, trim: true)
    
    html_parts = Enum.map(parts, fn part ->
      if String.match?(part, url_regex) do
        # Escape the URL for HTML attributes
        escaped_url = part
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()
        
        # Check if it's an image URL
        if String.match?(part, image_regex) do
          # Return an image tag without hover effects or view button
          """
          <div class="my-2">
            <img 
              src="#{escaped_url}" 
              alt="Shared image" 
              class="rounded-lg max-w-sm"
              loading="lazy"
            />
          </div>
          """
        else
          # Return a regular link
          "<a href=\"#{escaped_url}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"underline hover:text-purple-300 transition\">#{escaped_url}</a>"
        end
      else
        # Escape regular text and convert to string
        part
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()
      end
    end)
    
    # Join all parts and mark as safe HTML
    html_parts
    |> Enum.join("")
    |> Phoenix.HTML.raw()
  end
end