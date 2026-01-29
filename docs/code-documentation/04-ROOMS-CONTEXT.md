# 04-ROOMS-CONTEXT.md - Room Management Business Logic

## File: `lib/youtube_video_chat_app/rooms.ex`

This module is the **Context** for room management. In Phoenix, contexts are the public API for a domain of your application.

## Complete Source Code

```elixir
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

  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
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
        DynamicSupervisor.start_child(
          YoutubeVideoChatApp.RoomSupervisor,
          {RoomServer, room_id}
        )
      _ ->
        :ok
    end
  end
end
```

## Line-by-Line Explanation

### Module Definition & Documentation

```elixir
defmodule YoutubeVideoChatApp.Rooms do
  @moduledoc """
  The Rooms context.
  """
```

- **Context Pattern**: Contexts are Phoenix's recommended way to organize business logic
- **Boundary**: This module defines the public API for all room-related operations
- **Isolation**: Other parts of the app (LiveViews, controllers) should only access room data through this context

### Imports and Aliases

```elixir
  import Ecto.Query, warn: false
  alias YoutubeVideoChatApp.Repo
  alias YoutubeVideoChatApp.Rooms.{Room, RoomServer}
```

| Import/Alias | Purpose |
|--------------|---------|
| `import Ecto.Query` | Allows using query macros like `where/3`, `order_by/3` |
| `warn: false` | Suppresses "unused import" warnings |
| `alias Repo` | Shorthand for database operations |
| `alias Room` | Shorthand for the Room schema |
| `alias RoomServer` | Shorthand for the room GenServer |

### List Public Rooms

```elixir
  def list_public_rooms do
    Room
    |> where([r], r.is_public == true)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end
```

**Purpose**: Retrieves all rooms marked as public for the room lobby

**Step-by-step**:
1. `Room` - Start with the Room schema
2. `|> where([r], r.is_public == true)` - Filter to only public rooms
   - `[r]` binds the room to variable `r`
   - SQL equivalent: `WHERE is_public = true`
3. `|> order_by([r], desc: r.inserted_at)` - Sort newest first
   - SQL equivalent: `ORDER BY inserted_at DESC`
4. `|> Repo.all()` - Execute query, return list of Room structs

**Return value**: `[%Room{}, %Room{}, ...]`

### Get Room by ID

```elixir
  def get_room!(id) do
    Repo.get!(Room, id)
  end
```

**Purpose**: Fetch a single room by its UUID primary key

**Behavior**:
- Returns `%Room{}` if found
- **Raises** `Ecto.NoResultsError` if not found
- The `!` in function name signals it may raise

**Usage**:
```elixir
room = Rooms.get_room!("550e8400-e29b-41d4-a716-446655440000")
```

### Get Room by Slug

```elixir
  def get_room_by_slug!(slug) do
    Repo.get_by!(Room, slug: slug)
  end
```

**Purpose**: Find room by its URL-friendly slug (e.g., "cool-vibes-1234")

**Why slugs?**:
- More readable URLs: `/room/cool-vibes-1234` vs `/room/550e8400-e29b-...`
- Unique identifier for sharing
- User-friendly

**Usage**: Called by LiveView when user navigates to `/room/:slug`

### Create Room

```elixir
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end
```

**Purpose**: Create a new room in the database

**Flow**:
1. `%Room{}` - Start with empty Room struct
2. `|> Room.changeset(attrs)` - Validate and cast attributes
3. `|> Repo.insert()` - Insert into database

**Return values**:
- `{:ok, %Room{}}` - Success
- `{:error, %Ecto.Changeset{}}` - Validation failed

**Default parameter**: `attrs \\ %{}` means empty map if no argument provided

### Update Room

```elixir
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end
```

**Purpose**: Update an existing room's attributes

**Pattern match**: `%Room{} = room` ensures input is a Room struct

**Return values**: Same as `create_room/1`

### Delete Room

```elixir
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end
```

**Purpose**: Remove a room from the database

**Return values**:
- `{:ok, %Room{}}` - Successfully deleted
- `{:error, %Ecto.Changeset{}}` - Deletion failed (e.g., constraint violation)

### Generate Room Slug

```elixir
  def generate_room_slug do
    adjectives = ~w(cool epic awesome rad groovy funky fresh dope stellar cosmic)
    nouns = ~w(vibes beats jams tunes waves sounds rhythms melodies harmony bass)
    
    "#{Enum.random(adjectives)}-#{Enum.random(nouns)}-#{:rand.uniform(9999)}"
  end
```

**Purpose**: Create unique, memorable room URLs

**Breakdown**:
1. `~w(...)` - Word list sigil, creates list of strings
2. `Enum.random(adjectives)` - Pick random adjective
3. `Enum.random(nouns)` - Pick random noun
4. `:rand.uniform(9999)` - Random number 1-9999
5. String interpolation combines them

**Examples**:
- `"cool-vibes-4523"`
- `"epic-beats-8901"`
- `"funky-rhythms-1234"`

**Uniqueness**: Database has unique constraint on `slug` column

### Ensure Room Server

```elixir
  def ensure_room_server(room_id) do
    case RoomServer.get_state(room_id) do
      {:error, :room_not_found} ->
        DynamicSupervisor.start_child(
          YoutubeVideoChatApp.RoomSupervisor,
          {RoomServer, room_id}
        )
      _ ->
        :ok
    end
  end
```

**Purpose**: Start a RoomServer process for a room if one doesn't exist

**Flow**:
1. Try to get the room's state from RoomServer
2. If `{:error, :room_not_found}`:
   - Start new RoomServer via DynamicSupervisor
   - `{RoomServer, room_id}` - Child spec with room_id argument
3. If already exists (`_` matches any other result):
   - Return `:ok`

**Why DynamicSupervisor?**:
- Creates child processes on-demand (not at app startup)
- Each room gets its own RoomServer process
- Processes are supervised and will restart if they crash

## Usage Examples

### In LiveView Mount

```elixir
def mount(%{"slug" => slug}, _session, socket) do
  room = Rooms.get_room_by_slug!(slug)
  Rooms.ensure_room_server(room.id)
  # ...
end
```

### Creating a New Room

```elixir
def handle_event("create_room", %{"name" => name}, socket) do
  attrs = %{
    name: name,
    slug: Rooms.generate_room_slug(),
    host_id: socket.assigns.user.id
  }
  
  case Rooms.create_room(attrs) do
    {:ok, room} ->
      {:noreply, push_navigate(socket, to: ~p"/room/#{room.slug}")}
    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to create room")}
  end
end
```

## Context Boundaries

### What Belongs in This Context
- ✅ Room CRUD operations
- ✅ Room querying
- ✅ Room server lifecycle management
- ✅ Slug generation

### What Doesn't Belong Here
- ❌ User authentication (→ Accounts context)
- ❌ Chat message handling (→ handled by RoomServer/LiveView)
- ❌ Video parsing (→ handled by LiveView)

## Related Files

| File | Relationship |
|------|--------------|
| `rooms/room.ex` | Schema definition |
| `rooms/room_server.ex` | Runtime state management |
| `live/room_live/show.ex` | Uses context functions |
| `application.ex` | Starts DynamicSupervisor |
