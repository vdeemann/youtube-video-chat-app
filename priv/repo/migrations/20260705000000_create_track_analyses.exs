defmodule YoutubeVideoChatApp.Repo.Migrations.CreateTrackAnalyses do
  use Ecto.Migration

  def change do
    create table(:track_analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :media_type, :string, null: false   # "youtube", "soundcloud"
      add :media_id, :string, null: false
      add :status, :string, null: false, default: "pending"  # pending | complete | failed
      add :key, :string                        # e.g. "A"
      add :scale, :string                      # "major" | "minor"
      add :key_strength, :float
      add :bpm, :float
      add :chords, :map                        # %{"segments" => [%{"t" => 12.4, "c" => "Am"}, ...]}
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:track_analyses, [:media_type, :media_id])
  end
end
