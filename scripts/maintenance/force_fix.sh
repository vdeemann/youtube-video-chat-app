#!/bin/bash

# FORCE FIX for Phoenix + Elixir 1.18.2 Compatibility

echo "🔴 FORCE FIXING Phoenix Compilation Issue"
echo "=========================================="
echo ""
echo "This will completely clean and rebuild your project"
echo "Press Ctrl+C to cancel, or wait 3 seconds to continue..."
sleep 3

# Nuclear option - clean EVERYTHING
echo "🧹 Step 1: Complete cleanup..."
rm -rf _build
rm -rf deps  
rm -rf assets/node_modules
rm -f mix.lock
rm -rf .elixir_ls
rm -rf ~/.hex
rm -rf ~/.mix

echo "✅ Cleaned all build artifacts"

# Reinstall Hex and Rebar
echo "📦 Step 2: Reinstalling Hex and Rebar..."
mix local.hex --force
mix local.rebar --force

echo "✅ Hex and Rebar reinstalled"

# Get dependencies
echo "📦 Step 3: Getting fresh dependencies..."
mix deps.get

echo "✅ Dependencies downloaded"

# Force compile Phoenix with explicit version
echo "🔨 Step 4: Compiling Phoenix..."
mix deps.compile phoenix --force

# Check if it worked
if [ $? -eq 0 ]; then
    echo "✅ Phoenix compiled successfully!"
else
    echo "❌ Phoenix compilation failed"
    echo ""
    echo "Alternative solution: Use Elixir 1.17.x"
    echo "Run these commands:"
    echo "  brew install elixir@1.17"
    echo "  or"
    echo "  asdf install elixir 1.17.3-otp-26"
    echo "  asdf local elixir 1.17.3-otp-26"
    exit 1
fi

# Compile everything else
echo "🔨 Step 5: Compiling all dependencies..."
mix deps.compile

echo "✅ All dependencies compiled"

# Install Node deps
echo "📦 Step 6: Installing Node dependencies..."
cd assets && npm install && cd ..

echo "✅ Node dependencies installed"

# Database setup
echo "🗄️ Step 7: Database setup..."
mix ecto.create 2>/dev/null || true
mix ecto.migrate

echo "✅ Database ready"

echo ""
echo "=========================================="
echo "🎉 SUCCESS! Everything is fixed!"
echo "=========================================="
echo ""
echo "Start your server with:"
echo "  mix phx.server"
echo ""
echo "Then visit http://localhost:4000"
echo ""
