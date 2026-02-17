#!/bin/bash
# scan_pool.sh — Scan pool AND kits, generate manifests for DrumBanger
#
# Usage: ./scan_pool.sh [base_dir]
#   Default base: ~/.config/REAPER/Effects/DrumBox16
#
# Generates:
#   pool/manifest.txt  — flat list of pool samples
#   kits/manifest.txt  — kit definitions (folder name + sample paths)
#
# For kits: drop ANY folder of .wav files into kits/ — no renaming needed!
# First 16 .wav files (alphabetical) map to pads 1-16.

set -e

BASE_DIR="${1:-$HOME/.config/REAPER/Effects/DrumBox16}"
POOL_DIR="$BASE_DIR/pool"
KITS_DIR="$BASE_DIR/kits"

# ---- Pool scan ----
if [ -d "$POOL_DIR" ]; then
    cd "$POOL_DIR"
    find . -iname "*.wav" | sed 's|^\./||' | sort > manifest.txt
    POOL_COUNT=$(wc -l < manifest.txt)
    echo "Pool: $POOL_COUNT samples"
else
    echo "Pool: directory not found ($POOL_DIR), skipping"
fi

# ---- Kit scan ----
if [ -d "$KITS_DIR" ]; then
    KIT_MANIFEST="$KITS_DIR/manifest.txt"
    > "$KIT_MANIFEST"

    KIT_COUNT=0
    for dir in "$KITS_DIR"/*/; do
        [ -d "$dir" ] || continue
        dirname=$(basename "$dir")

        # Find wav files in this folder, sorted alphabetically, first 16
        wavs=()
        while IFS= read -r f; do
            wavs+=("$f")
        done < <(find "$dir" -maxdepth 1 -iname "*.wav" -printf "%f\n" | sort | head -16)

        [ ${#wavs[@]} -eq 0 ] && continue

        # Write kit block
        echo "---" >> "$KIT_MANIFEST"
        echo "$dirname" >> "$KIT_MANIFEST"
        for wav in "${wavs[@]}"; do
            echo "$dirname/$wav" >> "$KIT_MANIFEST"
        done

        KIT_COUNT=$((KIT_COUNT + 1))
        echo "  Kit '$dirname': ${#wavs[@]} samples"

        [ $KIT_COUNT -ge 8 ] && break
    done

    echo "Kits: $KIT_COUNT found"
else
    echo "Kits: directory not found ($KITS_DIR), skipping"
fi

echo "Done. Reload JSFX in REAPER or run Rescan action."
