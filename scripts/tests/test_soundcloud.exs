#!/usr/bin/env elixir

# Test SoundCloud URL parsing and embed generation

defmodule SoundCloudTest do
  def test_url_parsing do
    urls = [
      "https://soundcloud.com/rickastley/never-gonna-give-you-up-4",
      "https://soundcloud.com/user-123456/awesome-track",
      "https://soundcloud.com/artist/track-name?in=playlist",
      "https://api.soundcloud.com/tracks/123456789"
    ]
    
    Enum.each(urls, fn url ->
      IO.puts("\n📎 Testing URL: #{url}")
      IO.puts("=" |> String.duplicate(60))
      
      result = parse_media_url(url)
      
      if result do
        IO.puts("✅ Parsed successfully!")
        IO.puts("   Type: #{result["type"]}")
        IO.puts("   Title: #{result["title"]}")
        IO.puts("   Embed URL: #{result["embed_url"]}")
      else
        IO.puts("❌ Failed to parse")
      end
    end)
  end
  
  def parse_media_url(url) do
    if String.contains?(url, "soundcloud.com") do
      extract_soundcloud_data(url)
    else
      nil
    end
  end
  
  def extract_soundcloud_data(url) do
    # Clean up the URL
    clean_url = url
    |> String.split("?")
    |> List.first()
    |> String.trim()
    
    # Extract track name from URL for display
    track_name = clean_url
    |> String.split("/")
    |> List.last()
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    
    %{
      "type" => "soundcloud",
      "media_id" => Base.encode64(clean_url),
      "title" => track_name,
      "thumbnail" => "soundcloud_gradient",
      "duration" => 180,
      "embed_url" => generate_soundcloud_embed_url(clean_url),
      "original_url" => clean_url
    }
  end
  
  def generate_soundcloud_embed_url(track_url) do
    # SoundCloud embed URL format
    encoded_url = URI.encode_www_form_component(track_url)
    "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true"
  end
end

# Run the test
SoundCloudTest.test_url_parsing()
