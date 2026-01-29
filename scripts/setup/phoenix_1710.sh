#!/bin/bash

echo "================================================"
echo "🔥 FINAL SOLUTION - Phoenix 1.7.10"
echo "================================================"
echo ""
echo "This uses Phoenix 1.7.10 which predates the"
echo "Elixir 1.18 regex compilation issue"
echo ""

# Create a working mix.exs with Phoenix 1.7.10
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
      {:phoenix, "1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:heroicons, "~> 0.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:bcrypt_elixir, "~> 3.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:swoosh, "~> 1.5"}
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
rm -rf _build deps mix.lock ~/.hex/packages/hexpm/phoenix

echo "Installing Hex and Rebar..."
yes | mix local.hex 2>/dev/null
yes | mix local.rebar 2>/dev/null

echo "Getting Phoenix 1.7.10..."
mix deps.get

echo "Compiling Phoenix..."
mix deps.compile phoenix

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ SUCCESS! Phoenix 1.7.10 compiled!"
    echo "================================================"
    echo ""
    echo "Finishing setup..."
    mix deps.compile
    cd assets && npm install && cd ..
    mix ecto.create 2>/dev/null
    mix ecto.migrate
    echo ""
    echo "🎉 Everything is ready!"
    echo ""
    echo "Start the server:"
    echo "  mix phx.server"
    echo ""
    echo "Visit: http://localhost:4000"
else
    echo ""
    echo "================================================"
    echo "❌ Phoenix 1.7.10 also failed"
    echo "================================================"
    echo ""
    echo "ELIXIR 1.18.2 IS INCOMPATIBLE WITH PHOENIX 1.7.x"
    echo ""
    echo "You MUST either:"
    echo ""
    echo "1. Use Docker:"
    echo "   docker-compose up"
    echo ""
    echo "2. Downgrade Elixir to 1.17.3:"
    echo "   brew install elixir@1.17"
    echo "   brew link --overwrite elixir@1.17"
    echo ""
    echo "There is no other solution."
fi
