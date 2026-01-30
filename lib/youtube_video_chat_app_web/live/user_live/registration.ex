defmodule YoutubeVideoChatAppWeb.UserLive.Registration do
  use YoutubeVideoChatAppWeb, :live_view

  alias YoutubeVideoChatApp.Accounts
  alias YoutubeVideoChatApp.Accounts.User

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    socket = assign(socket, 
      form: to_form(changeset),
      page_title: "Register",
      check_errors: false
    )
    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(to: ~p"/login?registered=true&email=#{user.email}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-black to-purple-900 flex items-center justify-center px-4">
      <div class="max-w-md w-full">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-white mb-2">Create Account</h1>
          <p class="text-purple-200">Join the watch party!</p>
        </div>

        <div class="bg-white/10 backdrop-blur-lg rounded-2xl p-8 shadow-xl border border-white/20">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <div>
              <label for="user_username" class="block text-sm font-medium text-purple-200 mb-2">
                Username
              </label>
              <input
                type="text"
                name="user[username]"
                id="user_username"
                value={@form[:username].value}
                required
                phx-debounce="blur"
                class={"w-full px-4 py-3 bg-white/10 border rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent #{if @check_errors && @form[:username].errors != [], do: "border-red-500", else: "border-white/20"}"}
                placeholder="cooluser123"
              />
              <%= for err <- @form[:username].errors do %>
                <p class="mt-1 text-sm text-red-400"><%= format_error(err) %></p>
              <% end %>
            </div>

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
                phx-debounce="blur"
                class={"w-full px-4 py-3 bg-white/10 border rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent #{if @check_errors && @form[:email].errors != [], do: "border-red-500", else: "border-white/20"}"}
                placeholder="you@example.com"
              />
              <%= for err <- @form[:email].errors do %>
                <p class="mt-1 text-sm text-red-400"><%= format_error(err) %></p>
              <% end %>
            </div>

            <div>
              <label for="user_password" class="block text-sm font-medium text-purple-200 mb-2">
                Password
              </label>
              <input
                type="password"
                name="user[password]"
                id="user_password"
                value={@form[:password].value}
                required
                phx-debounce="blur"
                class={"w-full px-4 py-3 bg-white/10 border rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent #{if @check_errors && @form[:password].errors != [], do: "border-red-500", else: "border-white/20"}"}
                placeholder="••••••••"
              />
              <%= for err <- @form[:password].errors do %>
                <p class="mt-1 text-sm text-red-400"><%= format_error(err) %></p>
              <% end %>
              <p class="mt-1 text-xs text-gray-400">Minimum 6 characters</p>
            </div>

            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="w-full py-3 px-4 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-semibold rounded-lg transition transform hover:scale-[1.02] shadow-lg"
            >
              Create Account
            </button>
          </.form>

          <div class="mt-6 text-center">
            <p class="text-gray-400">
              Already have an account?
              <.link navigate={~p"/login"} class="text-purple-400 hover:text-purple-300 font-medium">
                Log in
              </.link>
            </p>
          </div>
          
          <div class="mt-4 text-center">
            <.link navigate={~p"/rooms"} class="text-gray-500 hover:text-gray-400 text-sm">
              Continue as guest →
            </.link>
          </div>
        </div>
        
        <div class="mt-6 text-center">
          <p class="text-gray-500 text-sm">
            Registered users can add videos and chat.<br/>
            Guests can only watch.
          </p>
        </div>
      </div>
    </div>
    """
  end
  
  defp format_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
