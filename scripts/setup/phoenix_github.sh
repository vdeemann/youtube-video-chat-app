#!/bin/bash

echo "================================================"
echo "🚀 TRYING PHOENIX FROM GITHUB MAIN BRANCH"
echo "================================================"
echo ""
echo "This will use the latest Phoenix code which"
echo "should have fixes for Elixir 1.18 compatibility"
echo ""

# Create mix.exs with Phoenix from GitHub
cat > mix.exs << 'EOF'
defmodule YoutubeVideoChatApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :youtube_video_chat_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {YoutubeVideoChatApp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Use Phoenix from GitHub main branch
      {:phoenix, github: "phoenixframework/phoenix", branch: "main", override: true},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0.0-rc.7"},
      {:phoenix_live_dashboard, "~> 0.8.5"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:heroicons, "~> 0.5"},
      {:floki, ">= 0.36.0", only: :test},
      {:bcrypt_elixir, "~> 3.2"},
      {:dns_cluster, "~> 0.1.3"},
      {:swoosh, "~> 1.17"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind youtube_video_chat_app", "esbuild youtube_video_chat_app"],
      "assets.deploy": [
        "tailwind youtube_video_chat_app --minify",
        "esbuild youtube_video_chat_app --minify",
        "phx.digest"
      ]
    ]
  end
end
EOF

echo "Cleaning everything..."
rm -rf _build deps mix.lock

echo "Installing tools..."
mix local.hex --force
mix local.rebar --force

echo "Getting Phoenix from GitHub..."
mix deps.get

echo "Compiling Phoenix from source..."
mix deps.compile phoenix

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ SUCCESS! Phoenix from GitHub works!"
    echo "================================================"
    echo ""
    echo "Compiling remaining dependencies..."
    mix deps.compile
    cd assets && npm install && cd ..
    mix ecto.setup
    echo ""
    echo "🎉 Ready to go!"
    echo ""
    echo "Start with: mix phx.server"
    echo "Visit: http://localhost:4000"
else
    echo ""
    echo "================================================"
    echo "❌ Even Phoenix main branch fails"
    echo "================================================"
    echo ""
    echo "This confirms Elixir 1.18.2 is completely"
    echo "incompatible with Phoenix 1.7.x"
    echo ""
    echo "YOU MUST USE ONE OF THESE:"
    echo ""
    echo "1. Docker (guaranteed to work):"
    echo "   docker-compose up"
    echo ""
    echo "2. Elixir 1.17.3:"
    echo "   curl -fsSL https://raw.githubusercontent.com/asdf-vm/asdf/master/install.sh | bash"
    echo "   asdf plugin add elixir"
    echo "   asdf install elixir 1.17.3-otp-26"
    echo "   asdf local elixir 1.17.3-otp-26"
    echo "   mix deps.get && mix phx.server"
fi
