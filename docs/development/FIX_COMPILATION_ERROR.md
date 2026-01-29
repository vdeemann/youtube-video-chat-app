# YouTube Video Chat App - Fix Instructions

## Quick Fix for Phoenix Compilation Error

The compilation error you're experiencing is due to a compatibility issue between Phoenix 1.7.11 and Elixir 1.18.2.

### Solution 1: Automatic Fix (Recommended)

Run the fix script:

```bash
chmod +x fix_deps.sh
./fix_deps.sh
```

This will clean everything and reinstall with the correct versions.

### Solution 2: Manual Fix

If you prefer to fix it manually:

```bash
# 1. Clean everything
rm -rf _build deps mix.lock

# 2. Get fresh dependencies (with updated versions)
mix deps.get

# 3. Compile
mix compile

# 4. Setup database
mix ecto.setup

# 5. Start the server
mix phx.server
```

### What Changed?

- Updated Phoenix from 1.7.11 to 1.7.14 (compatible with Elixir 1.18)
- Updated Phoenix LiveView from 0.20.2 to 0.20.17
- These versions are fully compatible with Elixir 1.18.2

### After Fixing

Once the dependencies are fixed, you can start the app normally:

```bash
mix phx.server
```

Or use the start script:

```bash
./start.sh
```

Then visit http://localhost:4000 to enjoy your YouTube Watch Party app!

## Troubleshooting

If you still encounter issues:

1. Make sure you have PostgreSQL running
2. Check your Elixir version: `elixir --version`
3. If using asdf or similar, ensure you're using Elixir 1.14+ and Erlang/OTP 25+

## Alternative: Use Older Elixir

If you prefer not to update Phoenix, you can downgrade Elixir to 1.17.x:

```bash
# Using asdf
asdf install elixir 1.17.3-otp-26
asdf local elixir 1.17.3-otp-26
```

Then run `mix deps.get && mix phx.server`
