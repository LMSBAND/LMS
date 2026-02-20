#!/bin/bash
set -euo pipefail

# ============================================================
# DRUMBANGER Kit Preparation Script
# ============================================================
# Usage:
#   ./prepare_kit.sh synth [kit_name]              — Generate synthetic drum kit (ffmpeg)
#   ./prepare_kit.sh convert <source_folder> [kit_name] — Convert existing samples
#
# Output: ~/.config/REAPER/Effects/DRUMBANGER/pool/<kit_name>/
#
# Subfolders in pool/ become kits in DRUMBANGER.
# First 16 .wav files (alphabetical) per folder map to pads 1-16.
#
# Standard pad mapping:
#   01=Kick, 02=Snare, 03=Rimshot, 04=Clap,
#   05=Closed HH, 06=Open HH, 07=Low Tom, 08=Mid Tom,
#   09=Hi Tom, 10=Crash, 11=Ride, 12=Shaker,
#   13=Perc 1, 14=Perc 2, 15=FX 1, 16=FX 2
# ============================================================

REAPER_EFFECTS="$HOME/.config/REAPER/Effects"
DRUMBOX_DIR="$REAPER_EFFECTS/DRUMBANGER"
POOL_DIR="$DRUMBOX_DIR/pool"

# Pad names for display and file matching
PAD_NAMES=(
  "Kick" "Snare" "Rimshot" "Clap"
  "Closed HH" "Open HH" "Low Tom" "Mid Tom"
  "Hi Tom" "Crash" "Ride" "Shaker"
  "Perc 1" "Perc 2" "FX 1" "FX 2"
)

# Keywords for matching source files to pads (convert mode)
PAD_KEYWORDS=(
  "kick|bd|bassdrum|bass_drum"
  "snare|sn|sd"
  "rim|rimshot|sidestick|side_stick|cross_stick"
  "clap|cp|handclap"
  "closed|chh|cl_hh|hihat_cl|hh_cl|pedal_hh"
  "open|ohh|op_hh|hihat_op|hh_op"
  "low.?tom|tom.?low|tom.?1|floor"
  "mid.?tom|tom.?mid|tom.?2"
  "hi.?tom|tom.?hi|tom.?3|rack"
  "crash|cr"
  "ride|rd"
  "shaker|shake|tambourine|tamb"
  "perc|conga|bongo|block"
  "cowbell|bell|agogo|triangle"
  "fx|clav|click|noise|zap"
  "fx|sweep|reverse|rev|sub"
)

SAMPLE_RATE=48000
FORMAT="pcm_s24le"  # 24-bit WAV

# ============================================================
# Helper functions
# ============================================================

