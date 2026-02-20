defmodule YoutubeVideoChatAppWeb.RoomLive.Show do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.{Rooms, Accounts, Playlists}
  alias YoutubeVideoChatApp.Rooms.RoomServer
  alias YoutubeVideoChatAppWeb.Presence
  alias Phoenix.PubSub
  require Logger

  # ============================================================================
  # Mount
  # ============================================================================

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    room = Rooms.get_room_by_slug!(slug)
    user = get_or_create_user(socket)
    is_guest = Map.get(user, :is_guest, false)

    Rooms.ensure_room_server(room.id)

    presence_before_join = if connected?(socket),
      do: map_size(Presence.list("room:#{room.id}")),
      else: 0

    if connected?(socket) do
      PubSub.subscribe(YoutubeVideoChatApp.PubSub, "room:#{room.id}")

      {:ok, _} = Presence.track(self(), "room:#{room.id}", user.id, %{
        username: user.username,
        color: user.color,
        joined_at: System.system_time(:second),
        is_guest: is_guest
      })

      unless is_guest do
        msg = system_message("#{user.username} joined the room")
        RoomServer.add_message(room.id, msg)
        PubSub.broadcast(YoutubeVideoChatApp.PubSub, "room:#{room.id}", {:new_message, msg})
      end
    end

    room_state = case RoomServer.get_state(room.id) do
      {:ok, s} -> s
      {:error, _} -> %{current_track: nil, started_at: nil, server_now: now_ms(), queue: [], queue_length: 0}
    end

    is_host = user.id == room.host_id or presence_before_join == 0

    {user_playlists, main_playlist} = load_playlists(socket)

    socket = socket
    |> assign(:room, room)
    |> assign(:user, user)
    |> assign(:is_guest, is_guest)
    |> assign(:is_host, is_host)
    |> assign(:messages, load_recent_messages(room.id))
    |> assign(:current_media, room_state.current_track)
    |> assign(:queue, room_state.queue)
    |> assign(:queue_length, room_state[:queue_length] || length(room_state.queue))
    # UI state
    |> assign(:show_chat, true)
    |> assign(:show_queue, false)
    |> assign(:presences, %{})
    |> assign(:add_video_url, "")
    |> assign(:show_login_prompt, false)
    # Playlist state
    |> assign(:main_playlist, main_playlist)
    |> assign(:user_playlists, user_playlists)
    |> assign(:show_playlist_modal, false)
    |> assign(:playlist_modal_view, :list)
    |> assign(:selected_playlist, nil)
    |> assign(:new_playlist_name, "")
    |> assign(:playlist_add_url, "")
    |> assign(:playlist_search_query, "")
    |> assign(:playlist_visible_count, 50)
    |> assign(:show_grab_modal, false)
    |> assign(:import_url, "")
    |> assign(:importing, false)

    # Push player state to JS on connected mount
    socket = if connected?(socket) do
      push_player_state(socket, room_state, is_host)
    else
      socket
    end

    {:ok, socket |> handle_joins(Presence.list("room:#{room.id}"))}
  end

  # Push the full player state to JS as a single event
  defp push_player_state(socket, room_state, is_host) do
    track = room_state.current_track
    media = if track do
      %{
        "id" => track[:id] || track.id,
        "type" => track[:type] || track.type,
        "media_id" => track[:media_id] || track.media_id,
        "embed_url" => track[:embed_url] || track.embed_url,
        "title" => track[:title] || track.title
      }
    end

    socket
    |> push_event("sync_player", %{
      media: media,
      started_at: room_state.started_at,
      server_now: room_state.server_now || now_ms(),
      is_host: is_host
    })
  end

  defp now_ms, do: System.system_time(:millisecond)

  defp load_playlists(socket) do
    if socket.assigns[:current_user] do
      playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
      main = Enum.find(playlists, fn p -> p.is_main end)
      main_with_items = if main, do: Playlists.get_playlist_with_items!(main.id), else: nil
      {playlists, main_with_items}
    else
      {[], nil}
    end
  end

  defp load_recent_messages(room_id) do
    case RoomServer.get_messages(room_id) do
      {:ok, msgs} -> msgs
      {:error, _} -> []
    end
  end

  defp get_or_create_user(socket) do
    case socket.assigns[:current_user] do
      nil -> Accounts.create_guest_user()
      user -> Accounts.user_to_room_user(user)
    end
  end

  defp system_message(text) do
    %{
      id: Ecto.UUID.generate(),
      text: text,
      username: "System",
      color: "#888888",
      timestamp: DateTime.utc_now(),
      is_system: true
    }
  end

  # ============================================================================
  # Playback Events
  # ============================================================================

  @impl true
  def handle_event("add_video", %{"url" => url}, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      case parse_media_url(String.trim(url)) do
        nil ->
          {:noreply, put_flash(socket, :error, "Invalid YouTube or SoundCloud URL")}
        media_data ->
          {:ok, _} = RoomServer.add_to_queue(socket.assigns.room.id, media_data, socket.assigns.user)
          {:noreply, assign(socket, :add_video_url, "")}
      end
    end
  end

  @impl true
  def handle_event("play_next", _params, socket) do
    if socket.assigns.is_host, do: RoomServer.play_next(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_ended", _params, socket) do
    # Any client can report; server deduplicates
    RoomServer.track_ended(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_progress", %{"current_time" => current, "duration" => duration}, socket) do
    if socket.assigns.is_host && socket.assigns.current_media do
      RoomServer.report_progress(socket.assigns.room.id, current, duration)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("request_player_state", _params, socket) do
    case RoomServer.get_state(socket.assigns.room.id) do
      {:ok, room_state} ->
        {:noreply, push_player_state(socket, room_state, socket.assigns.is_host)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_queue", _params, socket) do
    if not socket.assigns.is_guest do
      RoomServer.clear_queue(socket.assigns.room.id)
    end
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
  def handle_event("remove_own_from_queue", %{"id" => media_id}, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      RoomServer.remove_from_queue_by_user(
        socket.assigns.room.id,
        media_id,
        socket.assigns.user.id
      )
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("skip_own_song", _params, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      cm = socket.assigns.current_media
      added_by = cm && (Map.get(cm, :added_by_id) || Map.get(cm, "added_by_id"))
      if added_by == socket.assigns.user.id do
        RoomServer.play_next(socket.assigns.room.id)
      end
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("manual_play_soundcloud", _params, socket) do
    {:noreply, push_event(socket, "force_play_soundcloud", %{})}
  end

  # ============================================================================
  # Chat / UI Events
  # ============================================================================

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => msg}, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      message = %{
        id: Ecto.UUID.generate(),
        text: msg,
        username: socket.assigns.user.username,
        color: socket.assigns.user.color,
        timestamp: DateTime.utc_now()
      }
      RoomServer.add_message(socket.assigns.room.id, message)
      PubSub.broadcast(
        YoutubeVideoChatApp.PubSub,
        "room:#{socket.assigns.room.id}",
        {:new_message, message}
      )
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_reaction", %{"emoji" => emoji}, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      PubSub.broadcast(
        YoutubeVideoChatApp.PubSub,
        "room:#{socket.assigns.room.id}",
        {:reaction, %{id: Ecto.UUID.generate(), emoji: emoji, username: socket.assigns.user.username}}
      )
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_login_prompt", _params, socket) do
    {:noreply, assign(socket, :show_login_prompt, false)}
  end

  @impl true
  def handle_event("video_state_change", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :show_chat, !socket.assigns.show_chat)}
  end

  @impl true
  def handle_event("toggle_queue", _params, socket) do
    {:noreply, assign(socket, :show_queue, !socket.assigns.show_queue)}
  end

  @impl true
  def handle_event("delete_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns[:current_user]
    if current_user && room.host_id == current_user.id do
      Rooms.delete_room(room)
      {:noreply, push_navigate(socket, to: ~p"/rooms") |> put_flash(:info, "Room deleted successfully")}
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own room")}
    end
  end

  @impl true
  def handle_event("update_duration", %{"duration" => duration, "media_id" => media_id}, socket) do
    cm = socket.assigns.current_media
    if cm && (cm[:media_id] || cm.media_id) == media_id do
      {:noreply, assign(socket, :current_media, Map.put(cm, :duration, duration))}
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Playlist Modal Events (unchanged)
  # ============================================================================

  @impl true
  def handle_event("open_playlist_modal", _params, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
      {:noreply, assign(socket, show_playlist_modal: true, playlist_modal_view: :list, user_playlists: playlists, selected_playlist: nil)}
    end
  end

  @impl true
  def handle_event("close_playlist_modal", _params, socket) do
    {:noreply, assign(socket, show_playlist_modal: false, playlist_modal_view: :list, selected_playlist: nil, new_playlist_name: "", playlist_add_url: "", playlist_search_query: "")}
  end

  @impl true
  def handle_event("playlist_search", %{"value" => query}, socket) do
    {:noreply, assign(socket, playlist_search_query: query, playlist_visible_count: 50)}
  end

  @impl true
  def handle_event("load_more_tracks", _params, socket) do
    {:noreply, assign(socket, :playlist_visible_count, socket.assigns.playlist_visible_count + 50)}
  end

  @impl true
  def handle_event("load_more_queue", _params, socket) do
    current_count = length(socket.assigns.queue)
    case RoomServer.get_queue_page(socket.assigns.room.id, current_count, 50) do
      {:ok, items, total} ->
        {:noreply, socket
        |> assign(:queue, socket.assigns.queue ++ items)
        |> assign(:queue_length, total)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("playlist_show_new_form", _params, socket) do
    {:noreply, assign(socket, playlist_modal_view: :new, new_playlist_name: "")}
  end

  @impl true
  def handle_event("playlist_show_import", _params, socket) do
    {:noreply, assign(socket, playlist_modal_view: :import, import_url: "", importing: false)}
  end

  @impl true
  def handle_event("import_playlist", %{"url" => url}, socket) do
    user = socket.assigns.current_user
    url = String.trim(url)

    if url == "" do
      {:noreply, put_flash(socket, :error, "Please enter a URL")}
    else
      # Set importing state, then do the work asynchronously
      socket = assign(socket, importing: true)
      send(self(), {:do_import, url, user.id})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:do_import, url, user_id}, socket) do
    alias YoutubeVideoChatApp.PlaylistImporter

    case PlaylistImporter.import_playlist(url) do
      {:ok, %{name: name, tracks: tracks}} when tracks != [] ->
        case Playlists.create_playlist(%{name: name, user_id: user_id}) do
          {:ok, playlist} ->
            Playlists.add_items_to_playlist(playlist.id, tracks)

            playlists = Playlists.list_user_playlists_with_counts(user_id)
            playlist_with_items = Playlists.get_playlist_with_items!(playlist.id)

            {:noreply,
              socket
              |> assign(
                importing: false,
                import_url: "",
                user_playlists: playlists,
                playlist_modal_view: :show,
                selected_playlist: playlist_with_items,
                playlist_visible_count: 50
              )
              |> put_flash(:info, "Imported '#{name}' with #{length(tracks)} tracks!")}

          {:error, _} ->
            {:noreply, assign(socket, importing: false) |> put_flash(:error, "Failed to create playlist")}
        end

      {:ok, %{tracks: []}} ->
        {:noreply, assign(socket, importing: false) |> put_flash(:error, "No tracks found in the playlist")}

      {:error, reason} ->
        {:noreply, assign(socket, importing: false) |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("playlist_back_to_list", _params, socket) do
    playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
    {:noreply, assign(socket, playlist_modal_view: :list, selected_playlist: nil, user_playlists: playlists, playlist_add_url: "", playlist_search_query: "")}
  end

  @impl true
  def handle_event("playlist_create", %{"name" => name}, socket) do
    user = socket.assigns.current_user
    case Playlists.create_playlist(%{name: name, user_id: user.id}) do
      {:ok, playlist} ->
        playlists = Playlists.list_user_playlists_with_counts(user.id)
        playlist_with_items = Playlists.get_playlist_with_items!(playlist.id)
        {:noreply, assign(socket, user_playlists: playlists, playlist_modal_view: :show, selected_playlist: playlist_with_items, new_playlist_name: "") |> put_flash(:info, "Playlist created!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create playlist")}
    end
  end

  @impl true
  def handle_event("playlist_view", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    case Playlists.get_user_playlist(user.id, playlist_id) do
      nil -> {:noreply, put_flash(socket, :error, "Playlist not found")}
      playlist ->
        {:noreply, assign(socket, playlist_modal_view: :show, selected_playlist: Playlists.get_playlist_with_items!(playlist.id), playlist_visible_count: 50)}
    end
  end

  @impl true
  def handle_event("playlist_delete", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    if playlist = Playlists.get_user_playlist(user.id, playlist_id) do
      Playlists.delete_playlist(playlist)
      playlists = Playlists.list_user_playlists_with_counts(user.id)
      main = Enum.find(playlists, fn p -> p.is_main end)
      main_with_items = if main, do: Playlists.get_playlist_with_items!(main.id), else: nil
      {:noreply, assign(socket, user_playlists: playlists, main_playlist: main_with_items, playlist_modal_view: :list, selected_playlist: nil) |> put_flash(:info, "Playlist deleted")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("playlist_set_main", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    Playlists.set_main_playlist(user.id, playlist_id)
    playlists = Playlists.list_user_playlists_with_counts(user.id)
    main = Enum.find(playlists, fn p -> p.is_main end)
    main_with_items = if main, do: Playlists.get_playlist_with_items!(main.id), else: nil
    {:noreply, assign(socket, user_playlists: playlists, main_playlist: main_with_items) |> put_flash(:info, "Main playlist updated!")}
  end

  @impl true
  def handle_event("playlist_unset_main", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    if playlist = Playlists.get_user_playlist(user.id, playlist_id) do
      if playlist.is_main do
        Playlists.unset_main_playlist(user.id)
        playlists = Playlists.list_user_playlists_with_counts(user.id)
        {:noreply, assign(socket, user_playlists: playlists, main_playlist: nil) |> put_flash(:info, "Main playlist unset")}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("playlist_add_track", %{"url" => url}, socket) do
    playlist = socket.assigns.selected_playlist
    case parse_media_url(url) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid URL")}
      media_data ->
        item_attrs = %{media_type: media_data["type"], media_id: media_data["media_id"], title: media_data["title"], thumbnail: media_data["thumbnail"], duration: media_data["duration"], embed_url: media_data["embed_url"], original_url: url}
        case Playlists.add_item_to_playlist(playlist.id, item_attrs) do
          {:ok, _item} ->
            updated_playlist = Playlists.get_playlist_with_items!(playlist.id)
            playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
            main_with_items = if socket.assigns.main_playlist && socket.assigns.main_playlist.id == playlist.id, do: updated_playlist, else: socket.assigns.main_playlist
            {:noreply, assign(socket, selected_playlist: updated_playlist, user_playlists: playlists, main_playlist: main_with_items, playlist_add_url: "") |> put_flash(:info, "Track added!")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add track")}
        end
    end
  end

  @impl true
  def handle_event("playlist_remove_track", %{"id" => item_id}, socket) do
    Playlists.remove_item_from_playlist(item_id)
    playlist = socket.assigns.selected_playlist
    updated_playlist = Playlists.get_playlist_with_items!(playlist.id)
    playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
    main_with_items = if socket.assigns.main_playlist && socket.assigns.main_playlist.id == playlist.id, do: updated_playlist, else: socket.assigns.main_playlist
    {:noreply, assign(socket, selected_playlist: updated_playlist, user_playlists: playlists, main_playlist: main_with_items)}
  end

  @impl true
  def handle_event("playlist_move_track_up", %{"id" => item_id}, socket) do
    item = Playlists.get_playlist_item!(item_id)
    if item.position > 1, do: Playlists.move_item(item_id, item.position - 1)
    updated_playlist = Playlists.get_playlist_with_items!(socket.assigns.selected_playlist.id)
    {:noreply, assign(socket, selected_playlist: updated_playlist)}
  end

  @impl true
  def handle_event("playlist_move_track_down", %{"id" => item_id}, socket) do
    item = Playlists.get_playlist_item!(item_id)
    max_pos = length(socket.assigns.selected_playlist.items)
    if item.position < max_pos, do: Playlists.move_item(item_id, item.position + 1)
    updated_playlist = Playlists.get_playlist_with_items!(socket.assigns.selected_playlist.id)
    {:noreply, assign(socket, selected_playlist: updated_playlist)}
  end

  @impl true
  def handle_event("load_playlist_to_queue", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    case Playlists.get_user_playlist(user.id, playlist_id) do
      nil -> {:noreply, put_flash(socket, :error, "Playlist not found")}
      playlist ->
        playlist = Playlists.get_playlist_with_items!(playlist.id)
        if Enum.empty?(playlist.items) do
          {:noreply, put_flash(socket, :error, "This playlist is empty")}
        else
          media_items = Enum.map(playlist.items, fn item ->
            %{type: item.media_type, media_id: item.media_id, title: item.title, thumbnail: item.thumbnail, duration: item.duration, embed_url: item.embed_url, original_url: item.original_url}
          end)
          room_user = Accounts.user_to_room_user(user)
          case RoomServer.add_multiple_to_queue(socket.assigns.room.id, media_items, room_user) do
            {:ok, count} ->
              {:noreply, socket |> assign(:show_playlist_modal, false) |> put_flash(:info, "Loaded #{count} tracks from '#{playlist.name}'")}
            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to load playlist")}
          end
        end
    end
  end

  @impl true
  def handle_event("open_grab_modal", _params, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      playlists = Playlists.list_user_playlists_with_counts(socket.assigns.current_user.id)
      {:noreply, assign(socket, show_grab_modal: true, user_playlists: playlists)}
    end
  end

  @impl true
  def handle_event("close_grab_modal", _params, socket) do
    {:noreply, assign(socket, show_grab_modal: false)}
  end

  @impl true
  def handle_event("grab_to_playlist", %{"playlist-id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    cm = socket.assigns.current_media
    if cm do
      item_attrs = %{
        media_type: Map.get(cm, :type) || Map.get(cm, "type"),
        media_id: Map.get(cm, :media_id) || Map.get(cm, "media_id"),
        title: Map.get(cm, :title) || Map.get(cm, "title"),
        thumbnail: Map.get(cm, :thumbnail) || Map.get(cm, "thumbnail"),
        duration: Map.get(cm, :duration) || Map.get(cm, "duration"),
        embed_url: Map.get(cm, :embed_url) || Map.get(cm, "embed_url"),
        original_url: Map.get(cm, :original_url) || Map.get(cm, "original_url")
      }
      case Playlists.add_item_to_playlist(playlist_id, item_attrs) do
        {:ok, _} ->
          playlist = Playlists.get_playlist!(playlist_id)
          playlists = Playlists.list_user_playlists_with_counts(user.id)
          main_with_items = if socket.assigns.main_playlist && socket.assigns.main_playlist.id == playlist_id, do: Playlists.get_playlist_with_items!(playlist_id), else: socket.assigns.main_playlist
          {:noreply, assign(socket, show_grab_modal: false, user_playlists: playlists, main_playlist: main_with_items) |> put_flash(:info, "Added to '#{playlist.name}'!")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add track")}
      end
    else
      {:noreply, put_flash(socket, :error, "No track is currently playing")}
    end
  end

  @impl true
  def handle_event("create_playlist_from_grab", _params, socket) do
    user = socket.assigns.current_user
    cm = socket.assigns.current_media
    if cm do
      playlist_name = "Grabbed Songs #{DateTime.utc_now() |> DateTime.to_unix()}"
      case Playlists.create_playlist(%{name: playlist_name, user_id: user.id}) do
        {:ok, playlist} ->
          item_attrs = %{
            media_type: Map.get(cm, :type) || Map.get(cm, "type"),
            media_id: Map.get(cm, :media_id) || Map.get(cm, "media_id"),
            title: Map.get(cm, :title) || Map.get(cm, "title"),
            thumbnail: Map.get(cm, :thumbnail) || Map.get(cm, "thumbnail"),
            duration: Map.get(cm, :duration) || Map.get(cm, "duration"),
            embed_url: Map.get(cm, :embed_url) || Map.get(cm, "embed_url"),
            original_url: Map.get(cm, :original_url) || Map.get(cm, "original_url")
          }
          case Playlists.add_item_to_playlist(playlist.id, item_attrs) do
            {:ok, _} ->
              playlists = Playlists.list_user_playlists_with_counts(user.id)
              {:noreply, assign(socket, show_grab_modal: false, user_playlists: playlists) |> put_flash(:info, "Created '#{playlist_name}' and added track!")}
            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to add track to new playlist")}
          end
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create playlist")}
      end
    else
      {:noreply, put_flash(socket, :error, "No track is currently playing")}
    end
  end

  @impl true
  def handle_event("load_main_playlist", _params, socket) do
    if socket.assigns.is_guest do
      {:noreply, assign(socket, :show_login_prompt, true)}
    else
      case socket.assigns.main_playlist do
        nil -> {:noreply, put_flash(socket, :error, "No main playlist set")}
        playlist when playlist.items == [] -> {:noreply, put_flash(socket, :error, "Your main playlist is empty")}
        playlist ->
          media_items = Enum.map(playlist.items, fn item ->
            %{type: item.media_type, media_id: item.media_id, title: item.title, thumbnail: item.thumbnail, duration: item.duration, embed_url: item.embed_url, original_url: item.original_url}
          end)
          room_user = Accounts.user_to_room_user(socket.assigns.current_user)
          case RoomServer.add_multiple_to_queue(socket.assigns.room.id, media_items, room_user) do
            {:ok, count} -> {:noreply, put_flash(socket, :info, "Loaded #{count} tracks from '#{playlist.name}'")}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to load playlist")}
          end
      end
    end
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  @impl true
  def handle_info({:room_state_changed, state}, socket) do
    old_media = socket.assigns.current_media
    old_track_id = old_media && (old_media[:id] || old_media.id)
    new_track = state.current_track
    new_track_id = new_track && (new_track[:id] || new_track.id)

    track_changed = old_track_id != new_track_id

    # Detect transition to nil (queue exhausted) — always push so client shows placeholder
    went_to_nil = old_media != nil && new_track == nil

    socket = socket
    |> assign(:current_media, new_track)
    |> assign(:queue, state.queue)
    |> assign(:queue_length, state[:queue_length] || length(state.queue))

    socket = if track_changed or went_to_nil do
      media = if new_track do
        %{
          "id" => new_track[:id] || new_track.id,
          "type" => new_track[:type] || new_track.type,
          "media_id" => new_track[:media_id] || new_track.media_id,
          "embed_url" => new_track[:embed_url] || new_track.embed_url,
          "title" => new_track[:title] || new_track.title
        }
      end

      push_event(socket, "sync_player", %{
        media: media,
        started_at: state.started_at,
        server_now: state.server_now,
        is_host: socket.assigns.is_host
      })
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(100)
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:reaction, reaction}, socket) do
    {:noreply, push_event(socket, "show_reaction", reaction)}
  end

  # Legacy handlers (ignore gracefully)
  @impl true
  def handle_info({:video_sync, _, _}, socket), do: {:noreply, socket}
  @impl true
  def handle_info({:media_changed, _}, socket), do: {:noreply, socket}
  @impl true
  def handle_info({:queue_updated, _}, socket), do: {:noreply, socket}
  @impl true
  def handle_info({:play_next, _, _}, socket), do: {:noreply, socket}
  @impl true
  def handle_info({:play_next, _, _, _}, socket), do: {:noreply, socket}


  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    Enum.each(diff.leaves, fn {_user_id, %{metas: metas}} ->
      meta = List.first(metas)
      unless meta.is_guest do
        remaining = socket.assigns.presences
        |> handle_leaves_map(diff.leaves)
        |> handle_joins_map(diff.joins)

        my_id = socket.assigns.user.id
        remaining_ids = Map.keys(remaining) |> Enum.sort()

        if match?([^my_id | _], remaining_ids) do
          msg = system_message("#{meta.username} left the room")
          RoomServer.add_message(socket.assigns.room.id, msg)
          PubSub.broadcast(YoutubeVideoChatApp.PubSub, "room:#{socket.assigns.room.id}", {:new_message, msg})
        end
      end
    end)

    new_presences = socket.assigns.presences
    |> handle_leaves_map(diff.leaves)
    |> handle_joins_map(diff.joins)

    {:noreply, assign(socket, :presences, new_presences)}
  end

  defp handle_joins_map(presences, joins) do
    Enum.reduce(joins, presences, fn {user_id, %{metas: [meta | _]}}, acc -> Map.put(acc, user_id, meta) end)
  end

  defp handle_leaves_map(presences, leaves) do
    Enum.reduce(leaves, presences, fn {user_id, _}, acc -> Map.delete(acc, user_id) end)
  end

  defp handle_joins(socket, joins) do
    assign(socket, :presences, handle_joins_map(socket.assigns.presences, joins))
  end

  # ============================================================================
  # URL Parsing (unchanged)
  # ============================================================================

  defp parse_media_url(url) do
    url = String.trim(url)
    youtube_result = extract_youtube_id(url)

    cond do
      youtube_result != nil ->
        %{
          "type" => "youtube",
          "media_id" => youtube_result,
          "title" => "YouTube Video",
          "thumbnail" => "https://img.youtube.com/vi/#{youtube_result}/mqdefault.jpg",
          "duration" => 180,
          "embed_url" => "https://www.youtube.com/embed/#{youtube_result}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000"
        }

      String.contains?(String.downcase(url), "soundcloud.com") ->
        extract_soundcloud_data(url)

      String.match?(url, ~r/^[A-Za-z0-9_-]{11}$/) ->
        %{
          "type" => "youtube",
          "media_id" => url,
          "title" => "YouTube Video",
          "thumbnail" => "https://img.youtube.com/vi/#{url}/mqdefault.jpg",
          "duration" => 180,
          "embed_url" => "https://www.youtube.com/embed/#{url}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000"
        }

      true -> nil
    end
  end

  defp extract_youtube_id(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        case Regex.run(~r/[?&]v=([A-Za-z0-9_-]{11})/, url) do
          [_, id] -> id
          _ -> nil
        end
      String.contains?(url, "youtu.be/") ->
        case Regex.run(~r/youtu\.be\/([A-Za-z0-9_-]{11})/, url) do
          [_, id] -> id
          _ -> nil
        end
      String.contains?(url, "youtube.com/embed/") ->
        case Regex.run(~r/embed\/([A-Za-z0-9_-]{11})/, url) do
          [_, id] -> id
          _ -> nil
        end
      true -> nil
    end
  end

  defp extract_soundcloud_data(url) do
    try do
      url = String.trim(url)
      url = case Regex.run(~r/(https?:\/\/[^\s]+soundcloud\.com[^\s]+)/i, url) do
        [_, found_url] -> found_url
        _ -> url
      end

      uri = URI.parse(url)
      path = uri.path || ""
      is_soundcloud = uri.host in ["soundcloud.com", "www.soundcloud.com", "m.soundcloud.com"] || String.contains?(String.downcase(uri.host || url), "soundcloud")
      unless is_soundcloud, do: throw(:not_soundcloud)

      clean_url = "https://soundcloud.com#{path}"
      path_parts = path |> String.trim("/") |> String.split("/") |> Enum.filter(&(&1 != ""))

      {artist_name, track_name} = case path_parts do
        [artist, track | _] when artist != "" and track != "" -> {format_name(artist), format_name(track)}
        [single_part] -> {format_name(single_part), "Track"}
        _ -> {"SoundCloud", "Audio"}
      end

      media_id = :crypto.hash(:md5, clean_url) |> Base.encode16() |> String.slice(0..10)
      encoded_url = URI.encode(clean_url)

      %{
        "type" => "soundcloud",
        "media_id" => media_id,
        "title" => "#{track_name} by #{artist_name}",
        "thumbnail" => generate_soundcloud_thumbnail(),
        "duration" => 180,
        "embed_url" => "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=true&buying=false&liking=false&download=false&sharing=false&show_artwork=true&show_comments=false&show_playcount=false&show_user=true&hide_related=true&visual=true&start_track=0&callback=true",
        "original_url" => clean_url
      }
    rescue
      _ -> nil
    catch
      :not_soundcloud -> nil
      _ -> nil
    end
  end

  defp format_name(name) do
    name |> String.replace("-", " ") |> String.replace("_", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  end

  defp generate_soundcloud_thumbnail do
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 180' fill='none'%3E%3Crect width='320' height='180' fill='url(%23gradient)'/%3E%3Cg transform='translate(160, 90)'%3E%3Cpath d='M-60 -20 Q-60 -30, -50 -30 L50 -30 Q60 -30, 60 -20 L60 20 Q60 30, 50 30 L-50 30 Q-60 30, -60 20 Z' fill='white' fill-opacity='0.2'/%3E%3Cpath d='M-30 -5v20h4V-12c-1.2-0.8-2.8-1.2-4-2zm-8 10v8h4V-8c-1.6 0.4-2.8 1.2-4 2zm16 0v10h4V-10c-1.2-0.8-2.8-1.6-4-2zm8 2v8h4V-8c-1.2-0.4-2.8-0.8-4-1.2zm8 2v6h4v-6c-1.2-0.4-2.8-0.4-4-0.8zm8 2V15h4V-5c-1.2 0-2.8 0-4 0zm8 0V15h4c0-2-1.6-3.6-4-5z' fill='white'/%3E%3C/g%3E%3Cdefs%3E%3ClinearGradient id='gradient' x1='0' y1='0' x2='320' y2='180'%3E%3Cstop offset='0%25' stop-color='%23ff5500'/%3E%3Cstop offset='100%25' stop-color='%23ff8800'/%3E%3C/linearGradient%3E%3C/defs%3E%3C/svg%3E"
  end

  defp linkify_text(text) do
    url_regex = ~r/(https?:\/\/[^\s]+)/
    image_regex = ~r/\.(jpg|jpeg|png|gif|webp)(\?[^\s]*)?$/i
    parts = String.split(text, url_regex, include_captures: true, trim: true)
    html_parts = Enum.map(parts, fn part ->
      if String.match?(part, url_regex) do
        escaped_url = part |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
        if String.match?(part, image_regex) do
          "<div class=\"my-2\"><img src=\"#{escaped_url}\" alt=\"Shared image\" class=\"rounded-lg max-w-sm\" loading=\"lazy\" /></div>"
        else
          "<a href=\"#{escaped_url}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"underline hover:text-purple-300 transition\">#{escaped_url}</a>"
        end
      else
        part |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
      end
    end)
    html_parts |> Enum.join("") |> Phoenix.HTML.raw()
  end
end
