# 03-REPO.md - Database Repository Configuration

## File: `lib/youtube_video_chat_app/repo.ex`

```elixir
defmodule YoutubeVideoChatApp.Repo do
  use Ecto.Repo,
    otp_app: :youtube_video_chat_app,
    adapter: Ecto.Adapters.Postgres
end
```

## Line-by-Line Explanation

### Line 1: Module Definition
```elixir
defmodule YoutubeVideoChatApp.Repo do
```
- **Purpose**: Defines the `Repo` module, which is the database interface
- **Naming Convention**: `AppName.Repo` is the standard Phoenix convention
- **Role**: Acts as a wrapper around all database operations

### Lines 2-4: Using Ecto.Repo
```elixir
  use Ecto.Repo,
    otp_app: :youtube_video_chat_app,
    adapter: Ecto.Adapters.Postgres
```

**`use Ecto.Repo`**:
- Imports all Ecto.Repo functionality into this module
- Provides database operations like `insert/1`, `update/1`, `delete/1`, `get/2`, `all/1`
- Makes this module a GenServer that maintains a database connection pool

**`:otp_app`**:
- Tells Ecto which application's configuration to use
- Ecto will look for database config in `config/dev.exs`, `config/prod.exs`, etc.
- Example config it reads:
  ```elixir
  config :youtube_video_chat_app, YoutubeVideoChatApp.Repo,
    database: "youtube_video_chat_app_dev",
    username: "postgres",
    password: "postgres",
    hostname: "localhost"
  ```

**`:adapter`**:
- Specifies which database driver to use
- `Ecto.Adapters.Postgres` connects to PostgreSQL
- Other options: `Ecto.Adapters.MySQL`, `Ecto.Adapters.SQLite3`

## What This Module Provides

### Database Operations

```elixir
# Insert a new record
Repo.insert(%Room{name: "My Room"})

# Get a record by ID
Repo.get(Room, "uuid-here")

# Get a record or raise error
Repo.get!(Room, "uuid-here")

# Get by specific field
Repo.get_by(Room, slug: "cool-vibes-1234")

# Get all records
Repo.all(Room)

# Update a record
Repo.update(changeset)

# Delete a record
Repo.delete(room)

# Run a query
Repo.all(from r in Room, where: r.is_public == true)
```

### Transaction Support

```elixir
Repo.transaction(fn ->
  Repo.insert!(%Room{name: "Room 1"})
  Repo.insert!(%Room{name: "Room 2"})
end)
```

### Connection Pooling

- The Repo maintains a pool of database connections
- Configurable pool size (default: 10)
- Handles concurrent requests efficiently

## Configuration (from config/dev.exs)

```elixir
config :youtube_video_chat_app, YoutubeVideoChatApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "youtube_video_chat_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

### Configuration Options Explained

| Option | Description |
|--------|-------------|
| `username` | PostgreSQL user |
| `password` | PostgreSQL password |
| `hostname` | Database server location |
| `database` | Database name |
| `stacktrace` | Show detailed errors (dev only) |
| `pool_size` | Number of concurrent connections |

## Supervision

The Repo is started in `application.ex`:

```elixir
children = [
  YoutubeVideoChatApp.Repo,  # Database connection pool
  # ... other children
]
```

- Repo must start before any code tries to access the database
- If Repo crashes, the supervisor will restart it

## Related Files

- **Config**: `config/dev.exs`, `config/runtime.exs`
- **Migrations**: `priv/repo/migrations/`
- **Seeds**: `priv/repo/seeds.exs`
- **Application**: `lib/youtube_video_chat_app/application.ex`

## Common Patterns

### Using Repo in Context Modules

```elixir
defmodule YoutubeVideoChatApp.Rooms do
  alias YoutubeVideoChatApp.Repo
  alias YoutubeVideoChatApp.Rooms.Room

  def get_room!(id) do
    Repo.get!(Room, id)
  end
end
```

### Query Composition

```elixir
import Ecto.Query

# Build queries step by step
Room
|> where([r], r.is_public == true)
|> order_by([r], desc: r.inserted_at)
|> limit(10)
|> Repo.all()
```

## Error Handling

```elixir
# Using get (returns nil if not found)
case Repo.get(Room, id) do
  nil -> {:error, :not_found}
  room -> {:ok, room}
end

# Using get! (raises if not found)
try do
  Repo.get!(Room, id)
rescue
  Ecto.NoResultsError -> {:error, :not_found}
end
```
