#!/bin/bash
# scan_pool.sh — Scan the sample pool and generate manifest for DrumBox16
#
# Usage: ./scan_pool.sh [pool_folder]
#   Default pool folder: ~/.config/REAPER/Effects/DrumBox16/pool
#
# Run this after adding/removing wav files from the pool folder.
# Then reload the plugin in REAPER (or switch kit back and forth).
#
# Supports subdirectories — files are listed with relative paths:
#   kicks/808.wav
#   snares/clap.wav
#   oneshot.wav

set -e

POOL_DIR="${1:-$HOME/.config/REAPER/Effects/DrumBox16/pool}"
MANIFEST="$POOL_DIR/manifest.txt"

if [ ! -d "$POOL_DIR" ]; then
    echo "Error: pool folder '$POOL_DIR' not found"
    exit 1
fi

# Find all wav files recursively, output paths relative to pool dir
cd "$POOL_DIR"
find . -iname "*.wav" | sed 's|^\./||' | sort > "$MANIFEST"

COUNT=$(wc -l < "$MANIFEST")
echo "Scanned $COUNT samples into manifest."
echo "Pool: $POOL_DIR"
echo "Manifest: $MANIFEST"

if [ "$COUNT" -gt 0 ]; then
    echo ""
    echo "Samples:"
    cat -n "$MANIFEST"
fi
