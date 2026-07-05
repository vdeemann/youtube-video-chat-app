defmodule YoutubeVideoChatApp.AudioAnalysis.Worker do
  @moduledoc """
  Serializes analysis requests to the Essentia sidecar.

  One analysis runs at a time — the sidecar is CPU-bound, and loading a
  200-track playlist should queue work rather than flood it.  Requests are
  deduplicated in-memory (per boot) and against the DB cache.  Failed
  analyses are retried at most once an hour; stale "pending" rows from a
  previous boot are picked up again on request.
  """
  use GenServer
  require Logger
  alias YoutubeVideoChatApp.AudioAnalysis

  @retry_failed_after_s 3600
  # Download + Essentia + a ChordMini model pass on a 20-minute track can
  # legitimately take a while.
  @request_timeout :timer.minutes(10)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Queue a track for analysis.  `priority: :urgent` puts it at the front of
  the queue — used for the now-playing track so it isn't stuck behind a
  bulk playlist backlog.
  """
  def request(media_type, media_id, url, opts \\ []) do
    priority = Keyword.get(opts, :priority, :normal)
    GenServer.cast(__MODULE__, {:request, media_type, media_id, url, priority})
  end

  @impl true
  def init(_opts) do
    {:ok, %{queue: :queue.new(), keys: MapSet.new(), task: nil}}
  end

  @impl true
  def handle_cast({:request, type, id, url, priority}, state) do
    key = {type, id}

    cond do
      analyzer_url() == nil ->
        {:noreply, state}

      MapSet.member?(state.keys, key) ->
        {:noreply, state}

      not analyzable?(type, id) ->
        {:noreply, state}

      true ->
        AudioAnalysis.mark_pending(type, id)

        entry = {type, id, url}
        queue =
          case priority do
            :urgent -> :queue.in_r(entry, state.queue)
            _ -> :queue.in(entry, state.queue)
          end

        state = %{state | queue: queue, keys: MapSet.put(state.keys, key)}
        {:noreply, maybe_start_next(state)}
    end
  end

  @impl true
  def handle_info({ref, result}, %{task: {%Task{ref: ref}, {type, id}}} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, data} ->
        AudioAnalysis.complete(type, id, data)
        engine = data["chord_engine"] || "essentia"
        Logger.info("[AudioAnalysis] #{type}:#{id} → #{data["key"]} #{data["scale"]}, #{data["bpm"]} BPM (chords: #{engine})")

      {:error, reason} ->
        AudioAnalysis.fail(type, id, reason)
        Logger.warning("[AudioAnalysis] #{type}:#{id} failed: #{inspect(reason)}")
    end

    {:noreply, finish_current(state, {type, id})}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task: {%Task{ref: ref}, {type, id}}} = state) do
    AudioAnalysis.fail(type, id, "analysis task crashed: #{inspect(reason)}")
    {:noreply, finish_current(state, {type, id})}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ─────────────────────────────────────────────────────────────────

  defp finish_current(state, key) do
    %{state | task: nil, keys: MapSet.delete(state.keys, key)}
    |> maybe_start_next()
  end

  defp maybe_start_next(%{task: nil} = state) do
    case :queue.out(state.queue) do
      {{:value, {type, id, url}}, rest} ->
        task =
          Task.Supervisor.async_nolink(YoutubeVideoChatApp.TaskSupervisor, fn ->
            run_analysis(type, id, url)
          end)

        %{state | queue: rest, task: {task, {type, id}}}

      {:empty, _} ->
        state
    end
  end

  defp maybe_start_next(state), do: state

  defp analyzable?(type, id) do
    case AudioAnalysis.get(type, id) do
      nil -> true
      %{status: "complete"} -> false
      %{status: "pending"} -> true
      %{status: "failed", updated_at: at} ->
        DateTime.diff(DateTime.utc_now(), at) > @retry_failed_after_s
    end
  end

  defp run_analysis(type, id, url) do
    body = Jason.encode!(%{media_type: type, media_id: id, url: url})

    request =
      Finch.build(:post, analyzer_url() <> "/analyze", [{"content-type", "application/json"}], body)

    case Finch.request(request, YoutubeVideoChatApp.Finch, receive_timeout: @request_timeout) do
      {:ok, %Finch.Response{status: 200, body: resp}} ->
        {:ok, Jason.decode!(resp)}

      {:ok, %Finch.Response{status: status, body: resp}} ->
        {:error, "analyzer returned #{status}: #{String.slice(resp, 0, 200)}"}

      {:error, err} ->
        {:error, Exception.message(err)}
    end
  end

  defp analyzer_url do
    Application.get_env(:youtube_video_chat_app, :audio_analyzer, [])[:url]
  end
end
