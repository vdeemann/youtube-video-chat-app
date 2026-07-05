defmodule YoutubeVideoChatApp.AudioAnalysis.TrackAnalysis do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @statuses ~w(pending complete failed)

  schema "track_analyses" do
    field :media_type, :string
    field :media_id, :string
    field :status, :string, default: "pending"
    field :key, :string
    field :scale, :string
    field :key_strength, :float
    field :bpm, :float
    field :chords, :map
    field :error, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [:media_type, :media_id, :status, :key, :scale, :key_strength, :bpm, :chords, :error])
    |> validate_required([:media_type, :media_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:media_type, :media_id])
  end
end
