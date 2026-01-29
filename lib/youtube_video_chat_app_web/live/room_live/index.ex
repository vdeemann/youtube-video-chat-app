defmodule YoutubeVideoChatAppWeb.RoomLive.Index do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.{Rooms, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    rooms = Rooms.list_public_rooms()
    
    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:page_title, "Browse Rooms")}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    user = Accounts.create_guest_user()
    
    attrs = %{
      name: "#{user.username}'s Room",
      slug: Rooms.generate_room_slug(),
      host_id: user.id,
      is_public: true
    }
    
    case Rooms.create_room(attrs) do
      {:ok, room} ->
        {:noreply, push_navigate(socket, to: ~p"/room/#{room.slug}")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create room")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-black to-purple-900">
      <div class="container mx-auto px-4 py-8">
        <div class="text-center mb-12">
          <h1 class="text-5xl font-bold text-white mb-4">
            YouTube Watch Party 🎉
          </h1>
          <p class="text-xl text-purple-200">
            Watch YouTube videos together with floating live chat
          </p>
        </div>
        
        <!-- Create Room Button -->
        <div class="text-center mb-12">
          <button
            phx-click="create_room"
            class="px-8 py-4 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white text-xl font-bold rounded-full transform transition hover:scale-105 shadow-xl"
          >
            🚀 Create New Room
          </button>
        </div>
        
        <!-- Public Rooms Grid -->
        <div class="max-w-6xl mx-auto">
          <h2 class="text-2xl font-bold text-white mb-6">Public Rooms</h2>
          
          <%= if @rooms == [] do %>
            <div class="bg-white/10 backdrop-blur rounded-xl p-12 text-center">
              <p class="text-gray-300 text-lg">No rooms yet. Be the first to create one!</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for room <- @rooms do %>
                <.link
                  navigate={~p"/room/#{room.slug}"}
                  class="block bg-white/10 backdrop-blur rounded-xl p-6 hover:bg-white/20 transition transform hover:scale-105"
                >
                  <h3 class="text-xl font-bold text-white mb-2">
                    <%= room.name %>
                  </h3>
                  <p class="text-purple-300 text-sm mb-4">
                    Room Code: <%= room.slug %>
                  </p>
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400 text-sm">
                      Created <%= format_time_ago(room.inserted_at) %>
                    </span>
                    <span class="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-sm">
                      Join →
                    </span>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
        
        <!-- Features -->
        <div class="max-w-4xl mx-auto mt-16 grid grid-cols-1 md:grid-cols-3 gap-8">
          <div class="text-center">
            <div class="text-4xl mb-4">💬</div>
            <h3 class="text-white font-bold mb-2">Floating Live Chat</h3>
            <p class="text-gray-400">Instagram Live-style comments that float across the video</p>
          </div>
          <div class="text-center">
            <div class="text-4xl mb-4">🎵</div>
            <h3 class="text-white font-bold mb-2">DJ-Style Queue</h3>
            <p class="text-gray-400">Add videos to the queue and let everyone vote</p>
          </div>
          <div class="text-center">
            <div class="text-4xl mb-4">🔄</div>
            <h3 class="text-white font-bold mb-2">Perfect Sync</h3>
            <p class="text-gray-400">Everyone watches in perfect synchronization</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp format_time_ago(datetime) do
    # Convert NaiveDateTime to DateTime if needed
    utc_datetime = 
      case datetime do
        %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
        %DateTime{} -> datetime
      end
    
    diff = DateTime.diff(DateTime.utc_now(), utc_datetime)
    
    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end
