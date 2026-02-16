# Drumbanger gmem[] Broadcast — Slot Map

## Namespace

All LMS plugins share: `options:gmem=DrumBanger`

## gmem[] Memory Map

### Sampling Service (gmem[0-9]) — Lua ReaScript ↔ JSFX

```
gmem[0]  = rescan pool signal (Lua → JSFX, 1 = rescan)
gmem[1]  = new sample pool index (Lua → JSFX)
gmem[2]  = auto-load flag (Lua → JSFX, 1 = load onto selected pad)
gmem[3]  = sample request (JSFX → Lua, 1 = please sample)
gmem[4]  = target pad for sampling (JSFX → Lua, 0-15)
gmem[5]  = service status (Lua → JSFX, 0=idle, 1=sampling, 2=done, 3=error)
gmem[6]  = service heartbeat (Lua → JSFX, increments each frame)
gmem[7-9] = reserved
```

### Drone Broadcast (gmem[10-19]) — Drumbanger → DrumbangerDrone

```
gmem[10] = heartbeat (increments every @block — Drones detect connection)
gmem[11] = current step (0-63)
gmem[12] = steps_per_measure
gmem[13] = current pattern (0-7)
gmem[14] = BPM
gmem[15] = transport_playing (0 or 1)
gmem[16] = seq_mode (0 or 1)
gmem[17] = measure_num
gmem[18-19] = reserved
```

### Per-Pad Data (gmem[100+]) — Drumbanger → DrumbangerDrone

```
gmem[100+p]  = trigger flag (velocity on hit, Drone reads & clears)
gmem[120+p]  = pad is currently playing (1/0)
```

### Step Data (gmem[200+]) — Drumbanger → DrumbangerDrone

```
gmem[200 + step*16 + pad] = step velocity (0-127) for current pattern
                             (256 slots: 16 steps × 16 pads)
```

### Future: MIDI Note Sequence (gmem[500+])

```
gmem[500 + step*16 + pad] = MIDI note (0-127, 0 = rest)
                             For drone MIDI sequencer mode
```

### Future: Pad Mode Flags (gmem[800+])

```
gmem[800+p]  = pad mode (0 = drum sample, 1 = drone/MIDI output)
```

## Notes

- `options:gmem=DrumBanger` is set at the top of both JSFX files
- gmem[] is global across ALL JSFX instances with the same namespace
- Reads/writes are atomic at the sample level — no locks needed
- Zero additional CPU cost (just memory writes)
- Drones poll gmem[] in their own @block, same audio block = same timing
