defmodule YoutubeVideoChatAppWeb.Router do
  use YoutubeVideoChatAppWeb, :router

  import YoutubeVideoChatAppWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YoutubeVideoChatAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", YoutubeVideoChatAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/test_soundcloud", TestController, :soundcloud_test
  end

  ## Authentication routes
  scope "/", YoutubeVideoChatAppWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{YoutubeVideoChatAppWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", UserLive.Registration, :new
      live "/login", UserLive.Login, :new
    end

    post "/login", UserSessionController, :create
  end

  scope "/", YoutubeVideoChatAppWeb do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete
  end

  ## Room routes - accessible to all (guests and users)
  scope "/", YoutubeVideoChatAppWeb do
    pipe_through [:browser]

    live_session :room_session,
      on_mount: [{YoutubeVideoChatAppWeb.UserAuth, :mount_current_user}] do
      live "/rooms", RoomLive.Index, :index
      live "/room/:slug", RoomLive.Show, :show
    end
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
