#!/bin/bash

# View Docker logs with SoundCloud keyword highlighting

echo "📺 Viewing Docker logs (highlighting SoundCloud activity)..."
echo "============================================"
echo "Press Ctrl+C to stop"
echo ""

# Follow logs and highlight SoundCloud-related messages
docker-compose logs -f web | grep --color=always -E "SoundCloud|soundcloud|MediaPlayer|media_player|SC\.|Widget|FINISH|video_ended|media_changed|Current track|embed_url|"