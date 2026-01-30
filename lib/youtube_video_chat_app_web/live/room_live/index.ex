defmodule YoutubeVideoChatAppWeb.RoomLive.Index do
  use YoutubeVideoChatAppWeb, :live_view
  alias YoutubeVideoChatApp.{Rooms, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    rooms = Rooms.list_public_rooms()
    
    # Check if user is logged in
    current_user = socket.assigns[:current_user]
    is_guest = is_nil(current_user)
    
    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:is_guest, is_guest)
     |> assign(:page_title, "Browse Rooms")}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    # Only registered users can create rooms
    if socket.assigns.is_guest do
      {:noreply, put_flash(socket, :error, "Please log in or create an account to create a room.")}
    else
      user = Accounts.user_to_room_user(socket.assigns.current_user)
      
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
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-black to-purple-900">
      <div class="container mx-auto px-4 py-8">
        <!-- Header with Auth -->
        <div class="flex justify-end mb-4">
          <%= if @is_guest do %>
            <div class="flex gap-2">
              <.link 
                navigate={~p"/login"}
                class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition"
              >
                Log In
              </.link>
              <.link 
                navigate={~p"/register"}
                class="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition border border-white/20"
              >
                Sign Up
              </.link>
            </div>
          <% else %>
            <div class="flex items-center gap-4">
              <span class="text-purple-200">
                Welcome, <span class="font-semibold" style={"color: #{@current_user.color}"}><%= @current_user.username %></span>
              </span>
              <.link 
                href={~p"/logout"}
                method="delete"
                class="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition"
              >
                Logout
              </.link>
            </div>
          <% end %>
        </div>
        
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
          <%= if @is_guest do %>
            <div class="bg-white/5 backdrop-blur rounded-2xl p-8 max-w-md mx-auto border border-white/10">
              <div class="text-5xl mb-4">🚀</div>
              <h3 class="text-xl font-bold text-white mb-2">Want to create a room?</h3>
              <p class="text-gray-400 mb-6">
                Log in or create an account to start your own watch party!
              </p>
              <div class="flex flex-col sm:flex-row gap-3 justify-center">
                <.link 
                  navigate={~p"/login"}
                  class="px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold rounded-full transition transform hover:scale-105"
                >
                  Log In
                </.link>
                <.link 
                  navigate={~p"/register"}
                  class="px-6 py-3 bg-white/10 hover:bg-white/20 text-white font-bold rounded-full transition border border-white/20"
                >
                  Sign Up
                </.link>
              </div>
            </div>
          <% else %>
            <button
              phx-click="create_room"
              class="px-8 py-4 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white text-xl font-bold rounded-full transform transition hover:scale-105 shadow-xl"
            >
              🚀 Create New Room
            </button>
          <% end %>
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
        
        <!-- Guest vs Registered info -->
        <div class="max-w-2xl mx-auto mt-16 bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
          <h3 class="text-white font-bold text-lg mb-4 text-center">Guest vs Registered Users</h3>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <h4 class="text-yellow-400 font-semibold mb-2">👤 Guests Can:</h4>
              <ul class="text-gray-400 text-sm space-y-1">
                <li>✓ Watch videos</li>
                <li>✓ Listen to music</li>
                <li>✓ Join any room</li>
              </ul>
            </div>
            <div>
              <h4 class="text-green-400 font-semibold mb-2">🌟 Registered Users Can:</h4>
              <ul class="text-gray-400 text-sm space-y-1">
                <li>✓ Everything guests can do</li>
                <li>✓ Create rooms</li>
                <li>✓ Add YouTube videos</li>
                <li>✓ Add SoundCloud tracks</li>
                <li>✓ Chat with others</li>
                <li>✓ Send reactions</li>
              </ul>
            </div>
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
