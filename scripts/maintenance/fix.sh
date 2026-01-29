#!/bin/bash

echo "================================================"
echo "🚀 ONE-CLICK FIX FOR YOUR PHOENIX APP"
echo "================================================"
echo ""

# Function to check Elixir version
check_elixir_version() {
    if command -v elixir &> /dev/null; then
        version=$(elixir --version | grep "Elixir" | cut -d' ' -f2)
        echo "Current Elixir version: $version"
        if [[ $version == 1.17* ]]; then
            return 0  # Good version
        else
            return 1  # Bad version
        fi
    else
        echo "Elixir not found"
        return 1
    fi
}

# Check current Elixir version
if check_elixir_version; then
    echo "✅ You have Elixir 1.17.x - Perfect!"
    echo ""
    echo "Setting up Phoenix app..."
else
    echo "❌ You have Elixir 1.18.x - Incompatible with Phoenix 1.7"
    echo ""
    echo "Installing Elixir 1.17..."
    
    if command -v brew &> /dev/null; then
        echo "Using Homebrew..."
        brew uninstall --ignore-dependencies elixir 2>/dev/null || true
        brew install elixir@1.17
        brew link --overwrite elixir@1.17 --force
    else
        echo "Homebrew not found. Please install it first:"
        echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
fi

echo ""
echo "Cleaning build artifacts..."
rm -rf _build deps mix.lock

echo "Installing Hex and Rebar..."
yes | mix local.hex
yes | mix local.rebar

echo "Getting dependencies..."
mix deps.get

echo "Compiling..."
mix compile

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ SUCCESS! Phoenix compiled!"
    echo "================================================"
    echo ""
    
    # Check if PostgreSQL is running
    if pg_isready &> /dev/null; then
        echo "Setting up database..."
        mix ecto.create 2>/dev/null || echo "Database already exists"
        mix ecto.migrate
        mix run priv/repo/seeds.exs 2>/dev/null || echo "Seeds already run"
    else
        echo "⚠️  PostgreSQL is not running"
        echo ""
        echo "Start PostgreSQL with:"
        echo "  brew services start postgresql@14"
        echo "  or"
        echo "  postgres -D /usr/local/var/postgres"
    fi
    
    echo ""
    echo "🎉 Your YouTube Watch Party app is ready!"
    echo ""
    echo "Start the server:"
    echo "  mix phx.server"
    echo ""
    echo "Then visit:"
    echo "  http://localhost:4000"
    echo ""
else
    echo ""
    echo "❌ Compilation failed"
    echo ""
    echo "Try running these commands manually:"
    echo "  mix deps.clean --all"
    echo "  mix deps.get"
    echo "  mix compile"
fi
