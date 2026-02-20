#!/bin/bash
# install_kit.sh — Install a folder of wav files as a DRUMBANGER kit
#
# Usage:  ./install_kit.sh <source_folder> [kit_name]
# Example: ./install_kit.sh ~/Downloads/808_samples My808Kit
#
# Copies wav files from the source folder into pool/<kit_name>/.
# Subfolders in pool/ become kits in DRUMBANGER.
# Run the Rescan action in REAPER after installing.

set -e

POOL_DIR="$HOME/.config/REAPER/Effects/DRUMBANGER/pool"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <source_folder> [kit_name]"
    echo ""
    echo "Example: $0 ~/Downloads/808_kit My808Kit"
    echo "  → Copies wav files into pool/My808Kit/"
    echo ""
    echo "Current kits (pool subfolders):"
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

SRC="$1"
KIT_NAME="${2:-$(basename "$SRC")}"

if [ ! -d "$SRC" ]; then
    echo "Error: '$SRC' is not a directory"
    exit 1
fi

DEST="$POOL_DIR/$KIT_NAME"
mkdir -p "$DEST"

# Find wav files (case-insensitive), sorted alphabetically
mapfile -t wavs < <(find "$SRC" -maxdepth 1 -iname "*.wav" | sort)

if [ ${#wavs[@]} -eq 0 ]; then
    echo "Error: no .wav files found in '$SRC'"
    exit 1
fi

echo "Installing ${#wavs[@]} samples into pool/$KIT_NAME/..."
for wav in "${wavs[@]}"; do
    cp "$wav" "$DEST/"
    echo "  $(basename "$wav")"
done

echo ""
echo "Done! Kit '$KIT_NAME' installed with ${#wavs[@]} samples."
echo "Run the DRUMBANGER Rescan action in REAPER to detect the new kit."
