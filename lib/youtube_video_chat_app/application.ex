defmodule YoutubeVideoChatApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      YoutubeVideoChatAppWeb.Telemetry,
      YoutubeVideoChatApp.Repo,
      {DNSCluster, query: Application.get_env(:youtube_video_chat_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: YoutubeVideoChatApp.PubSub},
      # Start the Finch HTTP client for API requests
      {Finch, name: YoutubeVideoChatApp.Finch},
      # Start the Presence module
      YoutubeVideoChatAppWeb.Presence,
      # Start the Registry for room servers (faster than :global)
      {Registry, keys: :unique, name: YoutubeVideoChatApp.RoomRegistry},
      # Start the DynamicSupervisor for room servers
      {DynamicSupervisor, name: YoutubeVideoChatApp.RoomSupervisor, strategy: :one_for_one},
      # Start the Endpoint (http/https)
      YoutubeVideoChatAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: YoutubeVideoChatApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    YoutubeVideoChatAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
