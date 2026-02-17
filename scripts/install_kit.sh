#!/bin/bash
# install_kit.sh — Install a folder of wav files as a DRUMBANGER kit
#
# Usage:  ./install_kit.sh <source_folder> <kit_number 1-8>
# Example: ./install_kit.sh ~/Downloads/808_samples 2
#
# Takes the first 16 .wav files (sorted alphabetically) from the source
# folder and copies them as 01.wav-16.wav into the kit slot.

set -e

KITS_DIR="$HOME/.config/REAPER/Effects/DRUMBANGER/kits"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_folder> <kit_number 1-8>"
    echo ""
    echo "Example: $0 ~/Downloads/808_kit 2"
    echo ""
    echo "Current kits:"
    for i in 1 2 3 4 5 6 7 8; do
        dir="$KITS_DIR/$i"
        if [ -d "$dir" ]; then
            count=$(ls "$dir"/*.wav 2>/dev/null | wc -l)
            echo "  Kit $i: $count samples"
        else
            echo "  Kit $i: (empty)"
        fi
    done
    exit 1
fi

SRC="$1"
KIT="$2"

if [ ! -d "$SRC" ]; then
    echo "Error: '$SRC' is not a directory"
    exit 1
fi

if [ "$KIT" -lt 1 ] || [ "$KIT" -gt 8 ]; then
    echo "Error: kit number must be 1-8"
    exit 1
fi

DEST="$KITS_DIR/$KIT"
mkdir -p "$DEST"

# Find wav files (case-insensitive), sorted alphabetically, take first 16
mapfile -t wavs < <(find "$SRC" -maxdepth 1 -iname "*.wav" | sort | head -16)

if [ ${#wavs[@]} -eq 0 ]; then
    echo "Error: no .wav files found in '$SRC'"
    exit 1
fi

echo "Installing ${#wavs[@]} samples into Kit $KIT..."
for i in "${!wavs[@]}"; do
    num=$(printf "%02d" $((i + 1)))
    cp "${wavs[$i]}" "$DEST/$num.wav"
    echo "  $num.wav <- $(basename "${wavs[$i]}")"
done

echo ""
echo "Done! Kit $KIT loaded with ${#wavs[@]} samples."
echo "Switch to Kit $KIT in DRUMBANGER to use them."
