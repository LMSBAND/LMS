#!/bin/bash
# install.sh — Install LMS DRUMBANGER + Drones into REAPER Effects directory
#
# Usage: ./install.sh
#
# Copies all plugin files, scripts, kits, and pool into
# ~/.config/REAPER/Effects/DRUMBANGER/
# Run this after cloning or pulling the repo.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/REAPER/Effects/DRUMBANGER"

echo "Installing LMS DRUMBANGER suite..."
echo "  From: $SCRIPT_DIR"
echo "  To:   $DEST"
echo ""

# Create destination
mkdir -p "$DEST"
mkdir -p "$DEST/scripts"
mkdir -p "$DEST/kits"
mkdir -p "$DEST/pool"

# Copy plugin files
for f in "$SCRIPT_DIR"/lms_drumbanger.jsfx \
         "$SCRIPT_DIR"/DrumbangerDroneFX.jsfx \
         "$SCRIPT_DIR"/DrumbangerDroneMIDI2.jsfx \
         "$SCRIPT_DIR"/NOTICE.TXT; do
    if [ -f "$f" ]; then
        cp "$f" "$DEST/"
        echo "  Copied $(basename "$f")"
    fi
done

# Copy all other JSFX plugins (channel strip, distressor, etc.)
for f in "$SCRIPT_DIR"/lms_*.jsfx "$SCRIPT_DIR"/matchering_*.jsfx; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "lms_drumbanger.jsfx" ] && continue  # already copied above
    cp "$f" "$HOME/.config/REAPER/Effects/$base"
    echo "  Copied $base → Effects/"
done

# Copy service/rescan scripts (all scripts → DRUMBANGER/scripts/)
for f in "$SCRIPT_DIR"/scripts/*; do
    if [ -f "$f" ]; then
        cp "$f" "$DEST/scripts/"
        echo "  Copied scripts/$(basename "$f")"
    fi
done

# Copy LMS ReaScripts to REAPER Scripts directory (shows up in Action list)
LMS_SCRIPTS_DEST="$HOME/.config/REAPER/Scripts/LMS"
mkdir -p "$LMS_SCRIPTS_DEST"
for f in "$SCRIPT_DIR"/scripts/lms_*.lua; do
    [ -f "$f" ] || continue
    cp "$f" "$LMS_SCRIPTS_DEST/"
    echo "  Copied $(basename "$f") → Scripts/LMS/"
done

# Copy kits (only if they exist and have content)
if [ -d "$SCRIPT_DIR/kits" ]; then
    cp -r "$SCRIPT_DIR/kits/"* "$DEST/kits/" 2>/dev/null && \
        echo "  Copied kits/" || echo "  No kits to copy (add your own!)"
fi

echo ""
echo "Done! Open REAPER and look for DRUMBANGER in the FX browser."
echo ""
echo "IMPORTANT: You must run drumbanger_service.lua as a background ReaScript"
echo "for the sample pool browser to work:"
echo "  Actions → Run ReaScript → $DEST/scripts/drumbanger_service.lua"
echo ""
echo "LMS Session scripts installed to: $LMS_SCRIPTS_DEST"
echo "  In REAPER: Actions → Show action list → search 'LMS' to find:"
echo "    lms_save.lua   — snapshot current session to session.lms"
echo "    lms_load.lua   — restore session.lms into current project"
echo "    lms_steal.lua  — merge another session.lms into current project"
