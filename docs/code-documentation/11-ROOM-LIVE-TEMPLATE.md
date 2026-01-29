# 11-ROOM-LIVE-TEMPLATE.md - Room HTML Template

## File: `lib/youtube_video_chat_app_web/live/room_live/show.html.heex`

This is the HEEx (HTML + Embedded Elixir) template for the room view. It defines the entire UI for the video watching experience.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Room Template Layout                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Header Bar                            ││
│  │  [Room Name]            [Chat] [Queue] [Leave]          ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌───────────────────────────────────────┐ ┌──────────────┐│
│  │                                       │ │              ││
│  │                                       │ │   Playlist   ││
│  │          Media Container              │ │    Panel     ││
│  │           (phx-update="ignore")       │ │  (optional)  ││
│  │                                       │ │              ││
│  └───────────────────────────────────────┘ └──────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Chat History (scrollable)                              ││
│  │  [Message 1] [Message 2] [Message 3]...                 ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  [Chat Input..............................] [Send]       ││
│  │  [❤️] [🔥] [😂] [👏]   Chatting as Guest1234            ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Root Container

```heex
<div class="relative w-full h-screen bg-black overflow-hidden" 
     id="room-container" 
     phx-hook="VideoEndedPusher">
```

| Attribute | Purpose |
|-----------|---------|
| `relative w-full h-screen` | Full viewport height, positioned relative |
| `bg-black overflow-hidden` | Black background, no scrollbars |
| `id="room-container"` | Used by JavaScript to find this element |
| `phx-hook="VideoEndedPusher"` | Attaches LiveView hook for video events |

## Media Container

```heex
<div class="absolute inset-0 w-full h-full" 
     id="media-container" 
     phx-update="ignore">
  <!-- Player will be injected here by JavaScript -->
  <div class="flex items-center justify-center w-full h-full bg-gray-900" 
       id="no-media-placeholder">
    <div class="text-center">
      <svg class="w-24 h-24 mx-auto mb-4 text-gray-600" ...>
        <!-- Play icon SVG -->
      </svg>
      <p class="text-white text-xl mb-2">No media playing</p>
      <p class="text-gray-400 text-sm">Add a YouTube video or SoundCloud track to get started</p>
    </div>
  </div>
</div>
```

### Key Attribute: `phx-update="ignore"`

**Critical!** This tells LiveView to NEVER touch this element's contents after initial render.

**Why?**
- JavaScript creates the video player dynamically
- If LiveView re-rendered, it would destroy the player
- The `phx-update="ignore"` protects the JavaScript-managed content

**Without it**: Every LiveView update would reset the player and stop video playback.

## Header Bar

```heex
<div class="absolute top-0 left-0 right-0 p-4 pointer-events-auto 
            bg-gradient-to-b from-black/50 to-transparent">
  <div class="flex items-center justify-between">
```

**Styling**:
- `absolute top-0` - Fixed at top
- `pointer-events-auto` - Clickable (parent has `pointer-events-none`)
- `bg-gradient-to-b from-black/50 to-transparent` - Fade effect

### Room Info (Left Side)

```heex
<div class="flex items-center gap-3">
  <div class="w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 
              flex items-center justify-center">
    <span class="text-white text-sm font-bold">
      <%= String.first(@room.name) %>
    </span>
  </div>
  <div>
    <h3 class="text-white font-semibold"><%= @room.name %></h3>
    <div class="flex items-center gap-2">
      <span class="inline-flex items-center gap-1 text-xs text-gray-300">
        <span class="w-1.5 h-1.5 bg-red-500 rounded-full animate-pulse"></span>
        <%= map_size(@presences) %> watching
      </span>
    </div>
  </div>
</div>
```

**Dynamic content**:
- `String.first(@room.name)` - First letter as avatar
- `map_size(@presences)` - Live viewer count

### Action Buttons (Right Side)

```heex
<button
  phx-click="toggle_chat"
  class="p-2 bg-black/30 backdrop-blur rounded-full text-white hover:bg-black/50 transition"
  title={if @show_chat, do: "Hide chat", else: "Show chat"}
>
  <svg ...>
    <path d={if @show_chat, do: "chat_icon_filled", else: "chat_icon_outline"} />
  </svg>
</button>
```

