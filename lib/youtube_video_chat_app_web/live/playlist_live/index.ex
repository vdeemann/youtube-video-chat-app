defmodule YoutubeVideoChatAppWeb.PlaylistLive.Index do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.Playlists
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      playlists = Playlists.list_user_playlists_with_counts(user.id)
      
      {:ok, assign(socket,
        playlists: playlists,
        show_new_modal: false,
        new_playlist_name: "",
        new_playlist_description: "",
        page_title: "My Playlists"
      )}
    else
      {:ok, push_navigate(socket, to: "/login")}
    end
  end

  @impl true
  def handle_event("show_new_modal", _params, socket) do
    {:noreply, assign(socket, show_new_modal: true)}
  end

  @impl true
  def handle_event("hide_new_modal", _params, socket) do
    {:noreply, assign(socket,
      show_new_modal: false,
      new_playlist_name: "",
      new_playlist_description: ""
    )}
  end

  @impl true
  def handle_event("create_playlist", %{"name" => name, "description" => description}, socket) do
    user = socket.assigns.current_user
    
    case Playlists.create_playlist(%{
      name: name,
      description: description,
      user_id: user.id
    }) do
      {:ok, _playlist} ->
        playlists = Playlists.list_user_playlists_with_counts(user.id)
        {:noreply, assign(socket,
          playlists: playlists,
          show_new_modal: false,
          new_playlist_name: "",
          new_playlist_description: ""
        ) |> put_flash(:info, "Playlist created!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create playlist")}
    end
  end

  @impl true
  def handle_event("set_main", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    Playlists.set_main_playlist(user.id, playlist_id)
    playlists = Playlists.list_user_playlists_with_counts(user.id)
    {:noreply, assign(socket, playlists: playlists) |> put_flash(:info, "Main playlist updated!")}
  end

  @impl true
  def handle_event("unset_main", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    
    # Verify playlist belongs to user and unset
    if playlist = Playlists.get_user_playlist(user.id, playlist_id) do
      if playlist.is_main do
        Playlists.unset_main_playlist(user.id)
        playlists = Playlists.list_user_playlists_with_counts(user.id)
        {:noreply, assign(socket, playlists: playlists) |> put_flash(:info, "Main playlist unset")}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_playlist", %{"id" => playlist_id}, socket) do
    user = socket.assigns.current_user
    
    if playlist = Playlists.get_user_playlist(user.id, playlist_id) do
      Playlists.delete_playlist(playlist)
      playlists = Playlists.list_user_playlists_with_counts(user.id)
      {:noreply, assign(socket, playlists: playlists) |> put_flash(:info, "Playlist deleted")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
      <div class="max-w-6xl mx-auto px-4 py-8">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-white">My Playlists</h1>
            <p class="text-gray-400 mt-1">Organize your favorite tracks</p>
          </div>
          <div class="flex gap-4">
            <.link
              navigate="/rooms"
              class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition"
            >
              ← Back to Rooms
            </.link>
            <button
              phx-click="show_new_modal"
              class="px-6 py-2 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition transform hover:scale-105"
            >
              + New Playlist
            </button>
          </div>
        </div>

        <!-- Info about main playlist -->
        <div class="bg-purple-900/30 border border-purple-500/30 rounded-lg p-4 mb-6">
          <div class="flex items-start gap-3">
            <span class="text-2xl">⭐</span>
            <div>
              <h3 class="text-white font-semibold">Main Playlist</h3>
              <p class="text-gray-300 text-sm">
                Set a playlist as your "main" playlist to automatically load it as your queue when joining a room.
                Click the star icon on any playlist to set it as main.
              </p>
            </div>
          </div>
        </div>

        <!-- Playlists Grid -->
        <%= if Enum.empty?(@playlists) do %>
          <div class="text-center py-16">
            <div class="text-6xl mb-4">🎵</div>
            <h3 class="text-xl text-white mb-2">No playlists yet</h3>
            <p class="text-gray-400 mb-6">Create your first playlist to start organizing your music</p>
            <button
              phx-click="show_new_modal"
              class="px-6 py-3 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition"
            >
              Create Your First Playlist
            </button>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for playlist <- @playlists do %>
              <div class={"relative bg-gray-800/50 rounded-xl overflow-hidden border transition hover:border-purple-500/50 #{if playlist.is_main, do: "border-yellow-500/50 ring-2 ring-yellow-500/20", else: "border-gray-700/50"}"}>
                <!-- Main badge -->
                <%= if playlist.is_main do %>
                  <div class="absolute top-3 right-3 z-10">
                    <span class="px-2 py-1 bg-yellow-500 text-black text-xs font-bold rounded-full flex items-center gap-1">
                      ⭐ MAIN
                    </span>
                  </div>
                <% end %>

                <!-- Playlist content -->
                <.link navigate={"/playlists/#{playlist.id}"} class="block p-6">
                  <div class="flex items-start gap-4">
                    <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-pink-500 rounded-lg flex items-center justify-center text-3xl shrink-0">
                      🎶
                    </div>
                    <div class="flex-1 min-w-0">
                      <h3 class="text-white font-semibold text-lg truncate"><%= playlist.name %></h3>
                      <p class="text-gray-400 text-sm mt-1">
                        <%= playlist.item_count %> <%= if playlist.item_count == 1, do: "track", else: "tracks" %>
                      </p>
                      <%= if playlist.description do %>
                        <p class="text-gray-500 text-sm mt-2 line-clamp-2"><%= playlist.description %></p>
                      <% end %>
                    </div>
                  </div>
                </.link>

                <!-- Actions -->
                <div class="px-6 pb-4 flex items-center gap-2">
                  <%= if playlist.is_main do %>
                    <button
                      phx-click="unset_main"
                      phx-value-id={playlist.id}
                      class="px-3 py-1.5 bg-yellow-500/20 text-yellow-400 hover:bg-yellow-500/30 rounded-lg text-sm transition flex items-center gap-1"
                      title="Remove as main playlist"
                    >
                      ⭐ Unset Main
                    </button>
                  <% else %>
                    <button
                      phx-click="set_main"
                      phx-value-id={playlist.id}
                      class="px-3 py-1.5 bg-gray-700 text-gray-300 hover:bg-gray-600 rounded-lg text-sm transition flex items-center gap-1"
                      title="Set as main playlist"
                    >
                      ☆ Set as Main
                    </button>
                  <% end %>
                  <button
                    phx-click="delete_playlist"
                    phx-value-id={playlist.id}
                    data-confirm="Are you sure you want to delete this playlist? This cannot be undone."
                    class="px-3 py-1.5 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-lg text-sm transition"
                  >
                    Delete
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- New Playlist Modal -->
      <%= if @show_new_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70" phx-click="hide_new_modal">
          <div class="bg-gray-800 rounded-xl p-6 w-full max-w-md mx-4" phx-click-away="hide_new_modal">
            <h2 class="text-xl font-bold text-white mb-4">Create New Playlist</h2>
            <form phx-submit="create_playlist">
              <div class="space-y-4">
                <div>
                  <label class="block text-gray-300 text-sm mb-2">Playlist Name *</label>
                  <input
                    type="text"
                    name="name"
                    value={@new_playlist_name}
                    placeholder="My Awesome Playlist"
                    class="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-purple-500"
                    required
                    autofocus
                  />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm mb-2">Description (optional)</label>
                  <textarea
                    name="description"
                    placeholder="What's this playlist about?"
                    rows="3"
                    class="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-purple-500 resize-none"
                  ><%= @new_playlist_description %></textarea>
                </div>
              </div>
              <div class="flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  phx-click="hide_new_modal"
                  class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-2 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold rounded-lg transition"
                >
                  Create Playlist
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
