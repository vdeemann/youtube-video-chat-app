#!/bin/bash

echo "🚀 ULTIMATE FIX - Phoenix + Elixir 1.18.2"
echo "=========================================="
echo ""

# Step 1: Complete nuclear cleanup
echo "💣 Nuclear cleanup in progress..."
cd /Users/dee/youtube-video-chat-app

# Remove EVERYTHING
rm -rf _build
rm -rf deps
rm -rf mix.lock
rm -rf .elixir_ls
rm -rf assets/node_modules
rm -rf ~/.hex/packages
rm -rf ~/.mix/archives

echo "✅ Everything cleaned"
echo ""

# Step 2: Reinstall tools
echo "🔧 Reinstalling Hex and Rebar..."
yes | mix local.hex
yes | mix local.rebar

echo "✅ Tools reinstalled"
echo ""

# Step 3: Get deps with specific Phoenix version
echo "📦 Installing Phoenix 1.7.18 and dependencies..."
mix deps.get

echo "✅ Dependencies downloaded"
echo ""

# Step 4: Try to compile
echo "🔨 Attempting compilation..."
mix compile

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "🎉 SUCCESS! Everything compiled!"
    echo "=========================================="
    echo ""
    echo "Setting up database..."
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs
    echo ""
    echo "✅ Ready to start!"
    echo ""
    echo "Run: mix phx.server"
    echo "Visit: http://localhost:4000"
else
    echo ""
    echo "=========================================="
    echo "❌ Compilation failed - Elixir 1.18.2 issue"
    echo "=========================================="
    echo ""
    echo "SOLUTION: Use the Docker version instead:"
    echo ""
    echo "1. Make sure Docker is installed"
    echo "2. Run: docker-compose up"
    echo "3. Visit: http://localhost:4000"
    echo ""
    echo "OR downgrade Elixir to 1.17.x:"
    echo ""
    echo "brew install elixir@1.17"
    echo "brew link --overwrite elixir@1.17"
    echo ""
fi
