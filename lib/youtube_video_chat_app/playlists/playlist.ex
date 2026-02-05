defmodule YoutubeVideoChatApp.Playlists.Playlist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "playlists" do
    field :name, :string
    field :description, :string
    field :is_main, :boolean, default: false

    belongs_to :user, YoutubeVideoChatApp.Accounts.User
    has_many :items, YoutubeVideoChatApp.Playlists.PlaylistItem, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:name, :description, :is_main, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> foreign_key_constraint(:user_id)
  end
end
