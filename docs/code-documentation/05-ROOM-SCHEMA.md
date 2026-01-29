# 05-ROOM-SCHEMA.md - Room Database Schema

## File: `lib/youtube_video_chat_app/rooms/room.ex`

This file defines the Room schema - the data structure for rooms stored in the database.

## Complete Source Code

```elixir
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
```

## Line-by-Line Explanation

### Module Definition

```elixir
defmodule YoutubeVideoChatApp.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset
```

| Statement | Purpose |
|-----------|---------|
| `use Ecto.Schema` | Provides `schema/2` macro for defining database fields |
| `import Ecto.Changeset` | Imports `cast/3`, `validate_required/2`, etc. |

### Primary Key Configuration

```elixir
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
```

**`@primary_key`**:
- `:id` - Field name
- `:binary_id` - UUID type (instead of auto-incrementing integer)
- `autogenerate: true` - Ecto generates UUIDs automatically

**`@foreign_key_type`**:
- All foreign keys in this schema will be UUIDs
- Ensures consistency when referencing other tables

**Why UUIDs?**:
- Globally unique (no collisions across servers)
- Non-sequential (harder to guess room IDs)
- Better for distributed systems

### Schema Definition

```elixir
  schema "rooms" do
```

- `"rooms"` is the database table name
- Must match the migration that created the table

### Field Definitions

```elixir
    field :name, :string
    field :slug, :string
    field :is_public, :boolean, default: true
    field :current_video_id, :string
    field :host_id, :string
```

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Display name of the room |
| `slug` | string | URL-friendly identifier (e.g., "cool-vibes-1234") |
| `is_public` | boolean | Whether room appears in public list |
| `current_video_id` | string | Currently playing video (stored for persistence) |
| `host_id` | string | User ID who created/controls the room |

**Default values**: `default: true` means new rooms are public by default

### Embedded Schema (Queue)

```elixir
    embeds_many :queue, Video, primary_key: false do
      field :youtube_id, :string
      field :title, :string
      field :thumbnail, :string
      field :duration, :integer
      field :added_by_username, :string
      field :added_by_id, :string
      field :added_at, :utc_datetime
    end
```

**`embeds_many`**:
- Stores the queue as a JSON array in a single database column
- No separate `videos` table needed
- Perfect for data that belongs to one parent record

**`primary_key: false`**:
- Embedded records don't need their own IDs

**Queue fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `youtube_id` | string | YouTube video ID (e.g., "dQw4w9WgXcQ") |
| `title` | string | Video title for display |
| `thumbnail` | string | Thumbnail URL |
| `duration` | integer | Duration in seconds |
| `added_by_username` | string | Who added this video |
| `added_by_id` | string | User ID who added it |
| `added_at` | utc_datetime | When it was added |

### Timestamps

```elixir
    timestamps()
```

Automatically adds:
- `inserted_at` - When record was created
- `updated_at` - When record was last modified

Both are `:utc_datetime` by default.

### Changeset Function

```elixir
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :is_public, :current_video_id, :host_id])
    |> validate_required([:name, :slug, :host_id])
    |> unique_constraint(:slug)
    |> cast_embed(:queue, with: &video_changeset/2)
  end
```

**Purpose**: Validates and transforms external data before database operations

**Pipeline explained**:

1. **`cast(room, attrs, allowed_fields)`**
   - Takes raw attributes (e.g., from a form)
   - Only allows specified fields through
   - Converts string keys to atoms
   - Returns a changeset

2. **`validate_required([:name, :slug, :host_id])`**
   - These fields must be present
   - Adds errors if missing

3. **`unique_constraint(:slug)`**
   - Ensures slug is unique in database
   - Corresponds to database unique index
   - Error added only if database rejects insert

4. **`cast_embed(:queue, with: &video_changeset/2)`**
   - Casts embedded queue data
   - Uses `video_changeset/2` for validation

### Video Changeset

```elixir
  defp video_changeset(video, attrs) do
    video
    |> cast(attrs, [:youtube_id, :title, :thumbnail, :duration, :added_by_username, :added_by_id, :added_at])
    |> validate_required([:youtube_id, :title])
  end
```

**`defp`**: Private function (only callable within this module)

**Purpose**: Validates video data before adding to queue

## Database Table Structure

```sql
CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    slug VARCHAR NOT NULL UNIQUE,
    is_public BOOLEAN DEFAULT true,
    current_video_id VARCHAR,
    host_id VARCHAR NOT NULL,
    queue JSONB DEFAULT '[]',
    inserted_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX rooms_slug_index ON rooms(slug);
```

## Usage Examples

### Creating a Room

```elixir
attrs = %{
  name: "My Awesome Room",
  slug: "awesome-room-1234",
  host_id: "user-uuid-here"
}

changeset = Room.changeset(%Room{}, attrs)
# => Valid changeset

Repo.insert(changeset)
# => {:ok, %Room{id: "generated-uuid", name: "My Awesome Room", ...}}
```

### Validation Errors

```elixir
# Missing required fields
changeset = Room.changeset(%Room{}, %{})
changeset.valid?
# => false

changeset.errors
# => [name: {"can't be blank", [validation: :required]},
#     slug: {"can't be blank", [validation: :required]},
#     host_id: {"can't be blank", [validation: :required]}]
```

### Working with Queue

```elixir
# Add video to queue
video = %{
  youtube_id: "dQw4w9WgXcQ",
  title: "Never Gonna Give You Up",
  thumbnail: "https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
  duration: 213,
  added_by_username: "Guest1234",
  added_by_id: "user-uuid",
  added_at: DateTime.utc_now()
}

room = Repo.get!(Room, room_id)
new_queue = room.queue ++ [video]

Room.changeset(room, %{queue: new_queue})
|> Repo.update()
```

## Pattern: Runtime vs Persistent State

The Room schema stores **persistent** data, but the actual queue during playback is managed by **RoomServer** in memory.

| Aspect | Room Schema (Database) | RoomServer (Memory) |
|--------|------------------------|---------------------|
| Storage | PostgreSQL | Erlang process |
| Persistence | Survives restarts | Lost on crash |
| Speed | Slower (disk I/O) | Faster (RAM) |
| Use case | Long-term storage | Real-time state |

**Typical flow**:
1. Room created in database with empty queue
2. RoomServer started, manages queue in memory
3. Periodically sync queue back to database (optional)

## Related Files

| File | Relationship |
|------|--------------|
| `rooms.ex` | Context module using this schema |
| `room_server.ex` | Manages runtime queue state |
| `migrations/` | Creates the database table |
| `show.ex` | LiveView that displays rooms |
