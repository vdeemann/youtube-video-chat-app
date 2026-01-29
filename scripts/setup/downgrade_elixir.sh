#!/bin/bash

echo "🔧 Downgrading Elixir to 1.17 (Compatible with Phoenix)"
echo "========================================================"
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "📦 Step 1: Uninstalling current Elixir..."
brew uninstall --ignore-dependencies elixir 2>/dev/null || echo "Elixir not installed via brew"

echo "📦 Step 2: Installing Elixir 1.17..."
brew tap homebrew/core
brew install elixir@1.17

echo "📦 Step 3: Linking Elixir 1.17..."
brew unlink elixir 2>/dev/null || true
brew link --overwrite elixir@1.17

echo "✅ Step 4: Verifying installation..."
elixir --version

echo ""
echo "🎉 Elixir downgraded successfully!"
echo ""
echo "Now setting up your Phoenix app..."
echo "===================================="

# Clean previous build artifacts
rm -rf _build deps mix.lock

# Install hex and rebar
mix local.hex --force
mix local.rebar --force

# Get dependencies
echo "📦 Installing dependencies..."
mix deps.get

# Compile
echo "🔨 Compiling..."
mix compile

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Everything compiled!"
    echo ""
    echo "Setting up database..."
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs
    echo ""
    echo "🎉 Ready to start!"
    echo ""
    echo "Run: mix phx.server"
    echo "Visit: http://localhost:4000"
else
    echo "❌ Compilation failed. Try running manually:"
    echo "  mix deps.get"
    echo "  mix compile"
fi
