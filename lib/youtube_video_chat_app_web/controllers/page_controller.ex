defmodule YoutubeVideoChatAppWeb.PageController do
  use YoutubeVideoChatAppWeb, :controller

  def home(conn, _params) do
    # Redirect to the rooms index
    redirect(conn, to: ~p"/rooms")
  end
end
