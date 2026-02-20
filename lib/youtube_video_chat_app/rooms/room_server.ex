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

  Terminates after 30 min of inactivity.
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  @idle_timeout :timer.minutes(30)
  @auto_advance_buffer_s 5

  defstruct [
    :room_id,
    :host_id,
    current_track: nil,       # media map or nil
    started_at: nil,          # ms since epoch when track position 0 corresponds to
    queue: [],                # flat list of media maps in play order
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
  def track_ended(room_id),        do: call(room_id, :track_ended)
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

  # --- add_to_queue -----------------------------------------------------------

  @impl true
  def handle_call({:add_to_queue, media_data, user}, _from, st) do
    media = build_media(media_data, user)
    st = st
    |> insert_into_queue(user, [media])
    |> maybe_start_playing()
    broadcast(st)
    {:reply, {:ok, media}, st, @idle_timeout}
  end

  @impl true
  def handle_call({:add_multiple_to_queue, items, user}, _from, st) do
    medias = Enum.map(items, &build_media(&1, user))
    st = st
    |> insert_into_queue(user, medias)
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

  @impl true
  def handle_call(:track_ended, _from, st) do
    if st.current_track do
      {:reply, :ok, advance(st), @idle_timeout}
    else
      {:reply, :ok, st, @idle_timeout}
    end
  end

  # --- remove from queue ------------------------------------------------------

  @impl true
  def handle_cast({:remove_from_queue, media_id}, st) do
    st = %{st | queue: Enum.reject(st.queue, &(&1.id == media_id))}
    broadcast(st)
    {:noreply, st, @idle_timeout}
  end

  @impl true
  def handle_cast({:remove_from_queue_by_user, media_id, user_id}, st) do
    original_len = length(st.queue)
    new_queue = Enum.reject(st.queue, &(&1.id == media_id && &1.added_by_id == user_id))
    if length(new_queue) < original_len do
      st = %{st | queue: new_queue}
      broadcast(st)
    end
    {:noreply, st, @idle_timeout}
  end

  # --- clear queue --------------------------------------------------------------

  @impl true
  def handle_cast(:clear_queue, st) do
    st = %{st | queue: []}
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
    case st.queue do
      [next | rest] ->
        st = %{st |
          current_track: next,
          started_at: now_ms(),
          queue: rest
        }
        |> schedule_timer_for_track(next)
        broadcast(st)
        st

      [] ->
        st = %{st | current_track: nil, started_at: nil}
        broadcast(st)
        st
    end
  end

  # -- Start playing if nothing is playing -------------------------------------

  defp maybe_start_playing(%{current_track: nil, queue: [next | rest]} = st) do
    st = %{st |
      current_track: next,
      started_at: now_ms(),
      queue: rest
    }
    |> schedule_timer_for_track(next)
    st
  end
  defp maybe_start_playing(st), do: st

  # -- Round-robin insert: interleave new tracks fairly ------------------------

  defp insert_into_queue(st, _user, new_tracks) do
    # Insert each new track at the end of the queue.
    Enum.reduce(new_tracks, st, fn track, acc ->
      %{acc | queue: acc.queue ++ [track]}
    end)
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
    # Return the raw started_at without capping.
    #
    # Previously this function tried to cap elapsed time to the track's
    # duration to prevent seeking past the end on rejoin.  However, the
    # initial duration stored on the track is a hardcoded guess (180s)
    # from URL parsing.  If the real track is longer than 180s and the
    # host hasn't reported progress yet (or everyone left and rejoined),
    # the cap would force all clients to seek back to ~175s (2:55).
    #
    # The client-side sync loop already handles drift correction and
    # end-of-track detection, so this server-side cap is unnecessary
    # and actively harmful.  The host's progress reports update both
    # started_at and the track's real duration, keeping everything
    # calibrated without needing an artificial cap here.
    %{
      current_track: st.current_track,
      started_at: st.started_at,
      server_now: now_ms(),
      queue: st.queue
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
