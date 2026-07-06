defmodule YoutubeVideoChatApp.Repo.Migrations.CreateRoomPlaybackStates do
  use Ecto.Migration

  def change do
    # Write-through snapshot of each RoomServer's in-memory playback state
    # (current track, started_at, queue).  Restored on RoomServer init so
    # playback survives crashes, code reloads, and deploys.
    create table(:room_playback_states, primary_key: false) do
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :state, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end
  end
end
