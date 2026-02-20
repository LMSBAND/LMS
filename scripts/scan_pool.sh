#!/bin/bash
# scan_pool.sh — Scan pool folder, generate manifest for DrumBanger
#
# Usage: ./scan_pool.sh [base_dir]
#   Default base: ~/.config/REAPER/Effects/DRUMBANGER
#
# Generates:
#   pool/manifest.txt  — flat list of pool samples (including subfolders)
#
# Subfolders in pool/ become kits. Drop a folder of .wav files to add a kit.
# First 16 .wav files (alphabetical) per folder map to pads 1-16.

set -e

BASE_DIR="${1:-$HOME/.config/REAPER/Effects/DRUMBANGER}"
POOL_DIR="$BASE_DIR/pool"

# ---- Pool scan (includes subfolders = kits) ----
if [ -d "$POOL_DIR" ]; then
    cd "$POOL_DIR"
    find . -iname "*.wav" | sed 's|^\./||' | sort > manifest.txt
    POOL_COUNT=$(wc -l < manifest.txt)

    # Count subfolders (= kits)
    KIT_COUNT=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)

    echo "Pool: $POOL_COUNT samples, $KIT_COUNT kits (folders)"
else
    echo "Pool: directory not found ($POOL_DIR)"
    echo "  Create it and drop .wav files there for loose samples."
    echo "  Drop a FOLDER of .wav files to create a kit."
    mkdir -p "$POOL_DIR"
    echo "  Created: $POOL_DIR"
fi

echo "Done. Reload JSFX in REAPER or run Rescan action."
