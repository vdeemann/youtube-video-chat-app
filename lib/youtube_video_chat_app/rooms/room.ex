defmodule YoutubeVideoChatApp.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rooms" do
    field :name, :string
    field :slug, :string
    field :is_public, :boolean, default: true
    field :current_video_id, :string
    field :host_id, :string
    
    embeds_many :queue, Video, primary_key: false do
      field :youtube_id, :string
      field :title, :string
      field :thumbnail, :string
      field :duration, :integer
      field :added_by_username, :string
      field :added_by_id, :string
      field :added_at, :utc_datetime
    end
    
    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :is_public, :current_video_id, :host_id])
    |> validate_required([:name, :slug, :host_id])
    |> unique_constraint(:slug)
    |> cast_embed(:queue, with: &video_changeset/2)
  end

  defp video_changeset(video, attrs) do
    video
    |> cast(attrs, [:youtube_id, :title, :thumbnail, :duration, :added_by_username, :added_by_id, :added_at])
    |> validate_required([:youtube_id, :title])
  end
end
