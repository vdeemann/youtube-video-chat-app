defmodule YoutubeVideoChatApp.Rooms.RoomServer do
  @moduledoc """
  GenServer that owns all room playback state.

  ## Design principles
  1. **Single flat queue** – tracks are inserted in round-robin order at
     add-time so we never need to rebuild the queue on read.
  2. **Server-authoritative time** – `started_at` (UTC ms) marks when
     position 0 of the current track began.  Any client can compute its
     seek position as `(now_ms - started_at) / 1000`.
  3. **Server-side auto-advance** – a `Process.send_after` timer fires
     when the track *should* be over.  Client `video_ended` reports
     cancel the timer and advance immediately.
  4. **One broadcast** – every mutation that clients care about sends
     `{:room_state_changed, map}` so the LiveView has a single handler.

  ## Performance
  - Queue uses Erlang `:queue` for O(1) append and O(1) pop.
  - Broadcasts send only a limited preview of the queue (first 50 items)
    plus total count, to avoid serializing large queues over WebSocket.
  - Queue length is cached and maintained via arithmetic (never recomputed).

  Terminates after 30 min of inactivity.
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  @idle_timeout :timer.minutes(30)
  @auto_advance_buffer_s 5
  @queue_broadcast_limit 50

  defstruct [
    :room_id,
    :host_id,
    current_track: nil,       # media map or nil
    started_at: nil,          # ms since epoch when track position 0 corresponds to
    queue: :queue.new(),      # Erlang :queue of media maps in play order
    queue_length: 0,          # cached length for O(1) access
    track_timer: nil,         # timer ref for auto-advance
    messages: []              # recent chat messages
  ]

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(room_id),
    do: GenServer.start_link(__MODULE__, room_id, name: via(room_id))

  def get_state(room_id),          do: call(room_id, :get_state)
  def get_messages(room_id),       do: call(room_id, :get_messages)
  def add_to_queue(room_id, m, u), do: call(room_id, {:add_to_queue, m, u})
  def add_multiple_to_queue(room_id, items, u),
    do: call(room_id, {:add_multiple_to_queue, items, u})
  def play_next(room_id),          do: call(room_id, :play_next)
  def track_ended(room_id, track_id \\ nil),
    do: call(room_id, {:track_ended, track_id})
  def remove_from_queue(room_id, id),
    do: cast(room_id, {:remove_from_queue, id})
  def remove_from_queue_by_user(room_id, id, uid),
    do: cast(room_id, {:remove_from_queue_by_user, id, uid})
  def clear_queue(room_id),
    do: cast(room_id, :clear_queue)
  def report_progress(room_id, current_s, duration_s),
    do: cast(room_id, {:report_progress, current_s, duration_s})
  def add_message(room_id, msg),
    do: cast(room_id, {:add_message, msg})
  def get_queue_page(room_id, offset, limit),
    do: call(room_id, {:get_queue_page, offset, limit})

  defp via(id), do: {:via, Registry, {YoutubeVideoChatApp.RoomRegistry, id}}

  defp call(id, msg) do
    GenServer.call(via(id), msg)
  catch
    :exit, _ -> {:error, :room_not_found}
  end

  defp cast(id, msg) do
    GenServer.cast(via(id), msg)
  catch
    :exit, _ -> :ok
  end

  # ── Callbacks ───────────────────────────────────────────────────────────────

  @impl true
  def init(room_id) do
    room = YoutubeVideoChatApp.Rooms.get_room!(room_id)
    state = %__MODULE__{room_id: room_id, host_id: room.host_id}
    {:ok, state, @idle_timeout}
  end

  # --- get_state: return everything the client needs --------------------------

  @impl true
  def handle_call(:get_state, _from, st) do
    {:reply, {:ok, public_state(st)}, st, @idle_timeout}
  end

  @impl true
  def handle_call(:get_messages, _from, st) do
    {:reply, {:ok, st.messages}, st, @idle_timeout}
  end

  # --- get_queue_page: return a slice of the queue for pagination -------------

  @impl true
  def handle_call({:get_queue_page, offset, limit}, _from, st) do
    items = st.queue
    |> :queue.to_list()
    |> Enum.drop(offset)
    |> Enum.take(limit)
    {:reply, {:ok, items, st.queue_length}, st, @idle_timeout}
  end

  # --- add_to_queue -----------------------------------------------------------

  @impl true
  def handle_call({:add_to_queue, media_data, user}, _from, st) do
    media = build_media(media_data, user)
    st = st
    |> enqueue_tracks([media])
    |> maybe_start_playing()
    broadcast(st)
    {:reply, {:ok, media}, st, @idle_timeout}
  end

  @impl true
  def handle_call({:add_multiple_to_queue, items, user}, _from, st) do
    medias = Enum.map(items, &build_media(&1, user))
    st = st
    |> enqueue_tracks(medias)
    |> maybe_start_playing()
    broadcast(st)
    {:reply, {:ok, length(medias)}, st, @idle_timeout}
  end

  # --- play_next (skip) -------------------------------------------------------

  @impl true
  def handle_call(:play_next, _from, st) do
    {:reply, :ok, advance(st), @idle_timeout}
  end

  # --- track_ended (any client reports) ---------------------------------------
  # Deduplicated: if a track_id is provided, only advance when it matches the
  # currently-playing track.  This prevents a newly-joined client whose player
  # fires a spurious "ended" event from skipping the track that everyone else
  # is still listening to.

  @impl true
  def handle_call({:track_ended, reported_id}, _from, st) do
    current_id = st.current_track && st.current_track.id
    cond do
      # Nothing playing — ignore
      current_id == nil ->
        {:reply, :ok, st, @idle_timeout}

      # Client sent a track_id that doesn't match what's playing — stale/spurious, ignore
      reported_id != nil and reported_id != current_id ->
        Logger.debug("[RoomServer] Ignoring stale track_ended for #{reported_id}, current is #{current_id}")
        {:reply, :ok, st, @idle_timeout}

      # Matches (or legacy client sent nil) — advance
      true ->
        {:reply, :ok, advance(st), @idle_timeout}
    end
  end

  # --- remove from queue ------------------------------------------------------

  @impl true
  def handle_cast({:remove_from_queue, media_id}, st) do
    st = filter_queue(st, fn item -> item.id != media_id end)
    broadcast(st)
    {:noreply, st, @idle_timeout}
  end

  @impl true
  def handle_cast({:remove_from_queue_by_user, media_id, user_id}, st) do
    old_len = st.queue_length
    st = filter_queue(st, fn item ->
      not (item.id == media_id && item.added_by_id == user_id)
    end)
    if st.queue_length < old_len, do: broadcast(st)
    {:noreply, st, @idle_timeout}
  end

  # --- clear queue --------------------------------------------------------------

  @impl true
  def handle_cast(:clear_queue, st) do
    st = %{st | queue: :queue.new(), queue_length: 0}
    broadcast(st)
    {:noreply, st, @idle_timeout}
  end

  # --- host progress reports (recalibrate started_at) -------------------------

  @impl true
  def handle_cast({:report_progress, current_s, duration_s}, st) do
    now = now_ms()
    # Recalibrate: started_at = now - (current_s * 1000)
    st = %{st | started_at: round(now - current_s * 1000)}
    # Update current_track duration with the real value from the player
    st = if duration_s > 0 && st.current_track do
      %{st | current_track: Map.put(st.current_track, :duration, duration_s)}
    else
      st
    end
    # Reschedule timer with real duration
    st = if duration_s > 0 do
      remaining = max(0, duration_s - current_s) + @auto_advance_buffer_s
      schedule_timer(st, remaining)
    else
      st
    end
    {:noreply, st, @idle_timeout}
  end

  # --- chat messages ----------------------------------------------------------

  @impl true
  def handle_cast({:add_message, msg}, st) do
    {:noreply, %{st | messages: [msg | st.messages] |> Enum.take(50)}, @idle_timeout}
  end

  # --- timer ------------------------------------------------------------------

  @impl true
  def handle_info(:auto_advance, st) do
    Logger.info("[RoomServer] Auto-advancing track for room #{st.room_id}")
    {:noreply, %{st | track_timer: nil} |> advance(), @idle_timeout}
  end

  @impl true
  def handle_info(:timeout, st), do: {:stop, :normal, st}

  # ── Private helpers ─────────────────────────────────────────────────────────

  # -- Advance to the next track -----------------------------------------------

  defp advance(st) do
    st = cancel_timer(st)
    case :queue.out(st.queue) do
      {{:value, next}, rest} ->
        st = %{st |
          current_track: next,
          started_at: now_ms(),
          queue: rest,
          queue_length: st.queue_length - 1
        }
        |> schedule_timer_for_track(next)
        broadcast(st)
        st

      {:empty, _} ->
        st = %{st | current_track: nil, started_at: nil}
        broadcast(st)
        st
    end
  end

  # -- Start playing if nothing is playing -------------------------------------

  defp maybe_start_playing(%{current_track: nil} = st) do
    case :queue.out(st.queue) do
      {{:value, next}, rest} ->
        %{st |
          current_track: next,
          started_at: now_ms(),
          queue: rest,
          queue_length: st.queue_length - 1
        }
        |> schedule_timer_for_track(next)

      {:empty, _} ->
        st
    end
  end
  defp maybe_start_playing(st), do: st

  # -- Enqueue tracks with O(1) append ----------------------------------------

  defp enqueue_tracks(st, new_tracks) do
    Enum.reduce(new_tracks, st, fn track, acc ->
      %{acc |
        queue: :queue.in(track, acc.queue),
        queue_length: acc.queue_length + 1
      }
    end)
  end

  # -- Filter queue (for remove operations) ------------------------------------
  # We count removed items via fold instead of calling :queue.len/1 (which is O(n)).
  # Since we're removing at most 1 item in practice, this is effectively O(n) once
  # for the filter pass, not O(n) filter + O(n) len.

  defp filter_queue(st, filter_fn) do
    {new_queue, removed} = :queue.fold(fn item, {q, r} ->
      if filter_fn.(item), do: {:queue.in(item, q), r}, else: {q, r + 1}
    end, {:queue.new(), 0}, st.queue)
    %{st |
      queue: new_queue,
      queue_length: st.queue_length - removed
    }
  end

  # -- Timer helpers -----------------------------------------------------------

  defp schedule_timer_for_track(st, track) do
    duration = (track[:duration] || track.duration || 300)
    # Use a generous initial timer since the default duration (180s) from URL
    # parsing is often wrong.  The host's progress reports will reschedule
    # the timer with the real duration, so this just needs to be long enough
    # to avoid premature auto-advance on longer tracks.
    safe_duration = max(duration, 600)
    schedule_timer(st, safe_duration + @auto_advance_buffer_s)
  end

  defp schedule_timer(st, seconds) do
    st = cancel_timer(st)
    ref = Process.send_after(self(), :auto_advance, round(seconds * 1000))
    %{st | track_timer: ref}
  end

  defp cancel_timer(%{track_timer: nil} = st), do: st
  defp cancel_timer(%{track_timer: ref} = st) do
    Process.cancel_timer(ref)
    %{st | track_timer: nil}
  end

  # -- Build media map ---------------------------------------------------------

  defp build_media(data, user) do
    get = fn key -> data[key] || data[to_string(key)] end
    %{
      id: Ecto.UUID.generate(),
      type: get.(:type),
      media_id: get.(:media_id),
      title: get.(:title) || "Unknown",
      thumbnail: get.(:thumbnail),
      duration: get.(:duration) || 300,
      embed_url: get.(:embed_url),
      original_url: get.(:original_url),
      added_by_username: user.username,
      added_by_id: user.id,
      added_by_color: user.color,
      added_at: DateTime.utc_now()
    }
  end

  # -- Public state snapshot ---------------------------------------------------

  defp public_state(st) do
    # Send only the first N queue items to reduce WebSocket payload size.
    # Clients request additional pages via get_queue_page/3.
    queue_preview = st.queue
    |> :queue.to_list()
    |> Enum.take(@queue_broadcast_limit)

    %{
      current_track: st.current_track,
      started_at: st.started_at,
      server_now: now_ms(),
      queue: queue_preview,
      queue_length: st.queue_length
    }
  end

  # -- Broadcast ---------------------------------------------------------------

  defp broadcast(st) do
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{st.room_id}",
      {:room_state_changed, public_state(st)}
    )
  end

  defp now_ms, do: System.system_time(:millisecond)
end
