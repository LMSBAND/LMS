#!/bin/bash
# assign_sample.sh — Assign a single wav file to a specific pad in a kit
#
# Usage:  ./assign_sample.sh <wav_file> <kit_number 1-8> <pad_number 1-16>
# Example: ./assign_sample.sh ~/Downloads/my_kick.wav 2 1
#
# Copies the wav file into the kit folder as the correct pad number.
# Switch kits in the plugin to hear the change (or switch away and back).

set -e

KITS_DIR="$HOME/.config/REAPER/Effects/DrumBox16/kits"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <wav_file> <kit 1-8> <pad 1-16>"
    echo ""
    echo "Example: $0 ~/Downloads/fat_kick.wav 2 1"
    echo "  → Assigns fat_kick.wav to Pad 1 of Kit 2"
    echo ""
    echo "Current kit contents:"
    for k in 1 2 3 4 5 6 7 8; do
        dir="$KITS_DIR/$k"
        if [ -d "$dir" ] && ls "$dir"/*.wav &>/dev/null; then
            count=$(ls "$dir"/*.wav 2>/dev/null | wc -l)
            echo "  Kit $k: $count pads loaded"
        fi
    done
    exit 1
fi

WAV="$1"
KIT="$2"
PAD="$3"

if [ ! -f "$WAV" ]; then
    echo "Error: '$WAV' not found"
    exit 1
fi

if [ "$KIT" -lt 1 ] || [ "$KIT" -gt 8 ]; then
    echo "Error: kit must be 1-8"
    exit 1
fi

if [ "$PAD" -lt 1 ] || [ "$PAD" -gt 16 ]; then
    echo "Error: pad must be 1-16"
    exit 1
fi

DEST="$KITS_DIR/$KIT"
mkdir -p "$DEST"

PADNUM=$(printf "%02d" "$PAD")
cp "$WAV" "$DEST/$PADNUM.wav"
echo "Pad $PAD (Kit $KIT) ← $(basename "$WAV")"
echo "Switch to Kit $KIT in DrumBox16 to hear it."
