# 07-ACCOUNTS.md - Guest User Management

## File: `lib/youtube_video_chat_app/accounts.ex`

This module provides a simplified user system using anonymous guest accounts.

## Complete Source Code

```elixir
defmodule YoutubeVideoChatApp.Accounts do
  @moduledoc """
  The Accounts context - simplified user management for demo
  """
  
  def create_guest_user do
    %{
      id: Ecto.UUID.generate(),
      username: "Guest#{:rand.uniform(9999)}",
      color: random_color()
    }
  end
  
  defp random_color do
    colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]
    Enum.random(colors)
  end
end
```

## Line-by-Line Explanation

### Module Definition

```elixir
defmodule YoutubeVideoChatApp.Accounts do
  @moduledoc """
  The Accounts context - simplified user management for demo
  """
```

- **Context Pattern**: Follows Phoenix convention of grouping related functionality
- **"for demo"**: Indicates this is a simplified implementation
- No database persistence - users are created fresh each session

### Create Guest User

```elixir
  def create_guest_user do
    %{
      id: Ecto.UUID.generate(),
      username: "Guest#{:rand.uniform(9999)}",
      color: random_color()
    }
  end
```

**Returns**: A plain map (not a struct) representing a guest user

**Fields**:

| Field | Value | Purpose |
|-------|-------|---------|
| `id` | `"550e8400-e29b-41d4-..."` | Unique identifier for presence/hosting |
| `username` | `"Guest4523"` | Display name in chat |
| `color` | `"#FF6B6B"` | User's chat color |

**`Ecto.UUID.generate()`**:
- Generates a random UUID v4
- Format: `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`
- Statistically unique (collision probability is negligible)

**`:rand.uniform(9999)`**:
- Random integer from 1 to 9999
- Makes usernames like "Guest1234", "Guest8765"

### Random Color

```elixir
  defp random_color do
    colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]
    Enum.random(colors)
  end
```

**`defp`**: Private function (only callable within this module)

**Color palette**:

| Hex | Color |
|-----|-------|
| `#FF6B6B` | Coral Red |
| `#4ECDC4` | Teal |
| `#45B7D1` | Sky Blue |
| `#FFA07A` | Light Salmon |
| `#98D8C8` | Mint Green |
| `#F7DC6F` | Soft Yellow |
| `#BB8FCE` | Lavender |
| `#85C1E2` | Light Blue |

These colors are chosen to:
- Be visually distinct in chat
- Have good contrast against dark backgrounds
- Be pleasant and not too saturated

## Usage in LiveView

```elixir
defmodule YoutubeVideoChatAppWeb.RoomLive.Show do
  def mount(%{"slug" => slug}, _session, socket) do
    # Create a new guest user for this session
    user = Accounts.create_guest_user()
    
    socket = socket
    |> assign(:user, user)
    # ...
  end
end
```

## Why Guest-Based System?

### Advantages
1. **Zero friction**: Users join rooms instantly
2. **No auth complexity**: No passwords, sessions, OAuth
3. **Privacy**: No personal data collected
4. **Simplicity**: Perfect for temporary watching sessions

### Trade-offs
1. **No persistence**: Can't save favorites/history
2. **No identity**: Can't verify who someone is
3. **Spam risk**: No rate limiting by user (would need IP-based)

## Potential Enhancements

### Adding Database Persistence

```elixir
defmodule YoutubeVideoChatApp.Accounts.User do
  use Ecto.Schema
  
  schema "users" do
    field :username, :string
    field :color, :string
    field :is_guest, :boolean, default: true
    timestamps()
  end
end

def create_guest_user do
  %User{}
  |> User.changeset(%{
    username: "Guest#{:rand.uniform(9999)}",
    color: random_color(),
    is_guest: true
  })
  |> Repo.insert!()
end
```

### Adding Optional Registration

```elixir
def register_user(attrs) do
  %User{}
  |> User.registration_changeset(attrs)
  |> Repo.insert()
end

def authenticate_user(email, password) do
  user = Repo.get_by(User, email: email)
  if user && Bcrypt.verify_pass(password, user.password_hash) do
    {:ok, user}
  else
    {:error, :invalid_credentials}
  end
end
```

### Storing User Preferences in Session

```elixir
# In LiveView
def mount(_params, session, socket) do
  user = case session["user_id"] do
    nil -> 
      # New guest
      user = Accounts.create_guest_user()
      # Store in session would require redirect
      user
    id ->
      # Returning user
      Accounts.get_user!(id)
  end
end
```

## Design Decisions

### Why Maps Instead of Structs?

Using plain maps (`%{id: ..., username: ...}`) instead of structs:

**Pros**:
- Simpler (no schema module needed)
- More flexible
- Easy to serialize

**Cons**:
- No compile-time field validation
- No default values
- Harder to document structure

For a production app, you might use:

```elixir
defmodule YoutubeVideoChatApp.Accounts.User do
  defstruct [:id, :username, :color]
end
```

### Why UUID for Guest IDs?

Instead of sequential integers:
- Can't guess other user IDs
- Globally unique (safe across servers)
- Compatible with database UUIDs if later persisted

## Related Files

| File | Relationship |
|------|--------------|
| `live/room_live/show.ex` | Creates guest user on mount |
| `presence.ex` | Tracks users using their IDs |
| `room_server.ex` | Stores host_id from user |

## Security Considerations

1. **No Authentication**: Anyone can claim any username
2. **No Session Binding**: User ID is per-LiveView mount
3. **Host Privileges**: First user in room becomes host

For a production app, consider:
- Rate limiting by IP
- Username profanity filtering
- Optional account registration
- Session-based identity persistence
