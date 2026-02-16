# DrumbangerDrone — Claude Code Development Plan

## What Is This?
A satellite JSFX plugin that connects to LMS Drumbanger via gmem[] shared memory.
Place it on any track to receive triggers, patterns, and sequencing data from Drumbanger.
Turns Drumbanger from a drum machine into a full-project performance sequencer.

## Architecture

```
 Track 1: Drumbanger (brain)
   writes to gmem[] ──────────┬─────────────┬──────────────┐
                              │             │              │
 Track 2: Drone → Synth    Track 3: Drone → Bass    Track 4: Drone → Pad
   reads gmem[pad 13]       reads gmem[pad 14]      reads gmem[pad 15]
   mode: MIDI Seq           mode: MIDI Seq           mode: Sidechain
   outputs MIDI notes       outputs MIDI notes       ducks on kick
   HP filter sweep          delay + flanger          gate effect
```

All Drones read from the same gmem[] namespace ("LMS_Drumbanger").
Pattern changes in Drumbanger propagate to ALL Drones instantly.
Zero routing setup. Zero bus config. Just drop and select a pad.

## gmem[] Protocol
See DRUMBANGER_GMEM_PATCH.md for the full memory map.

## Current State (v0.1.0 — Skeleton)

Working:
- [x] gmem_attach and heartbeat detection
- [x] Connection status display
- [x] Pad trigger reading from gmem[]
- [x] MIDI Sequencer mode (reads note data, fires MIDI)
- [x] Trigger mode (single note per pad hit)
- [x] Sidechain mode (envelope follower, duck on trigger)
- [x] Gate mode (hard/soft gate on pad activity)
- [x] Biquad LP/HP filter with cutoff and Q
- [x] Tempo-synced flanger with feedback
- [x] Tempo-synced delay (mono + ping pong) with LP feedback
- [x] Step grid mirror showing Drumbanger's pattern
- [x] Output gain + dry/wet
- [x] Status bar with BPM/step/pattern from Drumbanger

Not yet:
- [ ] Note entry UI for MIDI Seq mode (currently uses gmem note data or fallback)
- [ ] Per-step filter automation from Drumbanger
- [ ] FX parameter sliders in GFX (currently slider-only)
- [ ] Preset system
- [ ] Multiple Drumbanger instance support (currently assumes one)

## Development Phases

### Phase 1: Wire Up gmem[] in Drumbanger
Add gmem_attach("LMS_Drumbanger") and the broadcast code to Drumbanger.
See DRUMBANGER_GMEM_PATCH.md for exact code.

**Claude Code prompt:**
> "Read DRUMBANGER_GMEM_PATCH.md and apply those changes to the Drumbanger
> JSFX file. Add gmem_attach in @init, broadcast state in @block, and mirror
> pattern data to gmem[]. Test that gmem[0] heartbeat increments."

### Phase 2: Drone MIDI Sequencer with Note Entry
Add note programming UI so users can enter melodies per step directly
in Drumbanger's grid when a pad is flagged as "drone output."

**Claude Code prompt:**
> "In Drumbanger's @gfx, when a pad is flagged as drone mode (gmem[800+pad]=1),
> change the step sequencer to show MIDI note names instead of velocity bars.
> Right-click a step to open a note picker. Store notes in gmem[500+step*16+pad].
> In DrumbangerDrone, read these notes in MIDI Seq mode and fire them."

### Phase 3: Interactive FX Controls in Drone GFX
Add draggable bars for filter, flanger, delay in the Drone UI.
Same style as Drumbanger's vol/pan/pitch controls.

### Phase 4: Per-Step FX Modulation
Let Drumbanger's step grid store filter cutoff values per step.
Drone reads them and sweeps the filter automatically.
This is the EDM performance feature — build a filter sweep right in the grid.

### Phase 5: Multiple Drone Behaviors
- Envelope follower → modulates filter cutoff based on pad dynamics
- Retrigger → chops and restarts audio on the track
- Probability → only fires X% of the time
- Swing offset → Drone can have independent swing from Drumbanger

### Phase 6: Preset Sharing
Save/load Drone configurations. FX chains as presets.
"EDM Sidechain," "Dub Delay," "Filter Sweep," etc.

## Testing Checklist
- [ ] Drumbanger gmem[] heartbeat incrementing
- [ ] Drone detects Drumbanger (LINKED status)
- [ ] Drone loses connection when Drumbanger removed (NO SIGNAL)
- [ ] MIDI Seq mode fires notes to downstream synth
- [ ] Sidechain ducks audio in time with pad triggers
- [ ] Gate passes/blocks audio correctly
- [ ] Filter sweeps without clicks or zipper noise
- [ ] Flanger sounds correct at various rates
- [ ] Delay stays in tempo when BPM changes
- [ ] Ping pong delay produces stereo spread
- [ ] Pattern changes in Drumbanger reflected in all Drones
- [ ] No stuck MIDI notes on transport stop
- [ ] CPU usage acceptable with 4+ Drones active
