defmodule YoutubeVideoChatApp.AudioAnalysis do
  @moduledoc """
  Musical analysis (key, BPM, chord timeline) for queued tracks.

  The actual signal processing runs in the Essentia sidecar service (see
  `analyzer/`), reached over HTTP.  Results are cached in the
  `track_analyses` table keyed by `{media_type, media_id}` so each track
  is only ever analyzed once, no matter how many rooms play it.

  Completed analyses are broadcast on the `"track_analysis"` PubSub topic
  as `{:track_analysis, payload}` — a single global topic is fine because
  at most one analysis finishes at a time (the worker is serial).
  """
  import Ecto.Query
  alias Phoenix.PubSub
  alias YoutubeVideoChatApp.AudioAnalysis.TrackAnalysis
  alias YoutubeVideoChatApp.Repo

  @topic "track_analysis"

  def subscribe, do: PubSub.subscribe(YoutubeVideoChatApp.PubSub, @topic)

  def get(media_type, media_id) when is_binary(media_type) and is_binary(media_id) do
    Repo.get_by(TrackAnalysis, media_type: media_type, media_id: media_id)
  end

  def get(_media_type, _media_id), do: nil

  @doc """
  Batch lookup for queue rendering.  Returns a map of
  `{media_type, media_id} => payload` containing only complete analyses.
  """
  def get_payloads([]), do: %{}

  def get_payloads(keys) when is_list(keys) do
    conditions =
      Enum.reduce(keys, false, fn {type, id}, acc ->
        dynamic([a], (a.media_type == ^type and a.media_id == ^id) or ^acc)
      end)

    from(a in TrackAnalysis, where: ^conditions, where: a.status == "complete")
    |> Repo.all()
    |> Map.new(fn a -> {{a.media_type, a.media_id}, payload(a)} end)
  end

  @doc """
  Request analysis for a queue media map (async, non-blocking).  No-op when
  the analyzer is disabled, the media has no resolvable source URL, or a
  result is already cached.  Pass `priority: :urgent` for the now-playing
  track so it skips ahead of bulk playlist backlogs.
  """
  def request_for_media(media, opts \\ []) do
    type = media[:type] || media["type"]
    id = media[:media_id] || media["media_id"]

    case source_url(type, id, media[:original_url] || media["original_url"]) do
      nil -> :ok
      url -> YoutubeVideoChatApp.AudioAnalysis.Worker.request(type, id, url, opts)
    end
  end

  # YouTube queue entries only carry the video ID; SoundCloud media_ids are
  # URL hashes, so the original URL is the only usable source there.
  @doc false
  def source_url("youtube", id, _url) when is_binary(id), do: "https://www.youtube.com/watch?v=" <> id
  def source_url("soundcloud", _id, url) when is_binary(url), do: url
  def source_url(_type, _id, _url), do: nil

  @doc "Client-facing payload for a complete analysis (nil otherwise)."
  def payload(%TrackAnalysis{status: "complete"} = a) do
    %{
      media_type: a.media_type,
      media_id: a.media_id,
      key: a.key,
      scale: a.scale,
      bpm: a.bpm && round(a.bpm),
      chords: (a.chords || %{})["segments"] || []
    }
  end

  def payload(_analysis), do: nil

  # -- Worker-facing persistence -----------------------------------------------

  def mark_pending(media_type, media_id) do
    upsert(%{media_type: media_type, media_id: media_id, status: "pending", error: nil})
  end

  def complete(media_type, media_id, result) do
    {:ok, analysis} =
      upsert(%{
        media_type: media_type,
        media_id: media_id,
        status: "complete",
        key: result["key"],
        scale: result["scale"],
        key_strength: result["key_strength"],
        bpm: result["bpm"],
        chords: %{"segments" => result["chords"] || []},
        error: nil
      })

    PubSub.broadcast(YoutubeVideoChatApp.PubSub, @topic, {:track_analysis, payload(analysis)})
    {:ok, analysis}
  end

  def fail(media_type, media_id, reason) do
    upsert(%{
      media_type: media_type,
      media_id: media_id,
      status: "failed",
      error: reason |> to_string() |> String.slice(0, 500)
    })
  end

  defp upsert(attrs) do
    %TrackAnalysis{}
    |> TrackAnalysis.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :media_type, :media_id, :inserted_at]},
      conflict_target: [:media_type, :media_id],
      returning: true
    )
  end
end
