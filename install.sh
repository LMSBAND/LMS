#!/bin/bash
# install.sh — Install LMS DRUMBANGER + Drones into REAPER Effects directory
#
# Usage: ./install.sh
#
# Symlinks plugin files and pool/ into ~/.config/REAPER/Effects/DRUMBANGER/
# Edits in the repo are instantly live in REAPER — no re-install needed.
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

# Symlink plugin files (edits in repo are instantly live — no re-install)
for f in "$SCRIPT_DIR"/lms_drumbanger.jsfx \
         "$SCRIPT_DIR"/DrumbangerDroneFX.jsfx \
         "$SCRIPT_DIR"/DrumbangerDroneMIDI2.jsfx; do
    if [ -f "$f" ]; then
        base=$(basename "$f")
        rm -f "$DEST/$base"
        ln -s "$f" "$DEST/$base"
        echo "  Linked $base"
    fi
done
[ -f "$SCRIPT_DIR/NOTICE.TXT" ] && cp "$SCRIPT_DIR/NOTICE.TXT" "$DEST/" && echo "  Copied NOTICE.TXT"

# Symlink pool/ — ONE shared sample library between repo and REAPER
# The JSFX resolves pool/ relative to itself. Symlink ensures the Lua scripts,
# the file manager, and the JSFX all see the same directory.
rm -rf "$DEST/pool"
ln -s "$SCRIPT_DIR/pool" "$DEST/pool"
echo "  Linked pool/ → $SCRIPT_DIR/pool/"

# Clean up legacy kits/ directory (kits are now subfolders inside pool/)
[ -d "$DEST/kits" ] && rm -rf "$DEST/kits" && echo "  Removed legacy kits/ (kits live in pool/ now)"

# Symlink shared DSP kernel (required by all LMS plugins)
# Symlinks mean edits in ~/LMS/ are instantly live in REAPER — no re-install needed
rm -f "$HOME/.config/REAPER/Effects/lms_core.jsfx-inc"
ln -s "$SCRIPT_DIR/lms_core.jsfx-inc" "$HOME/.config/REAPER/Effects/lms_core.jsfx-inc"
echo "  Linked lms_core.jsfx-inc → Effects/"

# Symlink all other JSFX plugins (channel strip, distressor, amp suite, etc.)
for f in "$SCRIPT_DIR"/lms_*.jsfx "$SCRIPT_DIR"/matchering_*.jsfx; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "lms_drumbanger.jsfx" ] && continue  # already linked into DRUMBANGER/
    rm -f "$HOME/.config/REAPER/Effects/$base"
    ln -s "$f" "$HOME/.config/REAPER/Effects/$base"
    echo "  Linked $base → Effects/"
done

# Symlink scripts (git pull updates them instantly — no re-install)
rm -rf "$DEST/scripts"
ln -s "$SCRIPT_DIR/scripts" "$DEST/scripts"
echo "  Linked scripts/ → $SCRIPT_DIR/scripts/"

# Symlink ALL ReaScripts to REAPER Scripts directory (shows up in Action list)
LMS_SCRIPTS_DEST="$HOME/.config/REAPER/Scripts/LMS"
mkdir -p "$LMS_SCRIPTS_DEST"
for f in "$SCRIPT_DIR"/scripts/lms_*.lua "$SCRIPT_DIR"/scripts/drumbanger_*.lua; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    rm -f "$LMS_SCRIPTS_DEST/$base"
    ln -s "$f" "$LMS_SCRIPTS_DEST/$base"
    echo "  Linked $base → Scripts/LMS/"
done

echo ""
echo "Done! Open REAPER and look for DRUMBANGER in the FX browser."
echo ""
echo "DRUMBANGER scripts (search 'DRUMBANGER' in Actions):"
echo "  drumbanger_open_pool.lua  — open pool folder (drop kits here)"
echo "  drumbanger_rescan.lua     — rescan pool after adding samples"
echo "  drumbanger_service.lua    — background service (run this first)"
echo ""
echo "LMS Session scripts (search 'LMS' in Actions):"
echo "  lms_save.lua   — snapshot current session to session.lms"
echo "  lms_load.lua   — restore session.lms into current project"
echo "  lms_steal.lua  — merge another session.lms into current project"
echo ""
echo "Pool folder: $SCRIPT_DIR/pool/"
echo "  Kit folders in pool/ = kits in DrumBanger. Drop WAV folders there."