**Features**:
- `phx-click="toggle_chat"` - Sends event to LiveView
- Dynamic icon path based on `@show_chat` state
- Dynamic title attribute

## Queue Panel (Side Panel)

```heex
<div 
  :if={@show_queue}
  class="absolute top-20 right-4 bottom-32 w-96 pointer-events-auto"
>
```

**`:if={@show_queue}`** - Conditional rendering (only shown when true)

### Add Media Form

```heex
<form phx-submit="add_video" class="mb-4">
  <div class="relative">
    <input
      type="text"
      name="url"
      value={@add_video_url}
      placeholder="Paste YouTube or SoundCloud URL..."
      class="w-full px-4 py-2.5 bg-white/10 text-white text-sm rounded-lg border 
             border-white/20 focus:border-purple-500 focus:outline-none 
             placeholder-gray-400 pr-10"
    />
    <button type="submit" class="absolute right-2 top-1/2 -translate-y-1/2 ...">
      <!-- Plus icon -->
    </button>
  </div>
</form>
```

**`phx-submit="add_video"`**: Form submission triggers `handle_event("add_video", ...)` in LiveView.

### Now Playing Section

```heex
<%= if @current_media do %>
  <div class="mb-4">
    <h4 class="text-xs font-semibold text-green-400 uppercase tracking-wider mb-2 
               flex items-center gap-1">
      <span class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></span>
      Now Playing
    </h4>
    <div class="bg-gradient-to-r from-purple-600/20 to-pink-600/20 
                border border-purple-500/30 rounded-lg p-3">
      <div class="flex items-center gap-3">
        <div class="relative flex-shrink-0">
          <% media_type = Map.get(@current_media, :type) || Map.get(@current_media, "type") %>
          <%= if media_type == "soundcloud" do %>
            <div class="w-16 h-16 bg-gradient-to-br from-orange-500 to-orange-600 
                        rounded flex items-center justify-center">
              <!-- SoundCloud icon -->
            </div>
          <% else %>
            <img 
              src={Map.get(@current_media, :thumbnail) || Map.get(@current_media, "thumbnail")}
              alt={Map.get(@current_media, :title) || Map.get(@current_media, "title")}
              class="w-16 h-16 object-cover rounded"
            />
          <% end %>
          <!-- Animated Playing Indicator -->
          <div class="absolute -bottom-1 left-1/2 -translate-x-1/2 flex gap-0.5">
            <span class="w-1 h-3 bg-green-400 rounded-full animate-bounce" 
                  style="animation-delay: 0ms"></span>
            <span class="w-1 h-3 bg-green-400 rounded-full animate-bounce" 
                  style="animation-delay: 150ms"></span>
            <span class="w-1 h-3 bg-green-400 rounded-full animate-bounce" 
                  style="animation-delay: 300ms"></span>
          </div>
        </div>
        ...
      </div>
    </div>
  </div>
<% end %>
```

**Handling mixed key types**:
```elixir
Map.get(@current_media, :type) || Map.get(@current_media, "type")
```
This handles both atom keys (`:type`) and string keys (`"type"`) since data might come from different sources.

### Queue Items List

```heex
<%= for {media, index} <- Enum.with_index(@queue) do %>
  <% media_type = Map.get(media, :type) || Map.get(media, "type") %>
  <% media_title = Map.get(media, :title) || Map.get(media, "title") || "Unknown" %>
  <% media_id = Map.get(media, :id) || Map.get(media, "id") %>
  
  <div class="flex items-center gap-2 p-2 bg-white/5 rounded-lg 
              hover:bg-white/10 transition group">
    <!-- Queue Position -->
    <div class="flex-shrink-0 w-6 text-center">
      <span class="text-gray-500 text-xs font-medium"><%= index + 1 %></span>
    </div>
    
    <!-- Thumbnail + Info -->
    ...
    
    <!-- Remove Button (Host Only) -->
    <%= if @is_host do %>
      <button
        phx-click="remove_from_queue"
        phx-value-id={media_id}
        class="opacity-0 group-hover:opacity-100 p-1.5 text-gray-400 
               hover:text-red-500 transition"
        title="Remove from queue"
      >
        <!-- X icon -->
      </button>
    <% end %>
  </div>
<% end %>
```

