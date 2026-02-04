defmodule YoutubeVideoChatApp.Bandcamp do
  @moduledoc """
  Fetches and parses Bandcamp track/album information.
  
  Since Bandcamp doesn't have a public API, we scrape the page HTML
  to extract track IDs, titles, durations, and artwork.
  """
  
  require Logger

  @doc """
  Fetches track information from a Bandcamp URL.
  
  Returns {:ok, track_info} or {:error, reason}
  
  track_info contains:
  - id: The track/album ID for embedding
  - type: "track" or "album"
  - title: Track/album title
  - artist: Artist name
  - duration: Duration in seconds (for tracks)
  - artwork: Album artwork URL
  - embed_url: The full embed URL
  """
  def fetch_track_info(url) do
    Logger.info("[Bandcamp] Fetching info for: #{url}")
    
    with {:ok, url} <- validate_url(url),
         {:ok, html} <- fetch_page(url),
         {:ok, info} <- parse_page(html, url) do
      {:ok, info}
    else
      {:error, reason} = error ->
        Logger.error("[Bandcamp] Failed to fetch track info: #{inspect(reason)}")
        error
    end
  end

  defp validate_url(url) do
    url = String.trim(url)
    
    if String.contains?(String.downcase(url), "bandcamp.com") do
      # Ensure it has a protocol
      url = if String.starts_with?(url, "http"), do: url, else: "https://#{url}"
      {:ok, url}
    else
      {:error, :not_bandcamp_url}
    end
  end

  defp fetch_page(url) do
    case Req.get(url, 
      headers: [
        {"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}
      ],
      redirect: true,
      max_redirects: 5,
      receive_timeout: 10_000
    ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}
      
      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_page(html, original_url) do
    # Parse the HTML
    case Floki.parse_document(html) do
      {:ok, document} ->
        # Try to extract data from multiple sources
        with {:ok, basic_info} <- extract_basic_info(document, original_url),
             {:ok, track_data} <- extract_track_data(html, document) do
          
          info = Map.merge(basic_info, track_data)
          
          # Build embed URL
          embed_url = build_embed_url(info)
          
          result = Map.put(info, :embed_url, embed_url)
          Logger.info("[Bandcamp] Successfully parsed: #{result.title} by #{result.artist} (#{result.duration}s)")
          
          {:ok, result}
        end
      
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp extract_basic_info(document, original_url) do
    # Get title from og:title or page title
    title = 
      get_meta_content(document, "og:title") ||
      get_meta_content(document, "twitter:title") ||
      get_page_title(document) ||
      "Bandcamp Track"
    
    # Get artist - try multiple sources
    artist = 
      get_meta_content(document, "og:site_name") ||
      extract_artist_from_url(original_url) ||
      "Unknown Artist"
    
    # Get artwork
    artwork = 
      get_meta_content(document, "og:image") ||
      get_meta_content(document, "twitter:image") ||
      default_bandcamp_artwork()
    
    # Determine if it's a track or album from URL
    type = if String.contains?(original_url, "/track/"), do: "track", else: "album"
    
    {:ok, %{
      title: clean_title(title, artist),
      artist: artist,
      artwork: artwork,
      type: type,
      original_url: original_url
    }}
  end

  defp extract_track_data(html, document) do
    # Try to get track ID from bc-page-properties meta tag
    track_id = extract_item_id(document) || extract_item_id_from_script(html)
    
    # Try to get duration from the page
    duration = extract_duration(html, document)
    
    if track_id do
      {:ok, %{
        id: track_id,
        duration: duration || 180  # Default to 3 minutes if we can't find duration
      }}
    else
      {:error, :no_track_id_found}
    end
  end

  defp extract_item_id(document) do
    # Try bc-page-properties meta tag first
    case Floki.find(document, "meta[name='bc-page-properties']") do
      [{_, attrs, _} | _] ->
        content = get_attr(attrs, "content")
        if content do
          case Jason.decode(content) do
            {:ok, %{"item_id" => id}} -> to_string(id)
            {:ok, %{"item_id" => nil}} -> nil
            _ -> nil
          end
        end
      _ -> nil
    end
  end

  defp extract_item_id_from_script(html) do
    # Look for TralbumData in script tags
    # Pattern: var TralbumData = { ... "id":12345678, ... }
    case Regex.run(~r/TralbumData\s*=\s*\{[^}]*"id"\s*:\s*(\d+)/, html) do
      [_, id] -> id
      _ ->
        # Try another pattern: data-tralbum-id
        case Regex.run(~r/data-tralbum-id="(\d+)"/, html) do
          [_, id] -> id
          _ ->
            # Try: trackinfo pattern
            case Regex.run(~r/"track_id"\s*:\s*(\d+)/, html) do
              [_, id] -> id
              _ -> nil
            end
        end
    end
  end

  defp extract_duration(html, document) do
    # Method 1: Look for duration in JSON-LD
    duration = extract_duration_from_jsonld(document)
    if duration, do: duration, else: extract_duration_from_script(html)
  end

  defp extract_duration_from_jsonld(document) do
    case Floki.find(document, "script[type='application/ld+json']") do
      [] -> nil
      scripts ->
        Enum.find_value(scripts, fn {_, _, [content]} ->
          case Jason.decode(content) do
            {:ok, %{"duration" => duration}} when is_binary(duration) ->
              parse_iso_duration(duration)
            
            {:ok, %{"@type" => "MusicRecording", "duration" => duration}} ->
              parse_iso_duration(duration)
            
            {:ok, data} when is_map(data) ->
              # Sometimes duration is nested
              case get_in(data, ["duration"]) do
                nil -> nil
                dur -> parse_iso_duration(dur)
              end
            
            _ -> nil
          end
        end)
    end
  end

  defp extract_duration_from_script(html) do
    # Look for duration in TralbumData or trackinfo
    # Pattern: "duration":123.45
    case Regex.run(~r/"duration"\s*:\s*([\d.]+)/, html) do
      [_, duration_str] ->
        case Float.parse(duration_str) do
          {duration, _} -> round(duration)
          :error -> nil
        end
      _ ->
        # Try looking for track time in format like "3:45"
        case Regex.run(~r/class="time[^"]*"[^>]*>(\d+):(\d+)/, html) do
          [_, min, sec] ->
            String.to_integer(min) * 60 + String.to_integer(sec)
          _ -> nil
        end
    end
  end

  defp parse_iso_duration(duration) when is_binary(duration) do
    # ISO 8601 duration format: PT3M45S or P0DT0H3M45S
    cond do
      # Simple format: PT3M45S
      match = Regex.run(~r/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/, duration) ->
        [_, hours, minutes, seconds] = match ++ ["", "", ""]
        h = if hours == "", do: 0, else: String.to_integer(hours)
        m = if minutes == "", do: 0, else: String.to_integer(minutes)
        s = if seconds == "", do: 0, else: String.to_integer(seconds)
        h * 3600 + m * 60 + s
      
      # Just seconds as number
      match?(~r/^\d+$/, duration) ->
        String.to_integer(duration)
      
      true ->
        nil
    end
  end
  defp parse_iso_duration(_), do: nil

  defp build_embed_url(%{id: id, type: type}) do
    type_param = if type == "track", do: "track", else: "album"
    
    # Add autoplay parameter - Bandcamp may honor this in some browsers
    "https://bandcamp.com/EmbeddedPlayer/#{type_param}=#{id}/size=large/bgcol=333333/linkcol=e99708/tracklist=false/artwork=small/transparent=true/autoplay=true/"
  end

  defp get_meta_content(document, property) do
    selectors = [
      "meta[property='#{property}']",
      "meta[name='#{property}']"
    ]
    
    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [{_, attrs, _} | _] -> get_attr(attrs, "content")
        _ -> nil
      end
    end)
  end

  defp get_page_title(document) do
    case Floki.find(document, "title") do
      [{_, _, [title]} | _] -> String.trim(title)
      _ -> nil
    end
  end

  defp get_attr(attrs, name) do
    Enum.find_value(attrs, fn
      {^name, value} -> value
      _ -> nil
    end)
  end

  defp extract_artist_from_url(url) do
    # Extract from subdomain: artist.bandcamp.com
    case Regex.run(~r/https?:\/\/([^.]+)\.bandcamp\.com/, url) do
      [_, artist] -> 
        artist
        |> String.replace("-", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
      _ -> nil
    end
  end

  defp clean_title(title, artist) do
    # Remove " | Artist Name" suffix if present
    title
    |> String.replace(~r/\s*\|\s*#{Regex.escape(artist)}.*$/i, "")
    |> String.replace(~r/\s*by\s*#{Regex.escape(artist)}.*$/i, "")
    |> String.trim()
  end

  defp default_bandcamp_artwork do
    # A simple colored placeholder
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 300'%3E%3Crect fill='%231da0c3' width='300' height='300'/%3E%3Ctext x='150' y='160' font-family='Arial' font-size='40' fill='white' text-anchor='middle'%3EBandcamp%3C/text%3E%3C/svg%3E"
  end
end
