defmodule YoutubeVideoChatAppWeb.Router do
  use YoutubeVideoChatAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YoutubeVideoChatAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", YoutubeVideoChatAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/test_soundcloud", TestController, :soundcloud_test
    
    # LiveView routes
    live "/room/:slug", RoomLive.Show, :show
    live "/rooms", RoomLive.Index, :index
    live "/rooms/new", RoomLive.New, :new
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:youtube_video_chat_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: YoutubeVideoChatAppWeb.Telemetry
    end
  end
end
