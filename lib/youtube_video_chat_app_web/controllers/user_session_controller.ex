defmodule YoutubeVideoChatAppWeb.UserSessionController do
  use YoutubeVideoChatAppWeb, :controller

  alias YoutubeVideoChatApp.Accounts
  alias YoutubeVideoChatAppWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: ~p"/login")
    end
  end

  # Token-based login from modal (LiveView generates token, we set the session)
  def token_login(conn, %{"token" => token_b64}) do
    with {:ok, token} <- Base.url_decode64(token_b64),
         user when not is_nil(user) <- Accounts.get_user_by_session_token(token) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> put_session(:user_token, token)
      |> configure_session(renew: true)
      |> redirect(to: ~p"/rooms")
    else
      _ ->
        conn
        |> put_flash(:error, "Invalid or expired login link")
        |> redirect(to: ~p"/rooms")
    end
  end

  def token_login(conn, _params) do
    conn
    |> redirect(to: ~p"/rooms")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
