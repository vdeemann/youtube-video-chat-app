defmodule YoutubeVideoChatApp.Repo.Migrations.CreatePlaylists do
  use Ecto.Migration

  def change do
    create table(:playlists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :is_main, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:playlists, [:user_id])
    create index(:playlists, [:user_id, :is_main])

    create table(:playlist_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :media_type, :string, null: false  # "youtube", "soundcloud", "bandcamp"
      add :media_id, :string, null: false    # video/track ID
      add :title, :string, null: false
      add :thumbnail, :text
      add :duration, :integer                 # in seconds
      add :embed_url, :text, null: false
      add :original_url, :text
      add :playlist_id, references(:playlists, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:playlist_items, [:playlist_id])
    create index(:playlist_items, [:playlist_id, :position])
  end
end
