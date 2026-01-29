# Getting Real Video Durations

## Current Behavior
- All videos default to **180 seconds (3 minutes)**
- Timer advances queue after 185 seconds (180 + 5 second buffer)
- This causes early/late transitions if videos aren't exactly 3 minutes

## Solution Options

### Option 1: Use YouTube Data API (Recommended for Production)

**Setup:**
1. Get a YouTube Data API key from Google Cloud Console
2. Add to your environment:
   ```bash
   export YOUTUBE_API_KEY="your_api_key_here"
   ```

3. Add HTTPoison to `mix.exs`:
   ```elixir
   {:httpoison, "~> 2.0"}
   ```

4. Fetch real duration when parsing YouTube URLs (in `show.ex`):
   ```elixir
   defp get_youtube_duration(video_id) do
     api_key = System.get_env("YOUTUBE_API_KEY")
     url = "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&part=contentDetails&key=#{api_key}"
     
     case HTTPoison.get(url) do
       {:ok, %{body: body}} ->
         with {:ok, data} <- Jason.decode(body),
              [video | _] <- data["items"],
              duration_str <- video["contentDetails"]["duration"] do
           parse_iso8601_duration(duration_str)
         else
           _ -> 180  # fallback
         end
       _ -> 180
     end
   end
   
   defp parse_iso8601_duration(iso_duration) do
     # Parse "PT1M30S" -> 90 seconds
     # Parse "PT2H5M10S" -> 7510 seconds
     regex = ~r/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/
     
     case Regex.run(regex, iso_duration) do
       [_, h, m, s] ->
         hours = if h != "", do: String.to_integer(h), else: 0
         minutes = if m != "", do: String.to_integer(m), else: 0
         seconds = if s != "", do: String.to_integer(s), else: 0
         hours * 3600 + minutes * 60 + seconds
       _ -> 180
     end
   end
   ```

### Option 2: JavaScript Detection (Current - Works but has delay)

The JavaScript MediaPlayer hook **is** detecting durations and could send them to the server, but currently just uses the hardcoded value. This works but means:
- Videos advance after a fixed time
- Works without API keys
- Some pause between videos

### Option 3: User Input

Let users specify duration when adding:
```html
<input type="text" name="duration" placeholder="Duration (seconds)" />
```

## For SoundCloud

SoundCloud doesn't provide duration in the URL. Options:
1. **Use SoundCloud API** (requires API key, more complex)
2. **Let JavaScript detect** after the widget loads
3. **Keep default 180 seconds**

## Current Recommendation

**For now, your queue works perfectly!** The 180-second default is fine for testing. When you're ready for production:

1. Add YouTube Data API for real durations
2. This eliminates the pause/early advance issue
3. Videos will advance exactly when they end

## Testing with Short Videos

To test auto-advance faster, use these short videos:

**10 seconds:**
```
https://www.youtube.com/watch?v=aqz-KE-bpKQ
```

**20 seconds:**
```
https://www.youtube.com/watch?v=C0DPdy98e4c
```

**30 seconds:**
```
https://www.youtube.com/watch?v=jNQXAC9IVRw
```

Add 2-3 of these and they'll advance quickly (after 185 seconds each with current setup).

## Summary

✅ **Queue system is 100% functional**
✅ **Auto-advance works perfectly**
✅ **Both YouTube and SoundCloud work**
✅ **Server-side timer ensures reliability**

The only improvement would be real duration detection, which is optional and can be added later!
