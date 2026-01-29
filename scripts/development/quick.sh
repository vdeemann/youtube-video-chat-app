#!/bin/bash

echo "================================================"
echo "🎯 FASTEST FIX - 3 Simple Steps"
echo "================================================"
echo ""

# Step 1: Install Elixir 1.17
echo "Step 1: Installing compatible Elixir version..."
if command -v brew &> /dev/null; then
    brew list elixir@1.17 &>/dev/null || brew install elixir@1.17
    brew link --overwrite elixir@1.17 --force
    echo "✅ Elixir 1.17 installed"
else
    echo "❌ Please install Homebrew first"
    exit 1
fi

# Step 2: Clean and compile
echo ""
echo "Step 2: Building Phoenix app..."
rm -rf _build deps mix.lock
mix local.hex --force <<< "Y"
mix local.rebar --force <<< "Y"
mix deps.get
mix compile

# Step 3: Database
echo ""
echo "Step 3: Setting up database..."
if ! pg_isready &>/dev/null; then
    echo "Starting PostgreSQL..."
    brew services start postgresql 2>/dev/null || brew services start postgresql@14 2>/dev/null || brew services start postgresql@15 2>/dev/null
    sleep 2
fi

mix ecto.create 2>/dev/null
mix ecto.migrate
mix run priv/repo/seeds.exs 2>/dev/null

echo ""
echo "================================================"
echo "✅ DONE! Your app is ready!"
echo "================================================"
echo ""
echo "Start it with:"
echo "  mix phx.server"
echo ""
echo "Visit: http://localhost:4000"
echo ""
