#!/bin/bash

echo "🔧 Quick Fix - Trying Phoenix 1.7.18 (latest)"
echo "============================================="

# Clean only Phoenix
echo "Cleaning Phoenix dependency..."
rm -rf deps/phoenix
rm -rf _build/dev/lib/phoenix

# Update mix.exs to use latest Phoenix
echo "Updating to Phoenix 1.7.18..."
sed -i '' 's/{:phoenix, "~> [0-9.]*"}/{:phoenix, "~> 1.7.18"}/' mix.exs

# Get Phoenix
echo "Fetching Phoenix 1.7.18..."
mix deps.get phoenix

# Compile Phoenix
echo "Compiling Phoenix..."
mix deps.compile phoenix --force

if [ $? -eq 0 ]; then
    echo "✅ Phoenix compiled successfully!"
    echo ""
    echo "Now compile the rest:"
    echo "  mix compile"
    echo "  mix phx.server"
else
    echo "❌ Still failing. You need to use Elixir 1.17.x"
    echo ""
    echo "Quick fix with Docker:"
    echo "  docker run -it --rm -p 4000:4000 -v \$(pwd):/app -w /app elixir:1.17.3 sh -c 'mix local.hex --force && mix deps.get && mix phx.server'"
fi
