# DrumBox16

A 16-pad drum machine plugin for [Reaper](https://www.reaper.fm/), built as a JSFX effect.

Clean UI. Open source drum kits. No bloat.

## Features (v0.1 — Skeleton)

- 16 pads mapped to MIDI notes C1–D#2 (36–51)
- 16-step sequencer with 8 pattern slots
- Per-pad volume, pan, and pitch controls
- Swing control
- Internal stereo mixer
- Host tempo sync
- Digitakt-inspired dark UI

## Install

1. Copy `DrumBox16.jsfx` to `~/.config/REAPER/Effects/DrumBox16/`
2. Copy kit folders to `~/.config/REAPER/Data/DrumBox16/kits/`
3. In Reaper: add FX → JS → DrumBox16

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

## License

GPL-3.0
