defmodule YoutubeVideoChatApp.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias YoutubeVideoChatApp.Repo
  alias YoutubeVideoChatApp.Rooms.{Room, RoomServer}

  def list_public_rooms do
    Room
    |> where([r], r.is_public == true)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def get_room_by_slug!(slug) do
    Repo.get_by!(Room, slug: slug)
  end

  @max_rooms_per_user 1

  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a room for a user, checking the room limit first.
  Returns {:error, :room_limit_reached} if user already has max rooms.
  """
  def create_room_for_user(attrs, user_id) do
    if count_user_rooms(user_id) >= @max_rooms_per_user do
      {:error, :room_limit_reached}
    else
      create_room(attrs)
    end
  end

  @doc """
  Returns the number of rooms owned by a user.
  """
  def count_user_rooms(user_id) do
    Room
    |> where([r], r.host_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns all rooms owned by a user.
  """
  def list_user_rooms(user_id) do
    Room
    |> where([r], r.host_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Checks if a user can create more rooms.
  """
  def can_create_room?(user_id) do
    count_user_rooms(user_id) < @max_rooms_per_user
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  def generate_room_slug do
    adjectives = ~w(cool epic awesome rad groovy funky fresh dope stellar cosmic)
    nouns = ~w(vibes beats jams tunes waves sounds rhythms melodies harmony bass)
    
    "#{Enum.random(adjectives)}-#{Enum.random(nouns)}-#{:rand.uniform(9999)}"
  end

  def ensure_room_server(room_id) do
    case RoomServer.get_state(room_id) do
      {:error, :room_not_found} ->
        # Start the room server
        DynamicSupervisor.start_child(
          YoutubeVideoChatApp.RoomSupervisor,
          {RoomServer, room_id}
        )
      _ ->
        :ok
    end
  end
end
