#!/bin/bash

# YouTube Video Chat App - Quick Start Script

echo "🎬 YouTube Video Chat App - Starting..."
echo "========================================="

# Check Elixir version
ELIXIR_VERSION=$(elixir --version | grep "Elixir" | cut -d' ' -f2)
echo "📌 Elixir version: $ELIXIR_VERSION"

# Check if we need to clean deps due to Phoenix compilation issue
if [ -d "deps/phoenix" ] && ! mix compile --no-deps-check 2>/dev/null; then
    echo "⚠️  Detected compilation issue. Cleaning dependencies..."
    rm -rf _build
    rm -rf deps
    rm mix.lock
fi

# Check if dependencies are installed
if [ ! -d "deps" ]; then
    echo "📦 Installing Elixir dependencies..."
    mix deps.get
    mix deps.compile
fi

if [ ! -d "assets/node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    cd assets && npm install && cd ..
fi

# Setup database
echo "🗄️  Setting up database..."
mix ecto.create 2>/dev/null || echo "Database already exists"
mix ecto.migrate

# Run seeds if database is empty
echo "🌱 Running seeds..."
mix run priv/repo/seeds.exs 2>/dev/null || echo "Seeds already run or demo room exists"

# Start the server
echo "🚀 Starting Phoenix server..."
echo "========================================="
echo "✨ Visit http://localhost:4000 to start watching!"
echo "✨ Demo room available at: http://localhost:4000/room/demo-room"
echo "========================================="
mix phx.server
