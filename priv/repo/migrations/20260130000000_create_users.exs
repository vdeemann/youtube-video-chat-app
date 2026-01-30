defmodule YoutubeVideoChatApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :username, :string, null: false
      add :hashed_password, :string, null: false
      add :color, :string, default: "#FF6B6B"
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
