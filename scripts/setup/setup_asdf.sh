#!/bin/bash

echo "================================================"
echo "🚀 Setting Up asdf for Multiple Elixir Projects"
echo "================================================"
echo ""
echo "This will let you use different Elixir versions"
echo "for different projects without conflicts"
echo ""

# Install asdf
if ! command -v asdf &> /dev/null; then
    echo "📦 Installing asdf version manager..."
    brew install asdf
    
    # Add to shell
    echo "" >> ~/.zshrc
    echo "# asdf version manager" >> ~/.zshrc
    echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc
    
    # Also add to bash if used
    echo "" >> ~/.bash_profile
    echo "# asdf version manager" >> ~/.bash_profile
    echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.bash_profile
    
    # Load for current session
    . $(brew --prefix asdf)/libexec/asdf.sh
else
    echo "✅ asdf already installed"
fi

# Add plugins
echo ""
echo "📦 Adding language plugins..."
asdf plugin add erlang 2>/dev/null || echo "✓ Erlang plugin already added"
asdf plugin add elixir 2>/dev/null || echo "✓ Elixir plugin already added"
asdf plugin add nodejs 2>/dev/null || echo "✓ Node.js plugin already added"

# Install versions for this project
echo ""
echo "📦 Installing versions for this project..."
echo "  Erlang 26.2.5"
echo "  Elixir 1.17.3-otp-26"
echo "  Node.js 20.11.0"
echo ""
echo "This may take a few minutes..."

asdf install erlang 26.2.5
asdf install elixir 1.17.3-otp-26
asdf install nodejs 20.11.0

# Set local versions for this project
echo ""
echo "📝 Setting versions for this project..."
asdf local erlang 26.2.5
asdf local elixir 1.17.3-otp-26
asdf local nodejs 20.11.0

# Verify
echo ""
echo "✅ Verification:"
echo "Elixir: $(elixir --version | grep Elixir | cut -d' ' -f2)"
echo "Erlang: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell | tr -d '\"')"
echo "Node: $(node --version)"

# Now setup the Phoenix project
echo ""
echo "================================================"
echo "📦 Setting up Phoenix project with Elixir 1.17"
echo "================================================"
echo ""

# Clean everything
rm -rf _build deps mix.lock

# Install hex and rebar
mix local.hex --force
mix local.rebar --force

# Get and compile deps
mix deps.get
mix compile

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Phoenix compiled successfully!"
    echo ""
    
    # Database setup
    if pg_isready &>/dev/null; then
        mix ecto.create 2>/dev/null || echo "Database exists"
        mix ecto.migrate
        mix run priv/repo/seeds.exs 2>/dev/null || echo "Seeds already run"
    else
        echo "⚠️  PostgreSQL not running. Start it with:"
        echo "  brew services start postgresql"
    fi
    
    echo ""
    echo "================================================"
    echo "🎉 SUCCESS! Project ready with asdf!"
    echo "================================================"
    echo ""
    echo "📝 How asdf works:"
    echo "  - Each project has a .tool-versions file"
    echo "  - When you 'cd' into a project, asdf switches versions"
    echo "  - No more version conflicts!"
    echo ""
    echo "🚀 Start your server:"
    echo "  mix phx.server"
    echo ""
    echo "📺 Visit: http://localhost:4000"
else
    echo "❌ Compilation failed"
fi
