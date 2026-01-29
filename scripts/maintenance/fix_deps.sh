#!/bin/bash

# Fix Phoenix compilation issue with Elixir 1.18

echo "🔧 Fixing Phoenix compilation issue..."
echo "========================================"

# Clean all build artifacts
echo "🧹 Cleaning build artifacts..."
rm -rf _build
rm -rf deps
rm -rf assets/node_modules
rm mix.lock

# Get fresh dependencies
echo "📦 Fetching fresh dependencies..."
mix deps.get

# Install npm dependencies
echo "📦 Installing Node.js dependencies..."
cd assets && npm install && cd ..

# Compile dependencies
echo "🔨 Compiling dependencies..."
mix deps.compile

# Setup database
echo "🗄️ Setting up database..."
mix ecto.create
mix ecto.migrate

# Run seeds
echo "🌱 Running seeds..."
mix run priv/repo/seeds.exs

echo "✅ Fixed! Now you can start the server with:"
echo "   mix phx.server"
echo ""
echo "Or use the start.sh script:"
echo "   ./start.sh"
