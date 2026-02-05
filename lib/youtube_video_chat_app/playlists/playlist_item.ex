defmodule YoutubeVideoChatApp.Playlists.PlaylistItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "playlist_items" do
    field :position, :integer
    field :media_type, :string
    field :media_id, :string
    field :title, :string
    field :thumbnail, :string
    field :duration, :integer
    field :embed_url, :string
    field :original_url, :string

    belongs_to :playlist, YoutubeVideoChatApp.Playlists.Playlist

    timestamps()
  end

  @doc false
  def changeset(playlist_item, attrs) do
    playlist_item
    |> cast(attrs, [:position, :media_type, :media_id, :title, :thumbnail, :duration, :embed_url, :original_url, :playlist_id])
    |> validate_required([:position, :media_type, :media_id, :title, :embed_url, :playlist_id])
    |> validate_inclusion(:media_type, ["youtube", "soundcloud", "bandcamp"])
    |> foreign_key_constraint(:playlist_id)
  end

  @doc """
  Convert a playlist item to the format used in room queues.
  """
  def to_queue_item(%__MODULE__{} = item) do
    %{
      id: Ecto.UUID.generate(),
      type: item.media_type,
      media_id: item.media_id,
      title: item.title,
      thumbnail: item.thumbnail,
      duration: item.duration || 180,
      embed_url: item.embed_url,
      original_url: item.original_url
    }
  end
end
