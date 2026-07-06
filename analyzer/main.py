"""Audio analysis sidecar for the YouTube Video Chat App.

Downloads a track's audio with yt-dlp and runs Essentia to detect the
musical key, BPM, and a chord timeline.  Called by the Elixir app over
HTTP; results are cached in Postgres on the Elixir side, so each track
is only analyzed once.
"""

import logging
import os
import tempfile
import threading
import time

import essentia
import essentia.standard as es
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import yt_dlp

logger = logging.getLogger("uvicorn.error")

essentia.log.infoActive = False
essentia.log.warningActive = False

# Tracks longer than this are rejected — hour-long DJ mixes have no single
# key, and downloading + analyzing them would monopolize the container.
MAX_DURATION_S = int(os.environ.get("MAX_DURATION_SECONDS", "1200"))

# Self-hosted ChordMini backend (github.com/ptnghia-j/ChordMiniApp) for
# deep-learning chord recognition.  Empty/unset -> Essentia chords only.
CHORDMINI_URL = os.environ.get("CHORDMINI_URL", "").rstrip("/")
CHORDMINI_TIMEOUT_S = int(os.environ.get("CHORDMINI_TIMEOUT_S", "300"))

SAMPLE_RATE = 44100
FRAME_SIZE = 4096
HOP_SIZE = 2048
# Chord segments shorter than this are detection flicker, not real changes.
MIN_SEGMENT_S = 1.0

app = FastAPI()

# Analysis is CPU-bound; serialize so concurrent requests queue instead of
# thrashing a small container.  The Elixir worker also serializes, so this
# lock only matters if something else calls the API directly.
_analysis_lock = threading.Lock()


class AnalyzeRequest(BaseModel):
    media_type: str
    media_id: str
    url: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    with _analysis_lock:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _download_audio(req.url, tmpdir)
            return _analyze_file(path)


