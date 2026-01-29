defmodule YoutubeVideoChatApp.Repo do
  use Ecto.Repo,
    otp_app: :youtube_video_chat_app,
    adapter: Ecto.Adapters.Postgres
end
