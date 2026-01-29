# SoundCloud Integration Guide

## Overview
The YouTube Video Chat App now supports SoundCloud tracks in addition to YouTube videos! Users can add both YouTube videos and SoundCloud tracks to the queue, creating a mixed media playlist experience.

## Features Added

### 1. **Mixed Media Queue**
- Support for both YouTube videos and SoundCloud tracks in the same queue
- Visual indicators (badges) showing media type
- Automatic media player switching between YouTube and SoundCloud

### 2. **SoundCloud Player**
- Beautiful gradient background when playing SoundCloud tracks
- Centered, responsive SoundCloud player widget
- Full SoundCloud player controls and visualizations

### 3. **URL Support**
The app now accepts:
- YouTube URLs:
  - `https://www.youtube.com/watch?v=VIDEO_ID`
  - `https://youtu.be/VIDEO_ID`
  - Direct video IDs
- SoundCloud URLs:
  - Any SoundCloud track URL
  - Example: `https://soundcloud.com/artist/track-name`

### 4. **Queue Management**
- Visual differentiation between YouTube (YT badge) and SoundCloud (SC badge)
- SoundCloud tracks show with an orange gradient thumbnail
- Host can skip both YouTube videos and SoundCloud tracks

## How to Use

1. **Adding Media to Queue**:
   - Paste either a YouTube or SoundCloud URL in the queue input field
   - The app automatically detects the media type
   - Media is added to the queue with appropriate visualization

2. **Media Playback**:
   - YouTube videos play in full-screen mode
   - SoundCloud tracks display with a centered player and gradient background
   - Auto-advance to next item in queue when current media ends

3. **Host Controls**:
   - Only the room host can skip tracks
   - Host controls work for both media types
   - Auto-play next item when current finishes

## Technical Implementation

### Backend Changes

1. **`RoomLive.Show` Module**:
   - Added `parse_media_url/1` function to detect media type
   - Updated `extract_soundcloud_data/1` to parse SoundCloud URLs
   - Changed from `current_video_id` to `current_media` structure

2. **`RoomServer` Module**:
   - Updated state to use `current_media` instead of `current_video`
   - Modified broadcast functions to handle media objects
   - Queue now supports mixed media types

3. **Data Structure**:
   ```elixir
   %{
     type: "youtube" | "soundcloud",
     media_id: String.t(),
     title: String.t(),
     thumbnail: String.t(),
     embed_url: String.t(),
     duration: integer()
   }
   ```

### Frontend Changes

1. **Template Updates**:
   - Conditional rendering based on media type
   - SoundCloud player with gradient background
   - Media type badges in queue

2. **JavaScript Hooks**:
   - New `MediaPlayer` hook supporting both platforms
   - SoundCloud Widget API integration
   - Auto-detection of media end events

## Running the Application

1. **Install dependencies**:
   ```bash
   mix deps.get
   cd assets && npm install
   ```

2. **Start the server**:
   ```bash
   mix phx.server
   ```
   Or with Docker:
   ```bash
   docker-compose up
   ```

3. **Access the app**:
   - Navigate to http://localhost:4000
   - Create or join a room
   - Start adding YouTube videos and SoundCloud tracks!

## Browser Compatibility
- Chrome, Firefox, Safari, Edge (latest versions)
- Requires JavaScript enabled
- SoundCloud Widget API loaded dynamically when needed

## Known Limitations
- SoundCloud track titles are extracted from URLs (may not always be accurate)
- No YouTube/SoundCloud API keys required (uses embed functionality)
- Media synchronization is disabled for iframe mode

## Future Enhancements
- Spotify integration
- Apple Music support
- Custom playlists
- Media search functionality
- Volume normalization between sources

## Troubleshooting

If SoundCloud tracks don't play:
1. Check if the SoundCloud URL is valid and publicly accessible
2. Ensure the track allows embedding
3. Check browser console for any errors
4. Try refreshing the page

If YouTube videos don't play:
1. Verify the YouTube URL is correct
2. Ensure the video is not private or age-restricted
3. Check for any browser extensions blocking embeds

## Support
For issues or questions, please check the existing documentation or create an issue in the project repository.