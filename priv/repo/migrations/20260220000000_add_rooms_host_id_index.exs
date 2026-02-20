defmodule YoutubeVideoChatApp.Repo.Migrations.AddRoomsHostIdIndex do
  use Ecto.Migration

  def change do
    create index(:rooms, [:host_id, :inserted_at])
  end
end
