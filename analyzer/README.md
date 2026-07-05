# Audio Analyzer Sidecar

Detects the musical **key**, **BPM**, and a **chord timeline** for tracks
queued in the app, using [Essentia](https://essentia.upf.edu/) with audio
fetched by yt-dlp.

## Why a sidecar?

- The browser can't tap audio from YouTube/SoundCloud iframes (cross-origin),
  so analysis must happen server-side.
- Essentia ships no Windows wheels, so this always runs in Docker (Linux).

## API

```
POST /analyze
{"media_type": "youtube", "media_id": "dQw4w9WgXcQ", "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}

200 → {"key": "Ab", "scale": "major", "key_strength": 0.917, "bpm": 113.6,
       "chords": [{"t": 1.72, "c": "Ab"}, {"t": 4.46, "c": "Bbm"}, ...]}
422 → {"detail": "..."}   # too long, download failed, undecodable audio
```

`chords` is a list of segments: `t` = start time in seconds, `c` = chord label.

## Chord engines

Chords come from one of two engines (reported as `chord_engine` in the
response):

1. **ChordMini** (preferred) — the self-hosted
   [ChordMiniApp](https://github.com/ptnghia-j/ChordMiniApp) backend
   (Chord-CNN-LSTM, 301 chord labels).  Enabled when `CHORDMINI_URL` is set;
   docker-compose runs it as the `chordmini` service.  Note: their *hosted*
   API at chordmini.me is gated behind Firebase App Check and cannot be
   called server-to-server — self-hosting is the only option.
2. **Essentia** (fallback) — HPCP template matching (major/minor triads
   only).  Used when `CHORDMINI_URL` is unset or the service is
   unreachable/errors, so tracks always get *some* chord timeline.

Key and BPM always come from Essentia — they've proven accurate and avoid a
second model pass.  MIREX-style labels from ChordMini (`C#:min7`) are mapped
to compact display form (`C#m7`); bass inversions are dropped.

## Behavior notes

- Requests are serialized with a lock — analysis is CPU-bound.
- Tracks longer than `MAX_DURATION_SECONDS` (default 1200) are rejected;
  hour-long mixes have no single key and would monopolize the container.
- Audio is transcoded to mono WAV before analysis because Essentia's bundled
  decoder can't read Opus/WebM.
- The Elixir app (see `YoutubeVideoChatApp.AudioAnalysis`) caches results in
  Postgres and never re-analyzes a completed track.

## Running locally

```
sh scripts/setup_chordmini.sh  # once: vendor the ChordMini backend + models
docker compose up -d analyzer  # starts chordmini too (depends_on)
curl http://localhost:8000/health
```

Without the setup script (or if the chordmini service is down), everything
still works — chords just come from the Essentia fallback engine.
