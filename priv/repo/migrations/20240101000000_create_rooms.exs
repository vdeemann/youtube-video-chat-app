defmodule YoutubeVideoChatApp.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :is_public, :boolean, default: true, null: false
      add :current_video_id, :string
      add :host_id, :string, null: false
      add :queue, :jsonb, default: "[]"
      
      timestamps()
    end

    create unique_index(:rooms, [:slug])
    create index(:rooms, [:is_public])
    create index(:rooms, [:inserted_at])
  end
end
