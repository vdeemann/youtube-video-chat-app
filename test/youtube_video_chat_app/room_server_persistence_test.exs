defmodule YoutubeVideoChatApp.RoomServerPersistenceTest do
  use YoutubeVideoChatApp.DataCase, async: false

  alias YoutubeVideoChatApp.{Accounts, Rooms}
  alias YoutubeVideoChatApp.Rooms.RoomServer

  defp media(title) do
    %{
      "type" => "youtube",
      "media_id" => "abcdefghijk",
      "title" => title,
      "thumbnail" => "thumb",
      "duration" => 200,
      "embed_url" => "https://example.com/embed"
    }
  end

  defp eventually(fun, tries \\ 50) do
    case fun.() do
      nil when tries > 0 ->
        Process.sleep(20)
        eventually(fun, tries - 1)

      nil ->
        flunk("condition never became true")

      result ->
        result
    end
  end

  test "playback state survives a RoomServer crash" do
    user = Accounts.create_guest_user()

    {:ok, room} =
      Rooms.create_room(%{
        name: "persist test",
        slug: "persist-#{System.unique_integer([:positive])}",
        host_id: user.id
      })

    on_exit(fn ->
      case Registry.lookup(YoutubeVideoChatApp.RoomRegistry, room.id) do
        [{pid, _}] -> DynamicSupervisor.terminate_child(YoutubeVideoChatApp.RoomSupervisor, pid)
        _ -> :ok
      end
    end)

    Rooms.ensure_room_server(room.id)
    {:ok, _} = RoomServer.add_to_queue(room.id, media("First"), user)
    {:ok, _} = RoomServer.add_to_queue(room.id, media("Second"), user)

    {:ok, before} = RoomServer.get_state(room.id)
    assert before.current_track.title == "First"
    assert before.queue_length == 1

    # Kill the server the way a crash or code reload would — no terminate
    # callback, no cleanup.  The DynamicSupervisor restarts it.
    [{pid, _}] = Registry.lookup(YoutubeVideoChatApp.RoomRegistry, room.id)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, _, :killed}

    restored =
      eventually(fn ->
        case RoomServer.get_state(room.id) do
          {:ok, %{current_track: %{title: "First"}} = state} -> state
          _ -> nil
        end
      end)

    assert restored.current_track.media_id == before.current_track.media_id
    assert restored.started_at == before.started_at
    assert restored.queue_length == 1
    assert [%{title: "Second"}] = restored.queue
  end

  test "save/load round-trips playback state" do
    user = Accounts.create_guest_user()

    {:ok, room} =
      Rooms.create_room(%{
        name: "roundtrip test",
        slug: "roundtrip-#{System.unique_integer([:positive])}",
        host_id: user.id
      })

    assert Rooms.load_playback_state(room.id) == nil

    :ok = Rooms.save_playback_state(room.id, %{"started_at" => 123, "queue" => []})
    :ok = Rooms.save_playback_state(room.id, %{"started_at" => 456, "queue" => []})

    assert %{"started_at" => 456} = Rooms.load_playback_state(room.id)
  end
end
