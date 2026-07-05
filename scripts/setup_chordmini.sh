#!/bin/sh
# Clones the ChordMini backend (MIT, github.com/ptnghia-j/ChordMiniApp) into
# vendor/ChordMiniApp so docker-compose can build the `chordmini` service.
#
# A local checkout is required because the chord/beat model weights live in
# git submodules, which Docker's git-URL build contexts don't fetch.
#
# Usage:  sh scripts/setup_chordmini.sh
set -e
cd "$(dirname "$0")/.."

PIN=daa299ceb616d24d888345d15cf54c938dcd6229

if [ ! -d vendor/ChordMiniApp ]; then
  git clone https://github.com/ptnghia-j/ChordMiniApp.git vendor/ChordMiniApp
fi

cd vendor/ChordMiniApp
git fetch --depth 1 origin "$PIN"
git checkout "$PIN"
git submodule update --init --depth 1 \
  python_backend/models/Beat-Transformer \
  python_backend/models/Chord-CNN-LSTM \
  python_backend/models/ChordMini

echo "ChordMini vendored at $PIN. Build with: docker compose build chordmini"