def _download_audio(url: str, tmpdir: str) -> str:
    opts = {
        "format": "bestaudio/best",
        "outtmpl": os.path.join(tmpdir, "audio.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        # YouTube intermittently 403s media downloads; retrying usually clears
        # it (the Elixir side also re-requests failed analyses after an hour).
        "retries": 3,
    }

    # Datacenter IPs (cloud deployments) get intermittent "confirm you're not
    # a bot" challenges from YouTube.  These knobs let a deployment try
    # alternative player clients or authenticate with exported cookies —
    # see analyzer/README.md.
    if clients := os.environ.get("YTDLP_PLAYER_CLIENTS"):
        opts["extractor_args"] = {"youtube": {"player_client": clients.split(",")}}
    cookies = os.environ.get("YTDLP_COOKIES_FILE")
    if cookies and os.path.exists(cookies):
        opts["cookiefile"] = cookies

    opts |= {
        # Essentia's bundled decoder is old and can't read Opus/WebM (YouTube's
        # usual bestaudio), so transcode to mono WAV with the system ffmpeg.
        "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "wav"}],
        "postprocessor_args": ["-ac", "1", "-ar", str(SAMPLE_RATE)],
    }
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
            duration = info.get("duration")
            if duration and duration > MAX_DURATION_S:
                raise HTTPException(
                    status_code=422,
                    detail=f"track is {duration}s, over the {MAX_DURATION_S}s analysis limit",
                )
            ydl.download([url])
    except yt_dlp.utils.DownloadError as e:
        raise HTTPException(status_code=422, detail=f"download failed: {e}") from e
    return os.path.join(tmpdir, "audio.wav")


def _analyze_file(path: str) -> dict:
    try:
        audio = es.MonoLoader(filename=path, sampleRate=SAMPLE_RATE)()
    except RuntimeError as e:
        raise HTTPException(status_code=422, detail=f"could not decode audio: {e}") from e
    if len(audio) < SAMPLE_RATE * 5:
        raise HTTPException(status_code=422, detail="audio too short to analyze")

    key, scale, strength = es.KeyExtractor()(audio)
    bpm = es.RhythmExtractor2013(method="degara")(audio)[0]
    chords, chord_engine = _detect_chords_best(path, audio)

    return {
        "key": key,
        "scale": scale,
        "key_strength": round(float(strength), 3),
        "bpm": round(float(bpm), 1),
        "chords": chords,
        "chord_engine": chord_engine,
    }


def _detect_chords_best(path, audio):
    """ChordMini (deep model, much better accuracy) when configured and
    reachable; Essentia's template matching otherwise."""
    if CHORDMINI_URL:
        try:
            return _detect_chords_chordmini(path), "chordmini"
        except Exception as e:
            logger.warning("ChordMini failed (%s); falling back to Essentia chords", e)
    return _detect_chords(audio), "essentia"


def _detect_chords_chordmini(path: str) -> list:
    # ChordMini rate-limits recognize-chords (~2/min) even self-hosted and
    # offers no disable flag; honor Retry-After instead of falling back to
    # the worse Essentia chords, since results are cached forever upstream.
    for attempt in range(3):
        with open(path, "rb") as f:
            resp = requests.post(
                f"{CHORDMINI_URL}/api/recognize-chords",
                files={"file": ("audio.wav", f, "audio/wav")},
                timeout=CHORDMINI_TIMEOUT_S,
            )
        if resp.status_code != 429:
            break
        wait = min(int(resp.headers.get("Retry-After", 35) or 35), 120)
        logger.info("ChordMini rate-limited; retrying in %ss", wait)
        time.sleep(wait)
    resp.raise_for_status()
    data = resp.json()
    if not data.get("success"):
        raise RuntimeError(data.get("error", "chordmini returned success=false"))

    segments = []
    for entry in data.get("chords", []):
        label = _friendly_label(entry.get("chord"))
        if segments and segments[-1]["c"] == label:
            continue
        segments.append({"t": round(float(entry["start"]), 2), "c": label})
    return segments


# ChordMini emits MIREX-style labels ("C#:min7", "F:maj/3").  Map the common
# qualities to compact display names; unknown qualities pass through as-is.
QUALITY_MAP = {
    "maj": "", "min": "m", "dim": "dim", "aug": "aug",
    "maj7": "maj7", "min7": "m7", "7": "7", "maj6": "6", "min6": "m6",
    "sus2": "sus2", "sus4": "sus4", "dim7": "dim7", "hdim7": "m7b5",
    "minmaj7": "mMaj7", "maj9": "maj9", "min9": "m9", "9": "9",
}


def _friendly_label(chord) -> str:
    if not chord or chord in ("N", "X"):
        return "N"
    root, _, quality = chord.partition(":")
    root = root.split("/")[0]
    quality = quality.split("/")[0]  # drop bass/inversion for display
    return root + QUALITY_MAP.get(quality, quality)


def _detect_chords(audio) -> list:
    windowing = es.Windowing(type="blackmanharris62")
    spectrum = es.Spectrum()
    peaks = es.SpectralPeaks(
        orderBy="magnitude",
        magnitudeThreshold=0.00001,
        minFrequency=20,
        maxFrequency=3500,
        maxPeaks=60,
    )
    hpcp = es.HPCP()

    hpcps = []
    for frame in es.FrameGenerator(audio, frameSize=FRAME_SIZE, hopSize=HOP_SIZE):
        freqs, mags = peaks(spectrum(windowing(frame)))
        hpcps.append(hpcp(freqs, mags))
    if not hpcps:
        return []

    chords, _strengths = es.ChordsDetection(hopSize=HOP_SIZE, windowSize=2.0)(
        essentia.array(hpcps)
    )
    return _collapse(chords)


def _collapse(chords) -> list:
    """Frame-wise chord labels -> [{t: start_seconds, c: chord}] segments,
    dropping flickers shorter than MIN_SEGMENT_S."""
    frame_s = HOP_SIZE / SAMPLE_RATE

    raw = []
    for i, chord in enumerate(chords):
        if not raw or raw[-1][1] != chord:
            raw.append((i * frame_s, chord))

    total = len(chords) * frame_s
    out = []
    for idx, (t, chord) in enumerate(raw):
        end = raw[idx + 1][0] if idx + 1 < len(raw) else total
        if end - t < MIN_SEGMENT_S:
            continue
        if out and out[-1]["c"] == chord:
            continue
        out.append({"t": round(t, 2), "c": chord})
    return out
