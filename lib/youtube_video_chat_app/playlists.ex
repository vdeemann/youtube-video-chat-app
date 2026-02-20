defmodule YoutubeVideoChatApp.Playlists do
  @moduledoc """
  The Playlists context - manage user playlists and playlist items.
  """

  import Ecto.Query, warn: false
  alias YoutubeVideoChatApp.Repo
  alias YoutubeVideoChatApp.Playlists.{Playlist, PlaylistItem}

  # ============================================================================
  # Playlist CRUD
  # ============================================================================

  @doc """
  Returns all playlists for a user.
  """
  def list_user_playlists(user_id) do
    Playlist
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], [desc: p.is_main, asc: p.name])
    |> Repo.all()
  end

  @doc """
  Returns all playlists for a user with item counts.
  """
  def list_user_playlists_with_counts(user_id) do
    Playlist
    |> where([p], p.user_id == ^user_id)
    |> join(:left, [p], i in PlaylistItem, on: i.playlist_id == p.id)
    |> group_by([p, i], p.id)
    |> select([p, i], {p, count(i.id)})
    |> order_by([p, i], [desc: p.is_main, asc: p.name])
    |> Repo.all()
    |> Enum.map(fn {playlist, count} -> Map.put(playlist, :item_count, count) end)
  end

  @doc """
  Gets a single playlist.
  """
  def get_playlist!(id), do: Repo.get!(Playlist, id)

  @doc """
  Gets a single playlist with its items preloaded.
  """
  def get_playlist_with_items!(id) do
    Playlist
    |> Repo.get!(id)
    |> Repo.preload(items: from(i in PlaylistItem, order_by: i.position))
  end

  @doc """
  Gets a playlist by id only if it belongs to the given user.
  """
  def get_user_playlist(user_id, playlist_id) do
    Playlist
    |> where([p], p.id == ^playlist_id and p.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets a user's main playlist.
  """
  def get_main_playlist(user_id) do
    Playlist
    |> where([p], p.user_id == ^user_id and p.is_main == true)
    |> Repo.one()
  end

  @doc """
  Gets a user's main playlist with items preloaded.
  """
  def get_main_playlist_with_items(user_id) do
    case get_main_playlist(user_id) do
      nil -> nil
      playlist -> Repo.preload(playlist, items: from(i in PlaylistItem, order_by: i.position))
    end
  end

  @doc """
  Creates a playlist.
  """
  def create_playlist(attrs \\ %{}) do
    %Playlist{}
    |> Playlist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a playlist.
  """
  def update_playlist(%Playlist{} = playlist, attrs) do
    playlist
    |> Playlist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a playlist.
  """
  def delete_playlist(%Playlist{} = playlist) do
    Repo.delete(playlist)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking playlist changes.
  """
  def change_playlist(%Playlist{} = playlist, attrs \\ %{}) do
    Playlist.changeset(playlist, attrs)
  end

  @doc """
  Sets a playlist as the main playlist for a user.
  Unsets any existing main playlist first.
  """
  def set_main_playlist(user_id, playlist_id) do
    Repo.transaction(fn ->
      # Unset current main playlist
      from(p in Playlist, where: p.user_id == ^user_id and p.is_main == true)
      |> Repo.update_all(set: [is_main: false])

      # Set new main playlist
      from(p in Playlist, where: p.id == ^playlist_id and p.user_id == ^user_id)
      |> Repo.update_all(set: [is_main: true])
    end)
  end

  @doc """
  Unsets the main playlist for a user.
  """
  def unset_main_playlist(user_id) do
    from(p in Playlist, where: p.user_id == ^user_id and p.is_main == true)
    |> Repo.update_all(set: [is_main: false])
  end

  # ============================================================================
  # Playlist Items CRUD
  # ============================================================================

  @doc """
  Gets a single playlist item.
  """
  def get_playlist_item!(id), do: Repo.get!(PlaylistItem, id)

  @doc """
  Adds an item to a playlist at the end.
  """
  def add_item_to_playlist(playlist_id, attrs) do
    # Get the next position
    max_position = 
      PlaylistItem
      |> where([i], i.playlist_id == ^playlist_id)
      |> select([i], max(i.position))
      |> Repo.one() || 0

    attrs = Map.put(attrs, :position, max_position + 1)
    attrs = Map.put(attrs, :playlist_id, playlist_id)

    %PlaylistItem{}
    |> PlaylistItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Adds multiple items to a playlist in a single batch insert.
  Much faster than calling add_item_to_playlist/2 in a loop for large playlists.
  """
  def add_items_to_playlist(playlist_id, items_attrs) when is_list(items_attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Get the current max position once
    max_position =
      PlaylistItem
      |> where([i], i.playlist_id == ^playlist_id)
      |> select([i], max(i.position))
      |> Repo.one() || 0

    # Build all rows with sequential positions
    rows =
      items_attrs
      |> Enum.with_index(max_position + 1)
      |> Enum.map(fn {attrs, position} ->
        %{
          id: Ecto.UUID.generate(),
          playlist_id: playlist_id,
          position: position,
          media_type: attrs[:media_type] || attrs["media_type"],
          media_id: attrs[:media_id] || attrs["media_id"],
          title: attrs[:title] || attrs["title"] || "Unknown",
          thumbnail: attrs[:thumbnail] || attrs["thumbnail"],
          duration: attrs[:duration] || attrs["duration"],
          embed_url: attrs[:embed_url] || attrs["embed_url"],
          original_url: attrs[:original_url] || attrs["original_url"],
          inserted_at: now,
          updated_at: now
        }
      end)

    # Insert in chunks of 500 to avoid query size limits
    rows
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all(PlaylistItem, chunk)
    end)

    {:ok, length(rows)}
  end

  @doc """
  Removes an item from a playlist.
  """
  def remove_item_from_playlist(item_id) do
    item = Repo.get!(PlaylistItem, item_id)
    Repo.delete(item)
  end

  @doc """
  Moves an item to a new position in the playlist.
  Reorders other items accordingly.
  """
  def move_item(item_id, new_position) do
    item = Repo.get!(PlaylistItem, item_id)
    old_position = item.position
    playlist_id = item.playlist_id

    Repo.transaction(fn ->
      cond do
        new_position > old_position ->
          # Moving down: decrease position of items between old and new
          from(i in PlaylistItem,
            where: i.playlist_id == ^playlist_id and i.position > ^old_position and i.position <= ^new_position
          )
          |> Repo.update_all(inc: [position: -1])

        new_position < old_position ->
          # Moving up: increase position of items between new and old
          from(i in PlaylistItem,
            where: i.playlist_id == ^playlist_id and i.position >= ^new_position and i.position < ^old_position
          )
          |> Repo.update_all(inc: [position: 1])

        true ->
          # No change needed
          :ok
      end

      # Update the item's position
      item
      |> PlaylistItem.changeset(%{position: new_position})
      |> Repo.update!()
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking playlist item changes.
  """
  def change_playlist_item(%PlaylistItem{} = item, attrs \\ %{}) do
    PlaylistItem.changeset(item, attrs)
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Converts playlist items to the format used in room queues.
  """
  def playlist_items_to_queue(items, user) do
    Enum.map(items, fn item ->
      %{
        id: Ecto.UUID.generate(),
        type: item.media_type,
        media_id: item.media_id,
        title: item.title,
        thumbnail: item.thumbnail,
        duration: item.duration || 180,
        embed_url: item.embed_url,
        original_url: item.original_url,
        added_by_username: user.username,
        added_by_id: user.id,
        added_at: DateTime.utc_now()
      }
    end)
  end

  @doc """
  Duplicates a playlist for a user (e.g., copying someone else's public playlist).
  """
  def duplicate_playlist(%Playlist{} = original, user_id, new_name \\ nil) do
    original = Repo.preload(original, :items)
    
    Repo.transaction(fn ->
      # Create the new playlist
      {:ok, new_playlist} = create_playlist(%{
        name: new_name || "#{original.name} (Copy)",
        description: original.description,
        user_id: user_id,
        is_main: false
      })

      # Copy all items
      Enum.each(original.items, fn item ->
        add_item_to_playlist(new_playlist.id, %{
          media_type: item.media_type,
          media_id: item.media_id,
          title: item.title,
          thumbnail: item.thumbnail,
          duration: item.duration,
          embed_url: item.embed_url,
          original_url: item.original_url
        })
      end)

      new_playlist
    end)
  end
end
