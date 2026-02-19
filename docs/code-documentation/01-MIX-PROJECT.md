# 01 — mix.exs (Project Configuration)

**File:** `mix.exs`
**Purpose:** Defines the Elixir project: its name, version, dependencies, compilation paths, and task aliases.

---

## Key Sections

### `project/0`
- `app: :youtube_video_chat_app` — OTP application name
- `elixir: "~> 1.14"` — Requires Elixir 1.14+
- `elixirc_paths` — `["lib"]` in dev/prod, `["lib", "test/support"]` in test
- `start_permanent: true` in prod — crashes kill the VM

### `application/0`
- `mod: {YoutubeVideoChatApp.Application, []}` — Entry point for the supervision tree
- `extra_applications: [:logger, :runtime_tools]` — Logging and debugging tools

### Dependencies

| Dependency | Purpose |
|---|---|
| `phoenix` + `phoenix_live_view` | Web framework with real-time server-rendered UI |
| `ecto_sql` + `postgrex` | Database ORM + PostgreSQL driver |
| `phoenix_live_reload` | Auto-reload in dev |
| `esbuild` + `tailwind` | JS bundling + CSS compilation |
| `plug_cowboy` | HTTP server |
| `jason` | JSON encoding/decoding |
| `comeonin` + `pbkdf2_elixir` | Password hashing (cross-platform) |
| `bcrypt_elixir` | Stronger password hashing (Linux/macOS only) |
| `swoosh` | Email framework |
| `dns_cluster` | Distributed node discovery |

**Conditional bcrypt:** On Windows, `bcrypt_elixir` is excluded (requires C compiler). `pbkdf2_elixir` serves as the fallback.

### Aliases

| Command | Runs |
|---|---|
| `mix setup` | `deps.get` → `ecto.setup` → `assets.setup` → `assets.build` |
| `mix ecto.setup` | `ecto.create` → `ecto.migrate` → `run seeds.exs` |
| `mix ecto.reset` | `ecto.drop` → `ecto.setup` |
| `mix test` | `ecto.create --quiet` → `ecto.migrate --quiet` → `test` |
| `mix assets.build` | Tailwind + esbuild compilation |
| `mix assets.deploy` | Minified build + `phx.digest` for cache busting |
