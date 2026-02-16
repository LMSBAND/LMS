# DrumBox16

A 16-pad drum machine plugin for [Reaper](https://www.reaper.fm/), built as a JSFX effect.

Clean UI. Open source. No bloat. No subscriptions. No iLok.

## Features

- 16 pads mapped to MIDI notes C1-D#2 (36-51)
- 16-step sequencer with 8 pattern slots
- Multi-bar patterns (up to 4 bars / 64 steps per pattern)
- Per-pad 1x/2x/4x step subdivision
- Per-step velocity (right-click any step to set velocity)
- MIDI recording with sub-step quantization
- Per-pad volume, pan, pitch, LP/HP filter controls
- Per-step filter parameter locks
- Output bus LP/HP filters (automatable)
- Swing, saturation, LA-2A style optical compressor
- Sample pool with subfolder organization and folder dropdown
- Pattern clear and duplicate buttons
- Kit system with hot-swappable sample loading
- Host tempo sync
- Digitakt-inspired dark UI
- Save/load with backward compatibility

## Install

1. Copy `DrumBox16.jsfx` to `~/.config/REAPER/Effects/DrumBox16/`
2. In Reaper: add FX > JS > DrumBox16

## Loading Samples

DrumBox16 loads samples from a **pool folder**:

```
~/.config/REAPER/Effects/DrumBox16/pool/
```

### Method 1: Drop files in the pool folder

1. Copy your `.wav` files into the pool folder above
2. Organize with subfolders if you want (e.g. `pool/kicks/`, `pool/snares/`)
3. Run the scan script to rebuild the manifest:
   ```
   ./scripts/scan_pool.sh
   ```
4. In the plugin, use the `<` `>` buttons to browse the pool
5. Use the folder dropdown to filter by subfolder

### Method 2: Use the ReaScript loader

1. In Reaper: Actions > Show Action List > New Action > Load ReaScript
2. Load `scripts/drumbanger_load.lua`
3. Assign a keyboard shortcut
4. Select a pad in DrumBox16, run the action — it opens a file picker, copies the wav into the pool, and loads it onto the selected pad automatically

### Method 3: Export from Reaper arrangement

1. Select audio in the arrange view
2. File > Render (or glue the item)
3. Save the rendered wav into the pool folder
4. Run `./scripts/scan_pool.sh` to update the manifest

## Sequencer

- **Left-click** a step to toggle it on/off
- **Right-click** a step to open the velocity editor (drag to set 0-127)
- **1x/2x/4x** buttons set step subdivision per pad
- **Bar buttons (1-4)**: left-click to navigate/extend bars, right-click to shrink
- **CLR PAT** clears the current pattern (all pads, all bars)
- **DUP** duplicates the current pattern to the next empty slot
- **Fill buttons** (1, 1/2, 1/4) fill the current bar
- **Nudge** (<< >>) shifts the pattern left/right within the current bar
- MIDI input is recorded and quantized to the current subdivision

## Kit Format

Each kit is a folder containing `01.wav` through `16.wav`:

| Pad | Default Mapping |
|-----|----------------|
| 01  | Kick           |
| 02  | Snare          |
| 03  | Rimshot        |
| 04  | Clap           |
| 05  | Closed Hi-Hat  |
| 06  | Open Hi-Hat    |
| 07  | Low Tom        |
| 08  | Mid Tom        |
| 09  | Hi Tom         |
| 10  | Crash          |
| 11  | Ride           |
| 12  | Shaker         |
| 13  | Perc 1         |
| 14  | Perc 2         |
| 15  | FX 1           |
| 16  | FX 2           |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/scan_pool.sh` | Scan pool folder, generate manifest.txt |
| `scripts/drumbanger_load.lua` | ReaScript: file picker to load sample onto selected pad |
| `scripts/drumbanger_rescan.lua` | ReaScript: trigger pool rescan from within Reaper |
| `scripts/install_kit.sh` | Install a kit folder into the kits directory |
| `scripts/prepare_kit.sh` | Prepare a folder of wavs as a numbered kit |

## Roadmap

- Choke groups — assign pads to choke lanes so triggering one cuts another (e.g. open/closed hi-hat)
- Improved sample chop mechanism — more accurate slicing with visual waveform editing
- Synth integration — built-in synthesis engine for layering with samples
- Sidechain outputs — per-pad or bus sidechain sends for ducking/pumping other tracks

## License

GPL-3.0
