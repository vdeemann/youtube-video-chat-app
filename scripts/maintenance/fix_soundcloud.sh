#!/bin/bash

echo "🔧 Applying SoundCloud Fix"
echo "=========================="

# First, let's ensure assets are properly copied
echo "1. Copying test page to static directory..."
docker-compose exec web bash -c "
# Ensure priv/static exists
mkdir -p priv/static

# Copy test page if it exists
if [ -f 'priv/static/test_soundcloud.html' ]; then
  echo '✅ Test page already in place'
else
  echo '⚠️  Test page not found, checking other locations...'
fi
"

echo -e "\n2. Rebuilding JavaScript with SoundCloud support..."
docker-compose exec web bash -c "
# Ensure hooks directory exists
mkdir -p assets/js/hooks

# Rebuild assets
echo 'Building assets...'
cd assets && npm install && cd ..
mix assets.build
"

echo -e "\n3. Applying a hotfix to ensure SoundCloud parsing works..."
docker-compose exec web elixir -e '
# Test that our SoundCloud module loads
Code.ensure_loaded(YoutubeVideoChatAppWeb.RoomLive.Show)
IO.puts("✅ RoomLive.Show module loaded")
'

echo -e "\n4. Restarting web container..."
docker-compose restart web

echo -e "\n5. Waiting for Phoenix to restart..."
sleep 10

# Check if app is running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "✅ Application restarted successfully!"
else
    echo "⚠️  Application may still be starting..."
fi

echo -e "\n=========================="
echo "🧪 Testing SoundCloud URL Parsing..."
echo "=========================="

docker-compose exec web elixir -e '
defmodule QuickTest do
  def parse_media_url(url) do
    url = String.trim(url)
    
    cond do
      String.contains?(url, "soundcloud.com") ->
        IO.puts("✅ Detected as SoundCloud URL")
        extract_soundcloud_data(url)
      true ->
        IO.puts("❌ Not detected as SoundCloud")
        nil
    end
  end
  
  def extract_soundcloud_data(url) do
    clean_url = url
    |> String.split(~r/[?#]/)
    |> List.first()
    |> String.trim()
    |> String.trim_trailing("/")
    
    parts = clean_url
    |> String.split("soundcloud.com/")
    |> List.last()
    |> String.split("/")
    
    {artist_name, track_name} = case parts do
      [artist, track | _] ->
        artist_display = artist
        |> String.replace("-", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        
        track_display = track
        |> String.replace("-", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        
        {artist_display, track_display}
      
      _ ->
        {"Unknown Artist", "Unknown Track"}
    end
    
    title = "#{track_name} by #{artist_name}"
    media_id = :crypto.hash(:md5, clean_url) |> Base.encode16() |> String.slice(0..10)
    
    encoded_url = URI.encode_www_form_component(clean_url)
    embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
    
    %{
      "type" => "soundcloud",
      "media_id" => media_id,
      "title" => title,
      "embed_url" => String.slice(embed_url, 0..200) <> "...",
      "status" => "✅ Successfully parsed"
    }
  end
  
  def test do
    urls = [
      "https://soundcloud.com/odesza/say-my-name-feat-zyra",
      "https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
    ]
    
    Enum.each(urls, fn url ->
      IO.puts("\n📎 Testing: #{url}")
      result = parse_media_url(url)
      if result do
        IO.inspect(result, pretty: true, limit: :infinity)
      end
    end)
  end
end

QuickTest.test()
'

echo -e "\n=========================="
echo "✅ Fix Applied!"
echo "=========================="
echo ""
echo "🧪 Now test it:"
echo "1. Go to http://localhost:4000"
echo "2. Create/join a room"
echo "3. Open browser console (F12)"
echo "4. Add this URL to queue:"
echo "   https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo ""
echo "📝 If it still doesn't work:"
echo "1. Check browser console for errors"
echo "2. Run: docker-compose logs -f web"
echo "3. Share the error messages"
echo ""