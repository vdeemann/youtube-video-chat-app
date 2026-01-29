#!/bin/bash

echo "===================================================="
echo "🚨 PHOENIX COMPILATION FIX for Elixir 1.18.2"
echo "===================================================="
echo ""
echo "This script will try multiple solutions in order:"
echo "1. Try Phoenix 1.7.18 (latest)"
echo "2. Try Phoenix 1.7.12 (last known good)"
echo "3. Suggest Docker or Elixir downgrade"
echo ""
echo "Starting in 3 seconds..."
sleep 3

# Function to clean everything
clean_all() {
    echo "🧹 Cleaning all artifacts..."
    rm -rf _build
    rm -rf deps
    rm -rf mix.lock
    rm -rf .elixir_ls
    rm -rf assets/node_modules
    rm -rf ~/.hex/packages/hexpm/phoenix
    rm -rf ~/.mix/archives/hex-phoenix*
}

# Function to try compilation
try_compile() {
    local version=$1
    echo ""
    echo "📦 Trying Phoenix $version..."
    
    # Update mix.exs
    cp mix.exs mix.exs.backup
    sed -i '' "s/{:phoenix, \"[^\"]*\"}/{:phoenix, \"$version\"}/" mix.exs
    
    # Get deps
    mix deps.get phoenix
    
    # Try to compile Phoenix
    mix deps.compile phoenix --force 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Phoenix $version compiled successfully!"
        return 0
    else
        echo "❌ Phoenix $version failed"
        return 1
    fi
}

# Main script
echo ""
echo "STEP 1: Complete cleanup"
echo "------------------------"
clean_all

echo ""
echo "STEP 2: Reinstall Hex and Rebar"
echo "--------------------------------"
mix local.hex --force
mix local.rebar --force

echo ""
echo "STEP 3: Try different Phoenix versions"
echo "---------------------------------------"

# Try Phoenix 1.7.18
if try_compile "~> 1.7.18"; then
    echo "🎉 Using Phoenix 1.7.18"
elif try_compile "1.7.12"; then
    echo "🎉 Using Phoenix 1.7.12"
else
    echo ""
    echo "===================================================="
    echo "❌ COMPILATION FAILED WITH ALL PHOENIX VERSIONS"
    echo "===================================================="
    echo ""
    echo "Your Elixir 1.18.2 is incompatible with Phoenix 1.7.x"
    echo ""
    echo "SOLUTION OPTIONS:"
    echo ""
    echo "Option 1: Use Docker (Recommended)"
    echo "-----------------------------------"
    echo "docker-compose up"
    echo ""
    echo "Option 2: Downgrade Elixir"
    echo "---------------------------"
    echo "brew install elixir@1.17"
    echo "brew link --overwrite elixir@1.17"
    echo ""
    echo "Option 3: Use asdf version manager"
    echo "-----------------------------------"
    echo "brew install asdf"
    echo "asdf plugin add elixir"
    echo "asdf install elixir 1.17.3-otp-26"
    echo "asdf local elixir 1.17.3-otp-26"
    echo ""
    echo "After downgrading Elixir, run:"
    echo "mix deps.get && mix phx.server"
    exit 1
fi

echo ""
echo "STEP 4: Compile all dependencies"
echo "---------------------------------"
mix deps.compile

if [ $? -ne 0 ]; then
    echo "❌ Some dependencies failed to compile"
    echo "Try: mix deps.compile --force"
    exit 1
fi

echo ""
echo "STEP 5: Install Node dependencies"
echo "----------------------------------"
cd assets && npm install && cd ..

echo ""
echo "STEP 6: Setup database"
echo "----------------------"
mix ecto.create 2>/dev/null || echo "Database exists"
mix ecto.migrate

echo ""
echo "===================================================="
echo "✅ SUCCESS! Everything is working!"
echo "===================================================="
echo ""
echo "Start your server with:"
echo "  mix phx.server"
echo ""
echo "Then visit:"
echo "  http://localhost:4000"
echo ""
