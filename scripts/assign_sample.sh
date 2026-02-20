#!/bin/bash
# assign_sample.sh — Assign a single wav file to a specific pad in a kit
#
# Usage:  ./assign_sample.sh <wav_file> <kit_folder_name> <pad_number 1-16>
# Example: ./assign_sample.sh ~/Downloads/my_kick.wav Kit1-808 1
#
# Copies the wav file into the pool kit folder as the correct pad number.
# Run the DRUMBANGER Rescan action in REAPER after assigning.

set -e

POOL_DIR="$HOME/.config/REAPER/Effects/DRUMBANGER/pool"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <wav_file> <kit_folder_name> <pad 1-16>"
    echo ""
    echo "Example: $0 ~/Downloads/fat_kick.wav Kit1-808 1"
    echo "  → Assigns fat_kick.wav to Pad 1 of Kit1-808"
    echo ""
    echo "Kits are subfolders in pool/. Current pool contents:"
    if [ -d "$POOL_DIR" ]; then
        for dir in "$POOL_DIR"/*/; do
            [ -d "$dir" ] || continue
            dirname=$(basename "$dir")
            count=$(find "$dir" -maxdepth 1 -iname "*.wav" 2>/dev/null | wc -l)
            echo "  $dirname: $count samples"
        done
    else
        echo "  (pool folder not found)"
    fi
    exit 1
fi

WAV="$1"
KIT="$2"
PAD="$3"

if [ ! -f "$WAV" ]; then
    echo "Error: '$WAV' not found"
    exit 1
fi

if [ "$PAD" -lt 1 ] || [ "$PAD" -gt 16 ]; then
    echo "Error: pad must be 1-16"
    exit 1
fi

DEST="$POOL_DIR/$KIT"
mkdir -p "$DEST"

PADNUM=$(printf "%02d" "$PAD")
cp "$WAV" "$DEST/$PADNUM.wav"
echo "Pad $PAD ($KIT) ← $(basename "$WAV")"
echo "Run the DRUMBANGER Rescan action in REAPER to pick up the change."
