defmodule YoutubeVideoChatAppWeb.Presence do
  @moduledoc """
  Provides presence tracking for rooms and users.
  """
  use Phoenix.Presence,
    otp_app: :youtube_video_chat_app,
    pubsub_server: YoutubeVideoChatApp.PubSub
end
