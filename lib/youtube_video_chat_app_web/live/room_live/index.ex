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
     |> assign(:show_auth_modal, false)
     |> assign(:auth_mode, :login)  # :login or :register
     |> assign(:auth_error, nil)
     |> assign(:page_title, "Browse Rooms")}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    # Only registered users can create rooms
    if socket.assigns.is_guest do
      {:noreply, 
       socket
       |> assign(:show_auth_modal, true)
       |> assign(:auth_mode, :login)
       |> assign(:auth_error, nil)}
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
  def handle_event("show_login", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_auth_modal, true)
     |> assign(:auth_mode, :login)
     |> assign(:auth_error, nil)}
  end

  @impl true
  def handle_event("show_register", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_auth_modal, true)
     |> assign(:auth_mode, :register)
     |> assign(:auth_error, nil)}
  end

  @impl true
  def handle_event("close_auth_modal", _params, socket) do
    {:noreply, assign(socket, :show_auth_modal, false)}
  end

  @impl true
  def handle_event("switch_to_login", _params, socket) do
    {:noreply, 
     socket
     |> assign(:auth_mode, :login)
     |> assign(:auth_error, nil)}
  end

  @impl true
  def handle_event("switch_to_register", _params, socket) do
    {:noreply, 
     socket
     |> assign(:auth_mode, :register)
     |> assign(:auth_error, nil)}
  end

  @impl true
  def handle_event("login", %{"email" => email, "password" => password}, socket) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:noreply, assign(socket, :auth_error, "Invalid email or password")}
      
      user ->
        # Create token and redirect to auth callback which sets the session
        token = Accounts.generate_user_session_token(user)
        {:noreply,
         socket
         |> assign(:show_auth_modal, false)
         |> redirect(to: ~p"/auth/callback?token=#{Base.url_encode64(token)}")}
    end
  end

  @impl true
  def handle_event("register", %{"username" => username, "email" => email, "password" => password}, socket) do
    case Accounts.register_user(%{username: username, email: email, password: password}) do
      {:ok, user} ->
        # Create token and redirect to auth callback which sets the session
        token = Accounts.generate_user_session_token(user)
        {:noreply,
         socket
         |> assign(:show_auth_modal, false)
         |> redirect(to: ~p"/auth/callback?token=#{Base.url_encode64(token)}")}
      
      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, assign(socket, :auth_error, error_msg)}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
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
              <button
                phx-click="show_login"
                class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition"
              >
                Log In
              </button>
              <button
                phx-click="show_register"
                class="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition border border-white/20"
              >
                Sign Up
              </button>
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
                <button
                  phx-click="show_login"
                  class="px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold rounded-full transition transform hover:scale-105"
                >
                  Log In
                </button>
                <button
                  phx-click="show_register"
                  class="px-6 py-3 bg-white/10 hover:bg-white/20 text-white font-bold rounded-full transition border border-white/20"
                >
                  Sign Up
                </button>
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
      
      <!-- Auth Modal -->
      <%= if @show_auth_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <!-- Backdrop (click to close) -->
          <div class="absolute inset-0" phx-click="close_auth_modal"></div>
          
          <!-- Modal Content (doesn't close on click) -->
          <div class="relative bg-gray-900 border border-purple-500/30 rounded-2xl p-8 max-w-md w-full mx-4 shadow-2xl z-10">
            <!-- Close button -->
            <button
              phx-click="close_auth_modal"
              class="absolute top-4 right-4 text-gray-500 hover:text-white transition"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
            
            <!-- Modal Content -->
            <div class="text-center mb-6">
              <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 flex items-center justify-center">
                <span class="text-2xl"><%= if @auth_mode == :login, do: "👋", else: "🎉" %></span>
              </div>
              <h3 class="text-2xl font-bold text-white">
                <%= if @auth_mode == :login, do: "Welcome Back!", else: "Join the Party!" %>
              </h3>
              <p class="text-gray-400 mt-2">
                <%= if @auth_mode == :login, do: "Log in to create rooms and chat", else: "Create an account to get started" %>
              </p>
            </div>
            
            <!-- Error Message -->
            <%= if @auth_error do %>
              <div class="mb-4 p-3 bg-red-500/20 border border-red-500/50 rounded-lg text-red-400 text-sm">
                <%= @auth_error %>
              </div>
            <% end %>
            
            <!-- Login Form -->
            <%= if @auth_mode == :login do %>
              <form phx-submit="login" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Email</label>
                  <input
                    type="email"
                    name="email"
                    required
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
                    placeholder="you@example.com"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Password</label>
                  <input
                    type="password"
                    name="password"
                    required
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
                    placeholder="••••••••"
                  />
                </div>
                <button
                  type="submit"
                  class="w-full py-3 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold rounded-lg transition"
                >
                  Log In
                </button>
              </form>
              <p class="text-center text-gray-400 mt-4">
                Don't have an account?
                <button phx-click="switch_to_register" class="text-purple-400 hover:text-purple-300 font-semibold ml-1">
                  Sign Up
                </button>
              </p>
            <% else %>
              <!-- Register Form -->
              <form phx-submit="register" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Username</label>
                  <input
                    type="text"
                    name="username"
                    required
                    minlength="2"
                    maxlength="20"
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
                    placeholder="cooluser123"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Email</label>
                  <input
                    type="email"
                    name="email"
                    required
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
                    placeholder="you@example.com"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Password</label>
                  <input
                    type="password"
                    name="password"
                    required
                    minlength="6"
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
                    placeholder="••••••••"
                  />
                </div>
                <button
                  type="submit"
                  class="w-full py-3 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold rounded-lg transition"
                >
                  Create Account
                </button>
              </form>
              <p class="text-center text-gray-400 mt-4">
                Already have an account?
                <button phx-click="switch_to_login" class="text-purple-400 hover:text-purple-300 font-semibold ml-1">
                  Log In
                </button>
              </p>
            <% end %>
          </div>
        </div>
      <% end %>
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
