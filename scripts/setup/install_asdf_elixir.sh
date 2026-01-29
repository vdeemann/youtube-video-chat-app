#!/bin/bash

echo "🔧 Installing Elixir 1.17 using asdf (Version Manager)"
echo "======================================================"
echo ""

# Check if asdf is installed
if ! command -v asdf &> /dev/null; then
    echo "📦 Installing asdf..."
    brew install asdf
    echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc
    echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.bash_profile
    source $(brew --prefix asdf)/libexec/asdf.sh
fi

echo "📦 Adding Elixir and Erlang plugins..."
asdf plugin add erlang 2>/dev/null || echo "Erlang plugin already added"
asdf plugin add elixir 2>/dev/null || echo "Elixir plugin already added"

echo "📦 Installing Erlang 26.2.5 (this may take a few minutes)..."
asdf install erlang 26.2.5

echo "📦 Installing Elixir 1.17.3..."
asdf install elixir 1.17.3-otp-26

echo "📦 Setting local versions for this project..."
asdf local erlang 26.2.5
asdf local elixir 1.17.3-otp-26

echo "✅ Verifying installation..."
elixir --version

echo ""
echo "🎉 Elixir 1.17.3 installed successfully!"
echo ""
echo "Setting up Phoenix app..."
echo "========================="

# Clean and rebuild
rm -rf _build deps mix.lock

mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Everything compiled successfully!"
    echo ""
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs
    echo ""
    echo "🚀 Start the server with:"
    echo "   mix phx.server"
    echo ""
    echo "📺 Visit: http://localhost:4000"
else
    echo "❌ Compilation failed"
fi
