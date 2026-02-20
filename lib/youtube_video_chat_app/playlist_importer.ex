defmodule YoutubeVideoChatApp.PlaylistImporter do
  @moduledoc """
  Imports playlists from YouTube and SoundCloud using their public APIs.

  ## YouTube
  Uses the YouTube oEmbed API + page scraping to extract video IDs from a playlist URL,
  then fetches each video's metadata via oEmbed.

  ## SoundCloud
  Uses the SoundCloud oEmbed API to resolve playlist/set URLs into track lists.
  """

  require Logger

  @finch YoutubeVideoChatApp.Finch
  @yt_oembed "https://www.youtube.com/oembed"
  @yt_browse_url "https://www.youtube.com/youtubei/v1/browse"
  @max_tracks 5000

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Detects the platform and imports a playlist from a URL.
  Returns {:ok, %{name: String.t(), tracks: [map()]}} or {:error, reason}.
  """
  def import_playlist(url) do
    url = String.trim(url)

    cond do
      youtube_playlist_url?(url) ->
        import_youtube_playlist(url)

      soundcloud_playlist_url?(url) ->
        import_soundcloud_playlist(url)

      true ->
        {:error, "URL doesn't appear to be a YouTube or SoundCloud playlist"}
    end
  end

  # ============================================================================
  # URL Detection
  # ============================================================================

  defp youtube_playlist_url?(url) do
    String.contains?(url, "youtube.com") and String.contains?(url, "list=")
  end

  defp soundcloud_playlist_url?(url) do
    uri = URI.parse(url)
    host = uri.host || ""
    path = uri.path || ""
    path_parts = path |> String.trim("/") |> String.split("/") |> Enum.filter(&(&1 != ""))

    is_soundcloud = host in ["soundcloud.com", "www.soundcloud.com", "m.soundcloud.com"]

    # SoundCloud playlists/sets have the pattern: /artist/sets/playlist-name
    is_set = is_soundcloud and length(path_parts) >= 3 and Enum.at(path_parts, 1) == "sets"
    # Also support likes/tracks pages: /artist (which lists tracks)
    is_set
  end

  # ============================================================================
  # YouTube Playlist Import
  # ============================================================================

  defp import_youtube_playlist(url) do
    case extract_youtube_playlist_id(url) do
      nil ->
        {:error, "Could not extract playlist ID from URL"}

      playlist_id ->
        Logger.info("[PlaylistImporter] Importing YouTube playlist: #{playlist_id}")

        playlist_url = "https://www.youtube.com/playlist?list=#{playlist_id}"

        case http_get_browser(playlist_url) do
          {:ok, body} ->
            playlist_name = extract_playlist_title_from_page(body) || "YouTube Playlist"

            # Extract API key and client version for pagination
            api_key = extract_yt_value(body, "INNERTUBE_API_KEY")
            client_version = extract_yt_value(body, "clientVersion")

            # Parse ytInitialData to get first page of videos + continuation token
            case extract_yt_initial_data(body) do
              {:ok, initial_data} ->
                {first_page_tracks, continuation_token} = extract_yt_playlist_items(initial_data)

                if Enum.empty?(first_page_tracks) do
                  {:error, "No videos found in this playlist. It may be private or empty."}
                else
                  # Fetch remaining pages via browse API
                  all_tracks = fetch_all_yt_pages(first_page_tracks, continuation_token, api_key, client_version)
                  all_tracks = Enum.take(all_tracks, @max_tracks)

                  Logger.info("[PlaylistImporter] Imported #{length(all_tracks)} YouTube tracks")
                  {:ok, %{name: playlist_name, tracks: all_tracks}}
                end

              :error ->
                # Fallback: extract video IDs from page HTML via regex
                import_youtube_from_page_html(body, playlist_name)
            end

          {:error, reason} ->
            {:error, "Failed to fetch YouTube playlist: #{reason}"}
        end
    end
  end

  defp extract_youtube_playlist_id(url) do
    case Regex.run(~r/[?&]list=([A-Za-z0-9_-]+)/, url) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp extract_yt_initial_data(html) do
    case Regex.run(~r/var\s+ytInitialData\s*=\s*(\{.+?\})\s*;\s*<\/script>/s, html) do
      [_, json_str] ->
        case Jason.decode(json_str) do
          {:ok, data} -> {:ok, data}
          _ -> :error
        end
      _ -> :error
    end
  end

  defp extract_yt_value(html, key) do
    case Regex.run(~r/"#{Regex.escape(key)}"\s*:\s*"([^"]+)"/, html) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp extract_yt_playlist_items(data) do
    # Navigate the ytInitialData structure to find playlist video renderers
    tabs = get_in(data, ["contents", "twoColumnBrowseResultsRenderer", "tabs"]) || []
    tab = List.first(tabs) || %{}
    contents = get_in(tab, ["tabRenderer", "content", "sectionListRenderer", "contents"]) || []
    section = List.first(contents) || %{}
    playlist_contents = get_in(section, ["itemSectionRenderer", "contents", Access.at(0), "playlistVideoListRenderer", "contents"]) || []

    {tracks, continuation} = extract_tracks_and_continuation(playlist_contents)
    {tracks, continuation}
  end

  defp extract_tracks_and_continuation(items) do
    tracks =
      items
      |> Enum.filter(&Map.has_key?(&1, "playlistVideoRenderer"))
      |> Enum.map(fn %{"playlistVideoRenderer" => renderer} ->
        video_id = renderer["videoId"]
        title = get_in(renderer, ["title", "runs", Access.at(0), "text"]) || "YouTube Video"
        build_youtube_track(video_id, title)
      end)
      |> Enum.filter(& &1)

    # Extract continuation token from the last item
    continuation =
      items
      |> Enum.find_value(nil, fn item ->
        case item do
          %{"continuationItemRenderer" => cont_renderer} ->
            # The token can be in different nested locations
            find_continuation_token(cont_renderer)
          _ -> nil
        end
      end)

    {tracks, continuation}
  end

  defp find_continuation_token(cont_renderer) do
    # Try direct path first
    direct_token = get_in(cont_renderer, ["continuationEndpoint", "continuationCommand", "token"])

    # Try nested commandExecutorCommand path (used in some playlist pages)
    commands_token =
      case get_in(cont_renderer, ["continuationEndpoint", "commandExecutorCommand", "commands"]) do
        commands when is_list(commands) ->
          Enum.find_value(commands, fn cmd ->
            get_in(cmd, ["continuationCommand", "token"])
          end)
        _ -> nil
      end

    token = direct_token || commands_token

    # Token must be non-empty
    if is_binary(token) and token != "", do: token, else: nil
  end

  defp fetch_all_yt_pages(tracks_so_far, nil, _api_key, _client_version), do: tracks_so_far
  defp fetch_all_yt_pages(tracks_so_far, _token, _api_key, _client_version)
    when length(tracks_so_far) >= @max_tracks, do: tracks_so_far
  defp fetch_all_yt_pages(tracks_so_far, _token, nil, _client_version), do: tracks_so_far

  defp fetch_all_yt_pages(tracks_so_far, token, api_key, client_version) do
    Logger.info("[PlaylistImporter] Fetching next YouTube page (#{length(tracks_so_far)} tracks so far)")

    browse_body = Jason.encode!(%{
      "context" => %{
        "client" => %{
          "clientName" => "WEB",
          "clientVersion" => client_version || "2.20260218.04.00"
        }
      },
      "continuation" => token
    })

    case http_post("#{@yt_browse_url}?key=#{api_key}", browse_body) do
      {:ok, resp_body} ->
        case Jason.decode(resp_body) do
          {:ok, resp_data} ->
            # Extract video items from continuation response
            continuation_items = extract_yt_continuation_items(resp_data)
            {new_tracks, next_token} = extract_tracks_and_continuation(continuation_items)

            if Enum.empty?(new_tracks) do
              tracks_so_far
            else
              fetch_all_yt_pages(tracks_so_far ++ new_tracks, next_token, api_key, client_version)
            end

          _ -> tracks_so_far
        end

      {:error, _} -> tracks_so_far
    end
  end

  defp extract_yt_continuation_items(resp_data) do
    # Browse API responses nest items under onResponseReceivedActions
    actions = resp_data["onResponseReceivedActions"] || []

    Enum.flat_map(actions, fn action ->
      get_in(action, ["appendContinuationItemsAction", "continuationItems"]) || []
    end)
  end

  defp build_youtube_track(nil, _title), do: nil
  defp build_youtube_track(video_id, title) do
    %{
      media_type: "youtube",
      media_id: video_id,
      title: title,
      thumbnail: "https://img.youtube.com/vi/#{video_id}/mqdefault.jpg",
      duration: 180,
      embed_url: "https://www.youtube.com/embed/#{video_id}?enablejsapi=1&autoplay=1&controls=1&rel=0&modestbranding=1&playsinline=1",
      original_url: "https://www.youtube.com/watch?v=#{video_id}"
    }
  end

  defp import_youtube_from_page_html(body, playlist_name) do
    # Fallback: extract video IDs via regex from the raw page HTML
    video_ids =
      Regex.scan(~r/"videoId"\s*:\s*"([A-Za-z0-9_-]{11})"/, body)
      |> Enum.map(fn [_, id] -> id end)
      |> Enum.uniq()
      |> Enum.take(@max_tracks)

    if Enum.empty?(video_ids) do
      {:error, "No videos found in this playlist. It may be private or empty."}
    else
      tracks =
        video_ids
        |> Task.async_stream(
          fn vid_id -> fetch_youtube_video_metadata(vid_id) end,
          max_concurrency: 5,
          timeout: 10_000,
          on_timeout: :kill_task
        )
        |> Enum.reduce([], fn
          {:ok, {:ok, track}}, acc -> [track | acc]
          _, acc -> acc
        end)
        |> Enum.reverse()

      Logger.info("[PlaylistImporter] Imported #{length(tracks)} YouTube tracks (HTML fallback)")
      {:ok, %{name: playlist_name, tracks: tracks}}
    end
  end

  defp extract_playlist_title_from_page(html) do
    case Regex.run(~r/<title>(.+?)(?:\s*-\s*YouTube)?<\/title>/s, html) do
      [_, title] ->
        title
        |> String.trim()
        |> HtmlEntities.decode()

      _ ->
        case Regex.run(~r/<meta\s+property="og:title"\s+content="([^"]+)"/, html) do
          [_, title] -> HtmlEntities.decode(title)
          _ -> nil
        end
    end
  end

  defp fetch_youtube_video_metadata(video_id) do
    oembed_url = "#{@yt_oembed}?url=https://www.youtube.com/watch?v=#{video_id}&format=json"

    case http_get(oembed_url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, data} ->
            {:ok, build_youtube_track(video_id, data["title"] || "YouTube Video")}
          _ ->
            {:error, :json_decode_failed}
        end

      {:error, _} ->
        {:ok, build_youtube_track(video_id, "YouTube Video (#{video_id})")}
    end
  end

  # ============================================================================
  # SoundCloud Playlist Import
  # ============================================================================

  defp import_soundcloud_playlist(url) do
    Logger.info("[PlaylistImporter] Importing SoundCloud playlist: #{url}")

    # Fetch the SoundCloud page and parse hydration data for track info
    case http_get(url) do
      {:ok, body} ->
        case extract_hydration_data(body) do
          {:ok, hydration} ->
            import_soundcloud_from_hydration(hydration, url, body)

          :error ->
            # Fallback: try regex-based extraction from page HTML
            import_soundcloud_from_page_html(body, url)
        end

      {:error, reason} ->
        {:error, "Failed to fetch SoundCloud playlist: #{reason}"}
    end
  end

  defp import_soundcloud_from_hydration(hydration, url, page_html) do
    # Find the playlist object in hydration data
    playlist_entry =
      Enum.find(hydration, fn entry ->
        entry["hydratable"] in ["playlist", "system-playlist"]
      end)

    case playlist_entry do
      %{"data" => playlist_data} ->
        playlist_name = playlist_data["title"] || "SoundCloud Playlist"
        raw_tracks = playlist_data["tracks"] || []

        if Enum.empty?(raw_tracks) do
          # No tracks array — try page HTML fallback
          import_soundcloud_from_page_html(page_html, url)
        else
          # Separate fully hydrated tracks from stub tracks (id-only)
          {full_tracks, stub_ids} =
            Enum.reduce(raw_tracks, {[], []}, fn track, {full, stubs} ->
              if track["title"] && track["permalink_url"] do
                {[track | full], stubs}
              else
                case track["id"] do
                  nil -> {full, stubs}
                  id -> {full, [id | stubs]}
                end
              end
            end)

          full_tracks = Enum.reverse(full_tracks)
          stub_ids = Enum.reverse(stub_ids)

          # Fetch metadata for stub tracks using client_id if we have stubs
          fetched_stubs =
            if Enum.empty?(stub_ids) do
              []
            else
              case scrape_client_id() do
                {:ok, client_id} ->
                  fetch_tracks_by_ids(stub_ids, client_id)

                :error ->
                  Logger.warning("[PlaylistImporter] Could not scrape SoundCloud client_id, #{length(stub_ids)} tracks will have minimal info")
                  # Build minimal tracks from IDs
                  Enum.map(stub_ids, fn id ->
                    %{"id" => id, "title" => "SoundCloud Track ##{id}", "permalink_url" => nil}
                  end)
              end
            end

          # Merge full + fetched tracks, preserving original order
          all_track_data = merge_tracks_in_order(raw_tracks, full_tracks, fetched_stubs)

          tracks =
            all_track_data
            |> Enum.take(@max_tracks)
            |> Enum.map(&hydration_track_to_map/1)

          Logger.info("[PlaylistImporter] Imported #{length(tracks)} SoundCloud tracks from hydration data")
          {:ok, %{name: playlist_name, tracks: tracks}}
        end

      _ ->
        # No playlist entry in hydration — try page HTML fallback
        import_soundcloud_from_page_html(page_html, url)
    end
  end

  defp extract_hydration_data(html) do
    # Extract the JSON array assigned to window.__sc_hydration
    # Use a greedy match up to the closing ];\s*</script> to capture the full array
    case Regex.run(~r/window\.__sc_hydration\s*=\s*(\[.*\])\s*;\s*<\/script>/s, html) do
      [_, json_str] ->
        case Jason.decode(json_str) do
          {:ok, data} when is_list(data) -> {:ok, data}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp scrape_client_id do
    # Fetch SoundCloud homepage and extract client_id from JS bundles
    case http_get("https://soundcloud.com") do
      {:ok, body} ->
        # Find script URLs
        script_urls =
          Regex.scan(~r/<script[^>]+src="(https:\/\/[^"]*sndcdn\.com\/[^"]+)"/, body)
          |> Enum.map(fn [_, url] -> url end)

        # Try the last few scripts (client_id is usually in the last bundle)
        script_urls
        |> Enum.reverse()
        |> Enum.take(3)
        |> Enum.find_value(:error, fn script_url ->
          case http_get(script_url) do
            {:ok, js_body} ->
              case Regex.run(~r/client_id\s*[:=]\s*"([a-zA-Z0-9]{32})"/, js_body) do
                [_, client_id] -> {:ok, client_id}
                _ -> nil
              end

            _ ->
              nil
          end
        end)

      {:error, _} ->
        :error
    end
  end

  defp fetch_tracks_by_ids(ids, client_id) do
    # Batch fetch in groups of 50
    ids
    |> Enum.chunk_every(50)
    |> Enum.flat_map(fn batch ->
      ids_param = Enum.join(batch, ",")
      api_url = "https://api-v2.soundcloud.com/tracks?ids=#{ids_param}&client_id=#{client_id}"

      case http_get(api_url) do
        {:ok, body} ->
          case Jason.decode(body) do
            {:ok, tracks} when is_list(tracks) -> tracks
            _ -> Enum.map(batch, fn id -> %{"id" => id, "title" => "Track ##{id}"} end)
          end

        {:error, _} ->
          Enum.map(batch, fn id -> %{"id" => id, "title" => "Track ##{id}"} end)
      end
    end)
  end

  defp merge_tracks_in_order(raw_tracks, full_tracks, fetched_stubs) do
    # Build lookup maps by ID
    full_map = Map.new(full_tracks, fn t -> {t["id"], t} end)
    stub_map = Map.new(fetched_stubs, fn t -> {t["id"], t} end)

    Enum.map(raw_tracks, fn raw ->
      id = raw["id"]
      cond do
        Map.has_key?(full_map, id) -> full_map[id]
        Map.has_key?(stub_map, id) -> stub_map[id]
        true -> raw
      end
    end)
  end

  defp hydration_track_to_map(track_data) do
    title = track_data["title"] || "SoundCloud Track"
    user = track_data["user"] || %{}
    artist = user["username"] || user["permalink"] || "Artist"
    permalink_url = track_data["permalink_url"]
    artwork_url = track_data["artwork_url"]
    duration_ms = track_data["full_duration"] || track_data["duration"] || 180_000

    # Use permalink_url if available, otherwise build from user + permalink
    track_url =
      cond do
        permalink_url -> permalink_url
        user["permalink"] && track_data["permalink"] ->
          "https://soundcloud.com/#{user["permalink"]}/#{track_data["permalink"]}"
        true ->
          nil
      end

    if track_url do
      build_soundcloud_track(track_url, "#{title} - #{artist}", artwork_url, div(duration_ms, 1000))
    else
      # Track without a URL — use a placeholder with the track ID
      id = track_data["id"] || :crypto.hash(:md5, title) |> Base.encode16() |> String.slice(0..10)
      %{
        media_type: "soundcloud",
        media_id: to_string(id),
        title: "#{title} - #{artist}",
        thumbnail: artwork_url,
        duration: div(duration_ms, 1000),
        embed_url: nil,
        original_url: nil
      }
    end
  end

  defp import_soundcloud_from_page_html(html, _url) do
    # Fallback: extract track URLs from page HTML via regex
    tracks =
      Regex.scan(~r/"permalink_url"\s*:\s*"(https?:\/\/soundcloud\.com\/[^"]+\/[^"]+)"/, html)
      |> Enum.map(fn [_, track_url] -> track_url end)
      |> Enum.uniq()
      |> Enum.reject(fn url ->
        String.contains?(url, "/sets/") or String.contains?(url, "/likes") or
          String.contains?(url, "/reposts")
      end)
      |> Enum.take(200)
      |> Enum.map(fn track_url ->
        track_name = track_url |> String.split("/") |> List.last() |> format_sc_name()
        artist_name = track_url |> String.split("/") |> Enum.at(-2, "Artist") |> format_sc_name()
        build_soundcloud_track(track_url, "#{track_name} by #{artist_name}")
      end)

    name =
      case Regex.run(~r/<title>(.+?)(?:\s*\|.*)?<\/title>/s, html) do
        [_, title] -> String.trim(title)
        _ -> "SoundCloud Playlist"
      end

    if Enum.empty?(tracks) do
      {:error, "Could not extract tracks from SoundCloud playlist. It may be private."}
    else
      {:ok, %{name: name, tracks: tracks}}
    end
  end

  defp build_soundcloud_track(url, title, artwork_url \\ nil, duration_secs \\ 180) do
    clean_url = url |> String.trim()
    media_id = :crypto.hash(:md5, clean_url) |> Base.encode16() |> String.slice(0..10)
    encoded_url = URI.encode(clean_url)

    %{
      media_type: "soundcloud",
      media_id: media_id,
      title: title,
      thumbnail: artwork_url,
      duration: duration_secs,
      embed_url: "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=true&buying=false&liking=false&download=false&sharing=false&show_artwork=true&show_comments=false&show_playcount=false&show_user=true&hide_related=true&visual=true&start_track=0&callback=true",
      original_url: clean_url
    }
  end

  defp format_sc_name(name) do
    name
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # ============================================================================
  # HTTP Helper
  # ============================================================================

  defp http_get(url, redirects \\ 5) do
    request = Finch.build(:get, url, [
      {"user-agent", "Mozilla/5.0 (compatible; PlaylistImporter/1.0)"},
      {"accept", "text/html,application/json,*/*"},
      {"accept-language", "en-US,en;q=0.9"}
    ])

    case Finch.request(request, @finch, receive_timeout: 15_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, headers: headers}} when status in [301, 302, 303, 307, 308] and redirects > 0 ->
        case List.keyfind(headers, "location", 0) do
          {_, redirect_url} -> http_get(redirect_url, redirects - 1)
          _ -> {:error, "Redirect without location header"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # GET with a real browser user-agent (needed for YouTube to return full page data)
  defp http_get_browser(url, redirects \\ 5) do
    request = Finch.build(:get, url, [
      {"user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
      {"accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
      {"accept-language", "en-US,en;q=0.9"}
    ])

    case Finch.request(request, @finch, receive_timeout: 30_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, headers: headers}} when status in [301, 302, 303, 307, 308] and redirects > 0 ->
        case List.keyfind(headers, "location", 0) do
          {_, redirect_url} -> http_get_browser(redirect_url, redirects - 1)
          _ -> {:error, "Redirect without location header"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # POST with JSON body (used for YouTube browse API)
  defp http_post(url, json_body) do
    request = Finch.build(:post, url, [
      {"content-type", "application/json"},
      {"user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    ], json_body)

    case Finch.request(request, @finch, receive_timeout: 30_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end

# Simple HTML entity decoder (avoids adding a dependency)
defmodule HtmlEntities do
  @entities %{
    "&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => "\"",
    "&#39;" => "'", "&apos;" => "'", "&nbsp;" => " ",
    "&#x27;" => "'", "&#x2F;" => "/", "&#38;" => "&",
    "&#34;" => "\"", "&#60;" => "<", "&#62;" => ">"
  }

  def decode(string) do
    Enum.reduce(@entities, string, fn {entity, char}, acc ->
      String.replace(acc, entity, char)
    end)
  end
end
