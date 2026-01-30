defmodule YoutubeVideoChatAppWeb.UserLive.Login do
  use YoutubeVideoChatAppWeb, :live_view

  def mount(params, _session, socket) do
    email = params["email"] || Phoenix.Flash.get(socket.assigns.flash, :email)
    registered = params["registered"] == "true"
    
    form = to_form(%{"email" => email}, as: "user")
    
    socket = socket
    |> assign(form: form, page_title: "Log In")
    |> then(fn socket ->
      if registered do
        put_flash(socket, :info, "Account created! Please log in.")
      else
        socket
      end
    end)
    
    {:ok, socket, temporary_assigns: [form: form]}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-black to-purple-900 flex items-center justify-center px-4">
      <div class="max-w-md w-full">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-white mb-2">Welcome Back</h1>
          <p class="text-purple-200">Log in to your account</p>
        </div>

        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="mb-4 p-4 bg-green-500/20 border border-green-500/30 rounded-lg text-green-400 text-center">
            <%= Phoenix.Flash.get(@flash, :info) %>
          </div>
        <% end %>
        
        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="mb-4 p-4 bg-red-500/20 border border-red-500/30 rounded-lg text-red-400 text-center">
            <%= Phoenix.Flash.get(@flash, :error) %>
          </div>
        <% end %>

        <div class="bg-white/10 backdrop-blur-lg rounded-2xl p-8 shadow-xl border border-white/20">
          <.form for={@form} id="login_form" action={~p"/login"} phx-update="ignore" class="space-y-6">
            <div>
              <label for="user_email" class="block text-sm font-medium text-purple-200 mb-2">
                Email
              </label>
              <input
                type="email"
                name="user[email]"
                id="user_email"
                value={@form[:email].value}
                required
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                placeholder="you@example.com"
              />
            </div>

            <div>
              <label for="user_password" class="block text-sm font-medium text-purple-200 mb-2">
                Password
              </label>
              <input
                type="password"
                name="user[password]"
                id="user_password"
                required
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                placeholder="••••••••"
              />
            </div>

            <div class="flex items-center justify-between">
              <label class="flex items-center">
                <input type="checkbox" name="user[remember_me]" class="rounded bg-white/10 border-white/20 text-purple-600 focus:ring-purple-500" />
                <span class="ml-2 text-sm text-gray-300">Remember me</span>
              </label>
            </div>

            <button
              type="submit"
              class="w-full py-3 px-4 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-semibold rounded-lg transition transform hover:scale-[1.02] shadow-lg"
            >
              Log In
            </button>
          </.form>

          <div class="mt-6 text-center">
            <p class="text-gray-400">
              Don't have an account?
              <.link navigate={~p"/register"} class="text-purple-400 hover:text-purple-300 font-medium">
                Sign up
              </.link>
            </p>
          </div>
          
          <div class="mt-4 text-center">
            <.link navigate={~p"/rooms"} class="text-gray-500 hover:text-gray-400 text-sm">
              Continue as guest →
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
