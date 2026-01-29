#!/bin/bash

echo "🧪 Testing SoundCloud URLs with Various Formats"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${CYAN}Testing different SoundCloud URL formats:${NC}"

docker-compose exec web elixir -e '
defmodule TestSoundCloudURLs do
  require Logger
  
  def test_urls do
    urls = [
      # URL with tracking params (the problematic one)
      "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing",
      
      # Clean URLs
      "https://soundcloud.com/odesza/say-my-name-feat-zyra",
      "https://soundcloud.com/rickastley/never-gonna-give-you-up-4",
      
      # URL with just one param
      "https://soundcloud.com/flume/flume-holdin-on?in=flume/sets/flume",
      
      # Mobile URL
      "https://m.soundcloud.com/porter-robinson/shelter",
      
      # URL with fragment
      "https://soundcloud.com/madeon/pay-no-mind#t=0:30"
    ]
    
    Enum.each(urls, fn url ->
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("Testing: #{String.slice(url, 0..80)}...")
      
      result = parse_soundcloud_url(url)
      
      case result do
        {:ok, data} ->
          IO.puts("✅ SUCCESS!")
          IO.puts("   Title: #{data["title"]}")
          IO.puts("   Clean URL: #{data["original_url"]}")
          IO.puts("   Embed URL: #{String.slice(data["embed_url"], 0..100)}...")
        {:error, reason} ->
          IO.puts("❌ FAILED: #{reason}")
      end
    end)
  end
  
  def parse_soundcloud_url(url) do
    try do
      # Parse the URL
      uri = URI.parse(url)
      
      # Handle mobile URLs
      host = case uri.host do
        "m.soundcloud.com" -> "soundcloud.com"
        host -> host
      end
      
      unless host == "soundcloud.com" do
        throw("Not a SoundCloud URL")
      end
      
      # Get clean path
      path = uri.path || ""
      clean_url = "https://soundcloud.com#{path}"
      
      # Extract artist and track
      path_parts = path |> String.trim("/") |> String.split("/")
      
      {artist, track} = case path_parts do
        [a, t | _] when a != "" and t != "" ->
          {format_name(a), format_name(t)}
        _ ->
          {"Unknown Artist", "Unknown Track"}
      end
      
      title = "#{track} by #{artist}"
      media_id = :crypto.hash(:md5, clean_url) |> Base.encode16() |> String.slice(0..10)
      
      # Build embed URL
      encoded_url = URI.encode_www_form_component(clean_url)
      embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
      
      {:ok, %{
        "title" => title,
        "original_url" => clean_url,
        "embed_url" => embed_url,
        "media_id" => media_id
      }}
    catch
      reason -> {:error, reason}
    rescue
      e -> {:error, "Exception: #{inspect(e)}"}
    end
  end
  
  defp format_name(name) do
    name
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

TestSoundCloudURLs.test_urls()
'

echo -e "\n${GREEN}===============================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo "All URLs above should show ✅ SUCCESS"
echo "If any show ❌ FAILED, there's still an issue with parsing"
echo ""