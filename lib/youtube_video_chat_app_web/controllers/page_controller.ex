defmodule YoutubeVideoChatAppWeb.PageController do
  use YoutubeVideoChatAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home, current_user: conn.assigns[:current_user])
  end

  def redirect_to_rooms(conn, _params) do
    redirect(conn, to: ~p"/rooms")
  end
end