check_ffmpeg() {
  if ! command -v ffmpeg &>/dev/null; then
    echo "ERROR: ffmpeg is required but not found."
    echo "Install with: sudo apt install ffmpeg"
    exit 1
  fi
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

# Convert any audio file to 48kHz 24-bit stereo WAV, normalized
convert_sample() {
  local input="$1"
  local output="$2"
  ffmpeg -y -i "$input" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    -af "loudnorm=I=-16:TP=-1:LRA=11" \
    "$output" 2>/dev/null
}

# ============================================================
# SYNTH MODE — Generate drum sounds with ffmpeg
# ============================================================
# Uses ffmpeg's lavfi audio source with sine/noise generators
# to create usable test samples. Not studio quality, but
# enough to verify the plugin works end to end.

generate_synth_kit() {
  local kit_name="${1:-synth}"
  local out_dir="$POOL_DIR/$kit_name"
  ensure_dir "$out_dir"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  echo "Generating synthetic drum kit: $kit_name"
  echo "Output: $out_dir"
  echo ""

  # 01 — Kick: low sine sweep with exponential decay
  echo "  [01/16] Kick..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=150:duration=0.4,asetrate=48000" \
    -af "aeval='val(0)*exp(-8*t)*sin(2*PI*(150-120*t)*t)':c=stereo,afade=t=out:st=0.05:d=0.35" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/01.wav" 2>/dev/null || \
  ffmpeg -y -f lavfi \
    -i "sine=frequency=80:duration=0.4" \
    -af "afade=t=out:st=0.02:d=0.38" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/01.wav" 2>/dev/null

  # 02 — Snare: noise + sine body
  echo "  [02/16] Snare..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=pink:duration=0.25" \
    -af "highpass=f=1000,afade=t=out:st=0.02:d=0.23,volume=0.7" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/02_noise.wav" 2>/dev/null
  ffmpeg -y -f lavfi \
    -i "sine=frequency=180:duration=0.15" \
    -af "afade=t=out:st=0.01:d=0.14,volume=0.5" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/02_body.wav" 2>/dev/null
  ffmpeg -y -i "$tmpdir/02_noise.wav" -i "$tmpdir/02_body.wav" \
    -filter_complex "amix=inputs=2:duration=longest" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/02.wav" 2>/dev/null

  # 03 — Rimshot: short high sine click
  echo "  [03/16] Rimshot..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=800:duration=0.05" \
    -af "afade=t=out:st=0.005:d=0.045,volume=0.6" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/03.wav" 2>/dev/null

  # 04 — Clap: short noise burst
  echo "  [04/16] Clap..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=white:duration=0.15" \
    -af "highpass=f=800,bandpass=f=1200:width_type=o:w=2,afade=t=in:d=0.005,afade=t=out:st=0.02:d=0.13,volume=0.6" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/04.wav" 2>/dev/null

  # 05 — Closed Hi-Hat: very short high noise
  echo "  [05/16] Closed HH..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=white:duration=0.05" \
    -af "highpass=f=5000,afade=t=out:st=0.005:d=0.045,volume=0.4" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/05.wav" 2>/dev/null

  # 06 — Open Hi-Hat: longer high noise
  echo "  [06/16] Open HH..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=white:duration=0.35" \
    -af "highpass=f=4000,afade=t=out:st=0.05:d=0.3,volume=0.4" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/06.wav" 2>/dev/null

  # 07 — Low Tom: sine 120Hz
  echo "  [07/16] Low Tom..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=120:duration=0.35" \
    -af "afade=t=out:st=0.02:d=0.33,volume=0.7" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/07.wav" 2>/dev/null

  # 08 — Mid Tom: sine 160Hz
  echo "  [08/16] Mid Tom..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=160:duration=0.3" \
    -af "afade=t=out:st=0.02:d=0.28,volume=0.7" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/08.wav" 2>/dev/null

  # 09 — Hi Tom: sine 220Hz
  echo "  [09/16] Hi Tom..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=220:duration=0.25" \
    -af "afade=t=out:st=0.02:d=0.23,volume=0.7" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/09.wav" 2>/dev/null

  # 10 — Crash: long noise, high-passed
  echo "  [10/16] Crash..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=pink:duration=1.5" \
    -af "highpass=f=2000,afade=t=out:st=0.1:d=1.4,volume=0.5" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/10.wav" 2>/dev/null

  # 11 — Ride: medium noise, high-passed
  echo "  [11/16] Ride..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=pink:duration=0.8" \
    -af "highpass=f=3000,afade=t=out:st=0.05:d=0.75,volume=0.4" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/11.wav" 2>/dev/null

  # 12 — Shaker: short noise burst
  echo "  [12/16] Shaker..."
  ffmpeg -y -f lavfi \
    -i "anoisesrc=color=white:duration=0.08" \
    -af "highpass=f=3000,afade=t=out:st=0.01:d=0.07,volume=0.35" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/12.wav" 2>/dev/null

  # 13 — Perc 1 (Wood Block): short high sine
  echo "  [13/16] Perc 1 (Wood Block)..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=600:duration=0.06" \
    -af "afade=t=out:st=0.005:d=0.055,volume=0.5" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/13.wav" 2>/dev/null

  # 14 — Perc 2 (Cowbell): two sines
  echo "  [14/16] Perc 2 (Cowbell)..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=560:duration=0.2" \
    -f lavfi \
    -i "sine=frequency=845:duration=0.2" \
    -filter_complex "amix=inputs=2,afade=t=out:st=0.02:d=0.18,volume=0.5" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/14.wav" 2>/dev/null

  # 15 — FX 1 (Zap): high sine sweep down
  echo "  [15/16] FX 1 (Zap)..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=2000:duration=0.15" \
    -af "vibrato=f=50:d=0.5,afade=t=out:st=0.02:d=0.13,volume=0.4" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/15.wav" 2>/dev/null

  # 16 — FX 2 (Sub Drop): low sine with pitch drop
  echo "  [16/16] FX 2 (Sub Drop)..."
  ffmpeg -y -f lavfi \
    -i "sine=frequency=200:duration=0.5" \
    -af "asetrate=48000*1.5,aresample=48000,afade=t=out:st=0.05:d=0.45,volume=0.5" \
    -ar "$SAMPLE_RATE" -ac 2 -c:a "$FORMAT" \
    "$tmpdir/16.wav" 2>/dev/null

  # Copy to output directory
  echo ""
  echo "Copying to $out_dir..."
  for i in $(seq -w 1 16); do
    if [ -f "$tmpdir/$i.wav" ]; then
      cp "$tmpdir/$i.wav" "$out_dir/$i.wav"
      echo "  $i.wav — ${PAD_NAMES[$((10#$i - 1))]}"
    else
      echo "  WARNING: $i.wav failed to generate"
    fi
  done

  echo ""
  echo "Done! Kit '$kit_name' ready at: $out_dir"
  echo "Samples: $(ls "$out_dir"/*.wav 2>/dev/null | wc -l)/16"
  echo "Run the DRUMBANGER Rescan action in REAPER to detect the new kit."
}

# ============================================================
# CONVERT MODE — Convert existing samples to DRUMBANGER format
# ============================================================

convert_existing_kit() {
  local source_dir="$1"
  local kit_name="${2:-custom}"
  local out_dir="$POOL_DIR/$kit_name"

  if [ ! -d "$source_dir" ]; then
    echo "ERROR: Source directory not found: $source_dir"
    exit 1
  fi

  ensure_dir "$out_dir"
  echo "Converting kit from: $source_dir"
  echo "Output: $out_dir"
  echo ""

  # Collect all audio files from source
  mapfile -t audio_files < <(find "$source_dir" -maxdepth 2 -type f \
    \( -iname "*.wav" -o -iname "*.flac" -o -iname "*.aif" -o -iname "*.aiff" -o -iname "*.ogg" -o -iname "*.mp3" \) \
    | sort)

  if [ ${#audio_files[@]} -eq 0 ]; then
    echo "ERROR: No audio files found in $source_dir"
    exit 1
  fi

  echo "Found ${#audio_files[@]} audio files."
  echo ""

  # Try to match files to pads by keyword
  local matched=0
  for pad_idx in $(seq 0 15); do
    local pad_num
    pad_num=$(printf "%02d" $((pad_idx + 1)))
    local keywords="${PAD_KEYWORDS[$pad_idx]}"
    local pad_name="${PAD_NAMES[$pad_idx]}"
    local found=""

    # Search for keyword match in filenames
    for f in "${audio_files[@]}"; do
      local basename
      basename=$(basename "$f" | tr '[:upper:]' '[:lower:]')
      if echo "$basename" | grep -qiE "$keywords"; then
        found="$f"
        break
      fi
    done

    if [ -n "$found" ]; then
      echo "  $pad_num ($pad_name) ← $(basename "$found")"
      convert_sample "$found" "$out_dir/$pad_num.wav"
      matched=$((matched + 1))
    else
      echo "  $pad_num ($pad_name) — no match found"
    fi
  done

  # If few matches, offer sequential assignment
  if [ "$matched" -lt 8 ]; then
    echo ""
    echo "Only $matched/16 pads matched by keyword."
    echo "Assigning remaining files sequentially..."
    local file_idx=0
    for pad_idx in $(seq 0 15); do
      local pad_num
      pad_num=$(printf "%02d" $((pad_idx + 1)))
      if [ ! -f "$out_dir/$pad_num.wav" ] && [ "$file_idx" -lt "${#audio_files[@]}" ]; then
        local f="${audio_files[$file_idx]}"
        echo "  $pad_num ← $(basename "$f")"
        convert_sample "$f" "$out_dir/$pad_num.wav"
        file_idx=$((file_idx + 1))
      fi
    done
  fi

  echo ""
  echo "Done! Kit '$kit_name' ready at: $out_dir"
  echo "Samples: $(ls "$out_dir"/*.wav 2>/dev/null | wc -l)/16"
  echo "Run the DRUMBANGER Rescan action in REAPER to detect the new kit."
}

# ============================================================
# MAIN
# ============================================================

usage() {
  echo "DRUMBANGER Kit Preparation Script"
  echo ""
  echo "Usage:"
  echo "  $(basename "$0") synth [kit_name]                  Generate synthetic test kit"
  echo "  $(basename "$0") convert <source_folder> [kit_name] Convert existing samples"
  echo ""
  echo "Output: $POOL_DIR/<kit_name>/"
  echo ""
  echo "Kits are subfolders in pool/. Drop a folder of .wav files to add a kit."
  echo ""
  echo "Pad mapping:"
  for i in $(seq 0 15); do
    printf "  %02d  %s\n" $((i + 1)) "${PAD_NAMES[$i]}"
  done
}

check_ffmpeg

case "${1:-}" in
  synth)
    generate_synth_kit "${2:-default}"
    ;;
  convert)
    if [ -z "${2:-}" ]; then
      echo "ERROR: source folder required"
      echo "Usage: $(basename "$0") convert <source_folder> [kit_name]"
      exit 1
    fi
    convert_existing_kit "$2" "${3:-custom}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