**Key patterns**:
- `Enum.with_index(@queue)` - Get both item and position
- `phx-value-id={media_id}` - Pass data to event handler
- `<%= if @is_host do %>` - Conditional host-only controls
- `group-hover:opacity-100` - Show on parent hover (Tailwind)

## Chat Section

### Chat History

```heex
<div 
  :if={@show_chat}
  class="relative h-48 pb-2 overflow-y-auto scrollbar-thin scrollbar-thumb-white/20"
  id="chat-history"
  phx-hook="ChatScroll"
  style="margin-bottom: 45px; padding-left: 1rem;"
>
  <div class="space-y-1" id="messages-container" 
       style={if @show_queue, do: "margin-right: 416px;", else: "margin-right: 0;"}>
    <%= for message <- Enum.reverse(@messages) do %>
      <div class="flex items-start gap-2 text-sm max-w-2xl">
        <span class="font-bold shrink-0" 
              style={"color: #{message.color}; text-shadow: ..."} >
          <%= message.username %>:
        </span>
        <span class="text-white break-words font-semibold" style="text-shadow: ...;">
          <%= linkify_text(message.text) %>
        </span>
      </div>
    <% end %>
  </div>
</div>
```

**Key features**:
- `phx-hook="ChatScroll"` - Auto-scroll behavior
- `Enum.reverse(@messages)` - Newest at bottom
- `linkify_text(message.text)` - Converts URLs to links/images
- `text-shadow` - Makes text readable over video

### Chat Input

```heex
<form phx-submit="send_message" class="flex-1 flex gap-2">
  <input 
    type="text"
    name="message"
    placeholder="Add a comment..."
    class="flex-1 px-4 py-2.5 bg-black/60 text-white rounded-full border 
           border-black/80 backdrop-blur focus:border-purple-500 
           focus:outline-none placeholder-gray-400 text-sm font-bold"
    autocomplete="off"
    maxlength="100"
  />
  <button type="submit" class="p-2.5 bg-gradient-to-r from-purple-600 to-pink-600 
                               hover:from-purple-700 hover:to-pink-700 
                               text-white rounded-full transition">
    <!-- Send icon -->
  </button>
</form>
```

### Reaction Buttons

```heex
<div class="flex items-center gap-1">
  <button 
    phx-click="send_reaction"
    phx-value-emoji="❤️"
    class="p-2 hover:scale-110 transition-transform"
  >
    <span class="text-2xl">❤️</span>
  </button>
  <button phx-click="send_reaction" phx-value-emoji="🔥" ...>
    <span class="text-2xl">🔥</span>
  </button>
  <!-- More reactions... -->
</div>
```

**`phx-value-*` attributes**: Pass data to event handler.

```elixir
# In LiveView
def handle_event("send_reaction", %{"emoji" => emoji}, socket) do
  # emoji = "❤️"
end
```

### Reactions Container

```heex
<div id="reactions-container" class="absolute bottom-20 right-4 pointer-events-none">
  <!-- Reactions will be dynamically added here by JavaScript -->
</div>
```

JavaScript adds animated emoji elements here when reactions are received.

## Key HEEx Patterns

### Conditional Rendering

```heex
<!-- Using :if directive -->
<div :if={@show_chat}>Only shown when @show_chat is true</div>

<!-- Using if/else -->
<%= if @current_media do %>
  <p>Playing: <%= @current_media.title %></p>
<% else %>
  <p>Nothing playing</p>
<% end %>
```

### Dynamic Attributes

```heex
<!-- Dynamic classes -->
<div class={if @is_host, do: "bg-purple-500", else: "bg-gray-500"}>

<!-- Dynamic styles -->
<span style={"color: #{message.color}"}>

<!-- Dynamic paths -->
<path d={if @show_chat, do: "M8 12h.01...", else: "M20 2H4..."} />
```

### Event Handlers

```heex
<!-- Click events -->
<button phx-click="toggle_chat">Click me</button>

<!-- With value -->
<button phx-click="remove" phx-value-id={item.id}>Remove</button>

<!-- Form submission -->
<form phx-submit="add_video">
  <input name="url" />
</form>
```

## Related Files

| File | Purpose |
|------|---------|
| `show.ex` | LiveView logic |
| `app.js` | JavaScript player logic |
| `app.css` | Custom styles and animations |
