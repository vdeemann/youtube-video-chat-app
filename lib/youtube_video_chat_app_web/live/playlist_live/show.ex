defmodule YoutubeVideoChatAppWeb.PlaylistLive.Show do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.Playlists
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    if user do
      case Playlists.get_user_playlist(user.id, id) do
        nil ->
          {:ok, push_navigate(socket, to: "/playlists") |> put_flash(:error, "Playlist not found")}
        
        playlist ->
          playlist = Playlists.get_playlist_with_items!(playlist.id)
          {:ok, assign(socket,
            playlist: playlist,
            show_add_modal: false,
            add_url: "",
            editing_name: false,
            new_name: playlist.name,
            page_title: playlist.name
          )}
      end
    else
      {:ok, push_navigate(socket, to: "/login")}
    end
  end

  @impl true
  def handle_event("show_add_modal", _params, socket) do
    {:noreply, assign(socket, show_add_modal: true, add_url: "")}
  end

  @impl true
  def handle_event("hide_add_modal", _params, socket) do
    {:noreply, assign(socket, show_add_modal: false, add_url: "")}
  end

  @impl true
  def handle_event("add_track", %{"url" => url}, socket) do
    playlist = socket.assigns.playlist

    case parse_media_url(url) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid URL. Please enter a valid YouTube or SoundCloud URL.")}

      media_data ->
        case Playlists.add_item_to_playlist(playlist.id, media_data) do
          {:ok, _item} ->
            playlist = Playlists.get_playlist_with_items!(playlist.id)
            {:noreply, assign(socket,
              playlist: playlist,
              show_add_modal: false,
              add_url: ""
            ) |> put_flash(:info, "Track added!")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add track")}
        end
    end
  end

  @impl true
  def handle_event("remove_item", %{"id" => item_id}, socket) do
    Playlists.remove_item_from_playlist(item_id)
    playlist = Playlists.get_playlist_with_items!(socket.assigns.playlist.id)
    {:noreply, assign(socket, playlist: playlist) |> put_flash(:info, "Track removed")}
  end

  @impl true
  def handle_event("move_up", %{"id" => item_id}, socket) do
    item = Playlists.get_playlist_item!(item_id)
    if item.position > 1 do
      Playlists.move_item(item_id, item.position - 1)
    end
    playlist = Playlists.get_playlist_with_items!(socket.assigns.playlist.id)
    {:noreply, assign(socket, playlist: playlist)}
  end

  @impl true
  def handle_event("move_down", %{"id" => item_id}, socket) do
    item = Playlists.get_playlist_item!(item_id)
    max_pos = length(socket.assigns.playlist.items)
    if item.position < max_pos do
      Playlists.move_item(item_id, item.position + 1)
    end
    playlist = Playlists.get_playlist_with_items!(socket.assigns.playlist.id)
    {:noreply, assign(socket, playlist: playlist)}
  end

  @impl true
  def handle_event("start_editing_name", _params, socket) do
    {:noreply, assign(socket, editing_name: true, new_name: socket.assigns.playlist.name)}
  end

  @impl true
  def handle_event("cancel_editing_name", _params, socket) do
    {:noreply, assign(socket, editing_name: false)}
  end

  @impl true
  def handle_event("save_name", %{"name" => name}, socket) do
    case Playlists.update_playlist(socket.assigns.playlist, %{name: name}) do
      {:ok, playlist} ->
        playlist = Playlists.get_playlist_with_items!(playlist.id)
        {:noreply, assign(socket, playlist: playlist, editing_name: false, page_title: playlist.name)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update name")}
    end
  end

  @impl true
  def handle_event("set_main", _params, socket) do
    user = socket.assigns.current_user
    Playlists.set_main_playlist(user.id, socket.assigns.playlist.id)
    playlist = Playlists.get_playlist_with_items!(socket.assigns.playlist.id)
    {:noreply, assign(socket, playlist: playlist) |> put_flash(:info, "Set as main playlist!")}
  end

  @impl true
  def handle_event("unset_main", _params, socket) do
    user = socket.assigns.current_user
    Playlists.unset_main_playlist(user.id)
    playlist = Playlists.get_playlist_with_items!(socket.assigns.playlist.id)
    {:noreply, assign(socket, playlist: playlist) |> put_flash(:info, "Main playlist unset")}
  end

  # URL parsing - copied from show.ex but could be refactored to a shared module
  defp parse_media_url(url) do
    url = String.trim(url)

    cond do
      youtube_id = extract_youtube_id(url) ->
        %{
          media_type: "youtube",
          media_id: youtube_id,
          title: "YouTube Video",
          thumbnail: "https://img.youtube.com/vi/#{youtube_id}/mqdefault.jpg",
          duration: 180,
          embed_url: "https://www.youtube.com/embed/#{youtube_id}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000",
          original_url: url
        }

      String.contains?(String.downcase(url), "soundcloud.com") ->
        extract_soundcloud_data(url)

      String.match?(url, ~r/^[A-Za-z0-9_-]{11}$/) ->
        %{
          media_type: "youtube",
          media_id: url,
          title: "YouTube Video",
          thumbnail: "https://img.youtube.com/vi/#{url}/mqdefault.jpg",
          duration: 180,
          embed_url: "https://www.youtube.com/embed/#{url}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1&origin=http://localhost:4000",
          original_url: url
        }

      true ->
        nil
    end
  end

  defp extract_youtube_id(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        case Regex.run(~r/[?&]v=([A-Za-z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end

      String.contains?(url, "youtu.be/") ->
        case Regex.run(~r/youtu\.be\/([A-Za-z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end

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
    try do
      url = String.trim(url)

      url = case Regex.run(~r/(https?:\/\/[^\s]+soundcloud\.com[^\s]+)/i, url) do
        [_, found_url] -> found_url
        _ -> url
      end

      uri = URI.parse(url)
      path = uri.path || ""

      clean_url = "https://soundcloud.com#{path}"

      path_parts = path
      |> String.trim("/")
      |> String.split("/")
      |> Enum.filter(fn part -> part != "" and part != nil end)

      {artist_name, track_name} = case path_parts do
        [artist, track | _] when artist != "" and track != "" ->
          {format_name(artist), format_name(track)}
        [single_part] ->
          {format_name(single_part), "Track"}
        _ ->
          {"SoundCloud", "Audio"}
      end

      title = "#{track_name} by #{artist_name}"

      media_id = :crypto.hash(:md5, clean_url)
      |> Base.encode16()
      |> String.slice(0..10)

      encoded_url = URI.encode(clean_url)
      embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=true&buying=false&liking=false&download=false&sharing=false&show_artwork=true&show_comments=false&show_playcount=false&show_user=true&hide_related=true&visual=true&start_track=0&callback=true"

      %{
        media_type: "soundcloud",
        media_id: media_id,
        title: title,
        thumbnail: nil,
        duration: 180,
        embed_url: embed_url,
        original_url: clean_url
      }
    rescue
      _ -> nil
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
      <div class="max-w-4xl mx-auto px-4 py-8">
        <!-- Header -->
        <div class="flex items-center gap-4 mb-6">
          <.link navigate="/playlists" class="text-gray-400 hover:text-white transition">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </.link>
          
          <div class="flex-1">
            <%= if @editing_name do %>
              <form phx-submit="save_name" class="flex gap-2">
                <input
                  type="text"
                  name="name"
                  value={@new_name}
                  class="flex-1 px-3 py-1 bg-gray-700 border border-gray-600 rounded-lg text-white text-2xl font-bold focus:outline-none focus:border-purple-500"
                  autofocus
                />
                <button type="submit" class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white rounded-lg">Save</button>
                <button type="button" phx-click="cancel_editing_name" class="px-3 py-1 bg-gray-600 hover:bg-gray-700 text-white rounded-lg">Cancel</button>
              </form>
            <% else %>
              <div class="flex items-center gap-2">
                <h1 class="text-2xl font-bold text-white"><%= @playlist.name %></h1>
                <button phx-click="start_editing_name" class="text-gray-400 hover:text-white">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                  </svg>
                </button>
                <%= if @playlist.is_main do %>
                  <span class="px-2 py-0.5 bg-yellow-500 text-black text-xs font-bold rounded-full">⭐ MAIN</span>
                <% end %>
              </div>
            <% end %>
            <p class="text-gray-400 text-sm mt-1"><%= length(@playlist.items) %> tracks</p>
          </div>

          <div class="flex gap-2">
            <%= if @playlist.is_main do %>
              <button
                phx-click="unset_main"
                class="px-4 py-2 bg-yellow-500/20 text-yellow-400 hover:bg-yellow-500/30 rounded-lg transition text-sm"
              >
                ⭐ Unset Main
              </button>
            <% else %>
              <button
                phx-click="set_main"
                class="px-4 py-2 bg-gray-700 text-gray-300 hover:bg-gray-600 rounded-lg transition text-sm"
              >
                ☆ Set as Main
              </button>
            <% end %>
            <button
              phx-click="show_add_modal"
              class="px-4 py-2 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition"
            >
              + Add Track
            </button>
          </div>
        </div>

        <!-- Tracks List -->
        <%= if Enum.empty?(@playlist.items) do %>
          <div class="text-center py-16 bg-gray-800/30 rounded-xl border border-gray-700/50">
            <div class="text-6xl mb-4">🎵</div>
            <h3 class="text-xl text-white mb-2">No tracks yet</h3>
            <p class="text-gray-400 mb-6">Add some tracks to your playlist</p>
            <button
              phx-click="show_add_modal"
              class="px-6 py-3 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition"
            >
              Add Your First Track
            </button>
          </div>
        <% else %>
          <div class="space-y-2">
            <%= for {item, index} <- Enum.with_index(@playlist.items) do %>
              <div class="flex items-center gap-4 p-4 bg-gray-800/50 rounded-lg border border-gray-700/50 hover:border-purple-500/30 transition group">
                <!-- Position -->
                <span class="text-gray-500 text-sm w-6 text-center"><%= index + 1 %></span>
                
                <!-- Thumbnail -->
                <div class="w-16 h-12 rounded overflow-hidden bg-gray-700 shrink-0">
                  <%= if item.thumbnail do %>
                    <img src={item.thumbnail} alt="" class="w-full h-full object-cover" />
                  <% else %>
                    <div class={"w-full h-full flex items-center justify-center text-2xl #{if item.media_type == "soundcloud", do: "bg-orange-900", else: "bg-red-900"}"}>
                      <%= if item.media_type == "youtube", do: "▶️", else: "🎵" %>
                    </div>
                  <% end %>
                </div>

                <!-- Info -->
                <div class="flex-1 min-w-0">
                  <h4 class="text-white font-medium truncate"><%= item.title %></h4>
                  <p class="text-gray-400 text-sm">
                    <%= String.capitalize(item.media_type) %>
                    <%= if item.duration do %>
                      • <%= format_duration(item.duration) %>
                    <% end %>
                  </p>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition">
                  <button
                    phx-click="move_up"
                    phx-value-id={item.id}
                    disabled={index == 0}
                    class={"p-2 rounded hover:bg-gray-700 transition #{if index == 0, do: "opacity-30 cursor-not-allowed", else: "text-gray-400 hover:text-white"}"}
                    title="Move up"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                    </svg>
                  </button>
                  <button
                    phx-click="move_down"
                    phx-value-id={item.id}
                    disabled={index == length(@playlist.items) - 1}
                    class={"p-2 rounded hover:bg-gray-700 transition #{if index == length(@playlist.items) - 1, do: "opacity-30 cursor-not-allowed", else: "text-gray-400 hover:text-white"}"}
                    title="Move down"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <button
                    phx-click="remove_item"
                    phx-value-id={item.id}
                    class="p-2 rounded hover:bg-red-500/20 text-gray-400 hover:text-red-400 transition"
                    title="Remove"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Add Track Modal -->
      <%= if @show_add_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70" phx-click="hide_add_modal">
          <div class="bg-gray-800 rounded-xl p-6 w-full max-w-lg mx-4" phx-click-away="hide_add_modal">
            <h2 class="text-xl font-bold text-white mb-4">Add Track</h2>
            <form phx-submit="add_track">
              <div>
                <label class="block text-gray-300 text-sm mb-2">YouTube or SoundCloud URL</label>
                <input
                  type="text"
                  name="url"
                  value={@add_url}
                  placeholder="https://youtube.com/watch?v=... or https://soundcloud.com/..."
                  class="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-purple-500"
                  required
                  autofocus
                />
                <p class="text-gray-500 text-sm mt-2">
                  Supported: YouTube videos, SoundCloud tracks
                </p>
              </div>
              <div class="flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  phx-click="hide_add_modal"
                  class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-2 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition"
                >
                  Add Track
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
  defp format_duration(_), do: ""
end
