# LMS Plugin Suite — User Guide

Free, open-source JSFX plugins for REAPER. No subscriptions. No iLok.

---

## Installation

### ReaPack (Recommended)
1. Install [ReaPack](https://reapack.com)
2. Add this repository URL: `https://raw.githubusercontent.com/LMSBAND/LMS/master/index.xml`
3. Synchronize. All plugins install automatically.

### Linux / macOS (install.sh)
1. Clone the repo: `git clone https://github.com/LMSBAND/LMS.git`
2. `cd LMS && chmod +x install.sh && ./install.sh`
3. The script creates symbolic links into `~/.config/REAPER/Effects/` — edits in the repo are instantly live in REAPER.
4. REAPER → Options → Preferences → Plug-ins → JS → Re-scan

### Windows (install.bat)
1. Download or clone the repo
2. Run `install.bat`
3. The script copies all plugins, pool, and scripts into `%APPDATA%\REAPER\Effects\`
4. REAPER → Options → Preferences → Plug-ins → JS → Re-scan

### Manual (Windows)
1. Open `%APPDATA%\REAPER\Effects\`
2. Copy `lms_core.jsfx-inc` first (required by everything)
3. Copy all `lms_*.jsfx` and `Drumbanger*.jsfx` files
4. Copy the `pool/` folder into a `DRUMBANGER/` subfolder
5. Copy the `scripts/` folder
6. REAPER → Options → Preferences → Plug-ins → JS → Re-scan

### Manual (Linux)
1. Copy everything to `~/.config/REAPER/Effects/`
2. Re-scan in REAPER

---

## Density-Aware Amp Sims

All amp sims share a density-aware architecture: a 4-band density tracker (Lo/Mid/Hi/Air) analyzes your playing dynamics in real time and modulates internal parameters like Miller capacitance, air shelf, drive boost, and feedback bandwidth. The harder you play, the more the amp responds — not just with more clipping, but with tonal changes that mirror how real tube amps behave under load.

Every amp sim includes a full GUI, broadcast system (instance manager with follow/steal), 4K/HiDPI scaling, and dual cabinet simulation.

### Cabinet Simulation (All Amps)

Every amp sim includes integrated dual-cab simulation with impedance modeling.

| Control | What It Does |
|---------|-------------|
| Cabinet | Primary cab: Off, 1x12 Greenback, 1x12 Jensen, 1x12 Blue, 2x12 Jensen, 4x12 G12T-75, 4x12 V30, 8x10 Sealed, 4x12 Sheffield, 1x15 Open, 4x10 Sealed, Orange PPC412 |
| Cab Sim | On/Off |
| Mic Distance | Primary mic position (0–100%) |
| Cabinet B | Second cab selection (same options) for dual-cab blending |
| Mic B Distance | Second mic position (0–100%) |
| Impedance Tap | 4 ohm / 8 ohm / 16 ohm — electrical load on the output transformer |

**Tips:**
- Dual-cab blending (e.g. 4x12 V30 + 1x12 Greenback) creates wider, more complex tones
- Impedance tap changes feel — lower impedance = tighter, higher = saggier
- Mic Distance at 0% = close-mic punch; 100% = room ambience

---

### The Twins v2 — Fender Twin Reverb / Deluxe Reverb

Two amps in one. The Twin is a clean 85W powerhouse; the Deluxe is a 22W breakup machine.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Twin Reverb 85W / Deluxe Reverb 22W |
| Bass / Mid / Treble | Fender tone stack |
| Presence | High-frequency emphasis post-power amp |
| Master | Power amp drive |
| Input Stage | Coupling cap / cathode follower intensity |
| PSU Sag | Power supply droop under load |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + feedback)

**Tips:**
- Twin channel stays clean at high volumes — use it for pedal platform tones
- Deluxe channel breaks up earlier and has more midrange push
- Crank the Master with low Gain for power amp saturation

---

### The Frenchie v2 — Fender Champ 5F1

The simplest amp in the suite. One knob of gain, one knob of tone. Sounds huge.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Single volume knob (like the real Champ) |
| Tone | Low-pass sweep |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed)

**Tips:**
- Gain at 70%+ is where the magic happens — spongy, compressed breakup
- PSU Sag adds that "amp struggling" feel on big chords

---

### The Frenchie v3 — Full Hog (Density-Aware Champ)

Everything the v2 does, plus transformer hysteresis modeling. The output transformer remembers what you just played — previous notes bias the saturation of the next note through persistent magnetic state.

Same controls as v2. The difference is under the hood:
- B-H curve hysteresis with remanence and coercivity
- Asymmetric magnetization from single-ended DC bias
- Dynamic Miller capacitance (6.5–9.5 kHz sweep based on harmonic density)
- Grid conduction modeling with peak envelope tracking
- No negative feedback (like the real Champ)

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed)

**Tips:**
- Play softly then dig in — the hysteresis makes dynamics feel alive in a way the v2 doesn't
- This is the "recording" Champ. Use v2 for live/low-CPU situations

---

### Punk Idol v2 — Marshall JCM800

Three channels of British aggression.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Clean / Crunch / Lead |
| Bass / Mid / Treble | Marshall tone stack |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + time + feedback)

**Tips:**
- Crunch channel with Gain at 60% is the classic punk/rock tone
- Lead channel is high-gain — roll back the guitar volume for cleans that still have bite
- Mid controls the cut. Scoop it for metal, boost it for punk

---

### The Fridge v2 — Ampeg SVT Bass Amp

The bass amp. SVT tone stack with selectable mid frequency and the Crushinator parallel distortion circuit.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Bass / Mid / Treble | SVT tone stack |
| Mid Freq | 220 Hz / 450 Hz / 800 Hz / 1.6 kHz / 3 kHz |
| Ultra Lo / Ultra Hi | Boost switches |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Crushinator** (SansAmp-style parallel distortion):

| Control | What It Does |
|---------|-------------|
| Crushinator | On/Off |
| Crush Drive | Distortion amount |
| Crush Blend | Parallel mix (clean + dirty) |
| Crush Presence | High-frequency edge |
| Crush Low / High | Tone shaping |

**Built-in Effects:** Tape Echo (mix + time + feedback)

**Tips:**
- Crushinator Blend at 30-40% adds grit without losing low-end definition
- Mid Freq at 800 Hz scooped = classic metal bass. 450 Hz boosted = Motown thump
- Ultra Lo + Ultra Hi together is the "SVT full send" tone

---

### TOMASTEKNIK v2 — SVT + ODB-3 Bass

Tribute amp inspired by Tomas Näslund's bass tone on Blindside's *A Thought Crushed My Mind* (1999, Tonteknik Studios, Umeå). SVT engine with a built-in Boss ODB-3 Bass Overdrive and LA-2A opto compressor — the entire Swedish hardcore bass rig in one plugin.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Bass / Mid / Treble | SVT tone stack |
| Mid Freq | 220 Hz / 450 Hz / 800 Hz / 1.6 kHz / 3 kHz |
| Ultra Lo / Ultra Hi | Boost switches |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**ODB-3** (Boss ODB-3 Bass Overdrive):

| Control | What It Does |
|---------|-------------|
| ODB-3 | On/Off |
| ODB Drive | Distortion amount |
| ODB Blend | Parallel mix (clean + dirty) |
| ODB Low / High | Tone shaping on dirty signal |

**Compressor** (LA-2A Opto — final in chain, post-cab):

| Control | What It Does |
|---------|-------------|
| LA-2A | On/Off (with GR meter) |
| Peak Reduction | How much compression |
| Comp Gain | Makeup gain (dB) |
| Comp Mode | Compress (gentler) / Limit (harder knee) |
| Emphasis | High-frequency sidechain sensitivity |
| Comp Mix | Parallel blend (0–100%) |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + time + feedback)

**Tips:**
- ODB Blend at 40-70% is the sweet spot — bass fundamentals stay clean while mids/highs get grit
- The ODB-3's 300Hz HPF means bass never gets muddy even at max drive
- Turn on the LA-2A with Peak Reduction at 50% and Mix at 100% for that glued studio bass tone
- Default cab is 4x12 V30 (the Tonteknik vibe) — try 8x10 Sealed for classic SVT thunder
- Crank Master with Gain at 50% for output transformer growl

---

### Top Boost v2 — Vox AC15

Two channels: Normal (darker, thicker) and Top Boost (brighter, chimey).

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Normal / Top Boost |
| Bass / Treble | Vox tone stack |
| Tone Cut | High-frequency roll-off (like the real AC15 cut knob) |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Tremolo (bias wobble on EL84s — depth + speed), Spring Reverb

**Tips:**
- Top Boost channel is the classic jangly Vox tone
- Tone Cut at 40-60% tames harshness at high gain without losing presence
- The tremolo is a bias tremolo — it wobbles the power tubes, not just the volume

---

### The TRSOB v2 — Mesa Triple Rectifier

Three channels of high-gain American brutality with selectable rectifier type.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Clean / Vintage / Modern |
| Bass / Mid / Treble | Mesa tone stack |
| Presence | High-frequency emphasis |
| Master | Power amp drive |
| Rectifier | Silicon (tight) / Tube (saggy) |
| Bold/Spongy | Power amp feel |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |
| Noise Gate | Built-in gate on/off |

**Built-in Effects:** Tape Echo (mix + time + feedback)

**Tips:**
- Modern channel + Silicon rectifier + Bold = tightest high-gain tone
- Vintage channel + Tube rectifier + Spongy = classic rock crunch with sag
- The built-in noise gate is basic — use Smart Gate for serious gating

---

### Area 50/51 v2 — Cold-Bias 6L6 High-Gain

High-gain amp with cold-biased 6L6 power tubes. Two channels and a resonance control for low-end tightness.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Pre Gain | Preamp drive |
| Channel | Clean / Lead |
| Low / Mid / High | Tone stack |
| Post Gain | Post-EQ gain |
| Presence | High-frequency emphasis |
| Resonance | Low-frequency depth |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |
| Noise Gate | Built-in gate on/off |

**Built-in Effects:** Tape Echo (mix + time + feedback)

**Tips:**
- Lead channel is where the gain lives — tight, aggressive, and articulate
- Resonance controls the low-end thump. Higher = heavier, lower = tighter
- Presence + Resonance together shape the power amp voicing more than any EQ

---

### OJ 99 v2 — Orange OR100 Rockerverb

British voiced Orange with Clean and Dirty channels.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Clean / Dirty |
| Bass / Mid / Treble | Orange tone stack |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + time + feedback)

**Tips:**
- Dirty channel has a thick, woolly midrange — very different from the Marshall or Mesa
- Clean channel with Gain at 40% does "edge of breakup" beautifully
- Default cab is Orange PPC412 — try it, that's what the amp was made for

---

### The Basswoman v2 — Fender Bassman

Density-aware Bassman with Normal and Bright channels. Works for bass and guitar.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Normal / Bright |
| Bass / Mid / Treble | Bassman tone stack |
| Presence | High-frequency emphasis |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + feedback)

**Tips:**
- The original "bass" amp that guitarists stole — great on both
- Bright channel with Gain at 50% is the classic blues-rock overdrive
- Normal channel keeps the low end intact for actual bass duties

---

### The Fucking Nightmare v2 — Orange Terror Bass

Two-channel Orange bass amp: Warm for clean low-end and Aggressive for driven tones.

| Control | What It Does |
|---------|-------------|
| Input Level | Input gain in dB |
| Gain | Preamp drive |
| Channel | Warm / Aggressive |
| Bass / Mid / Treble | Orange tone stack |
| Master | Power amp drive |
| Input Stage | Coupling cap intensity |
| PSU Sag | Power supply droop |
| Output Level | Final output in dB |
| FX Bypass | Bypasses built-in effects |

**Built-in Effects:** Spring Reverb, Tremolo (depth + speed), Tape Echo (mix + time + feedback)

**Tips:**
- Aggressive channel is mean — use it for distorted bass tones
- Warm channel with Master cranked gets a natural power amp growl
- Pairs well with The Fridge's Crushinator for layered bass distortion

---

## Dynamics

---

### LMS RTW — Channel Strip (Reinvents The Wheel)

Full channel strip: preamp saturation, 4-band parametric EQ, compressor, and output gain.

| Section | Controls |
|---------|----------|
| Preamp | Drive (dB), Saturation Mode (Clean / Warm / Hot) |
| HPF | On/Off, Frequency (20–500 Hz) |
| EQ | Low Shelf (dB + freq), Low-Mid (dB + freq + Q), Hi-Mid (dB + freq + Q), High Shelf (dB + freq) |
| Compressor | On/Off, Threshold, Ratio (2:1 / 4:1 / 6:1 / 10:1), Attack, Release |
| Output | Gain (dB) |

**Broadcast System:** Instances can follow each other. Set one as LEADER and all FOLLOWERs mirror its settings in real time. Use the instance panel at the bottom to manage.

**Tips:**
- Put this on every track. It's your bread and butter.
- Warm saturation mode adds subtle harmonics. Hot is more aggressive.
- The broadcast follow system means you can EQ one guitar and have the other guitar match instantly.

---

### Density Maximizer — Brick-Wall Limiter

Predictive mastering limiter with auto-makeup gain and opto pre-limiting.

| Control | What It Does |
|---------|-------------|
| Input Gain | Drive into the limiter |
| Ceiling | Maximum output level (dBFS) |
| Target Loudness | How loud the auto-makeup aims for (dB) |
| Release | Limiter release time (ms) |
| Gain Reduction | Read-only GR meter |
| Opto Pre-Limit | Gentle opto compression before the brick wall (0–100%) |
| EQ Profile | Off / Clean / Loud / Open |
| EQ Intensity | How much the EQ profile is applied (0–200%) |

**Tips:**
- Opto Pre-Limit at 30-50% catches peaks gently before they hit the wall — more transparent limiting
- "Loud" EQ profile boosts perceived loudness without extra gain
- Start with Ceiling at -0.3 dBFS, Target Loudness at 0, then raise Target until it sounds right
- Use on master bus only

---

### Kitty Kats Big Krush — Compressor/Distortion

FET compressor inspired by the Empirical Labs Distressor. Ratio goes up to NUKE.

| Control | What It Does |
|---------|-------------|
| Input | Input gain (dB) |
| Threshold | Compression threshold (dB) |
| Ratio | 1:1, 2:1, 3:1, 4:1, 6:1, 10:1, 20:1, Nuke |
| Attack | Attack time (ms) |
| Release | Release time (ms) |
| Distortion Mode | Off / Dist 2 (Tape) / Dist 3 (Tube) |
| HP Sidechain | On/Off — prevents bass from triggering compression |
| HP SC Freq | Sidechain high-pass frequency |
| Output | Output gain (dB) |
| Mix | Parallel compression blend (0–100%) |

**Tips:**
- NUKE ratio is infinite:1 — it's a brick wall with character
- Dist 2 (Tape) adds warmth. Dist 3 (Tube) adds edge.
- HP Sidechain on + 150 Hz = stops kick drum from pumping the mix
- Mix at 40-60% for parallel "New York style" compression on drums

---

### Silver Sixty Nine — Opto Compressor

Density-aware optical compressor inspired by the LA-2A. Program-dependent attack and release.

| Control | What It Does |
|---------|-------------|
| Input Gain | Input level (dB) |
| Peak Reduction | How much compression (like the LA-2A knob) |
| Gain | Makeup gain (dB) |
| Mode | Compress (gentler) / Limit (harder knee) |
| Emphasis | High-frequency sensitivity (like the LA-2A emphasis control) |
| Mix | Parallel blend (0–100%) |
| Warmth | Tube-style harmonic saturation |

**Tips:**
- This compressor is slow and musical — use it on vocals, bass, and bus groups
- Emphasis at 50% keeps sibilance from triggering over-compression on vocals
- Warmth adds even harmonics — subtle at 20%, obvious at 60%+

---

### Smart Gate — Density-Aware Noise Gate

Two modes: Single (per-track gating) and Drum (cross-mic spatial intelligence with phase correction).

| Control | What It Does |
|---------|-------------|
| Input Gain | Input level (dB) |
| Mode | Single / Drum |
| Threshold | Gate threshold (0–100%) |
| Pre-Open | Look-ahead to catch transients before they're cut (ms) |
| Hold | How long the gate stays open after signal drops (ms) |
| Release | How fast the gate closes (ms) |
| Range | How much the gate attenuates when closed (dB) — 0 = full mute, -40 = gentle |
| Density Sensitivity | How much playing density lowers the threshold |
| Hysteresis | Difference between open and close thresholds — prevents chatter |
| Sidechain HPF | High-pass filter on the detection signal (Hz) |
| Mix | Dry/wet blend |
| Fade In | Attack time when gate opens (ms) |

**Drum Mode additional controls:**

| Control | What It Does |
|---------|-------------|
| Drum Type | Kick / Snare / Tom / OH |
| Tom Distance | Position in the kit (1 = near snare, 8 = far) |
| Bleed Reject | How aggressively to reject bleed from other drums (%) |

**Drum Mode Features:**
- **Cross-instance communication:** Every Smart Gate instance in drum mode sees every other instance via shared memory. The DRUM PEERS panel shows all connected drums with their gate state.
- **Remote threshold adjustment:** Right-click any peer row to open a slider popup and adjust that drum's threshold from the current instance.
- **Phase correction (close mics):** Click PHASE CORRECT TO OH, hit a drum, and the plugin measures the sample-accurate time offset between the close mic and overheads. It then delays the close mic signal to align with the overheads. The offset persists across sessions.
- **Phase correction (OH instances):** Click CAL ALL PHASE to arm every close mic simultaneously. Supports stereo OH pairs — offsets from both OHs are averaged.
- **Phase View:** OH instances get a PHASE VIEW button that shows a live visualization — one circle per close mic. Red and wobbly = out of phase. Green and smooth = aligned.
- **CLR button:** Resets phase correction offset to zero.

**Tips:**
- Smart Gate + Black In Bluhm Special + Density Maximizer = 5-minute drum mix
- Pre-Open at 5ms preserves the attack of every hit
- In drum mode, set all your drums to their types first, then dial thresholds from one instance using right-click
- Bleed Reject at 60% is a good starting point for most kits
- Range at -40 dB instead of -80 dB sounds more natural — lets a little room through

---

## Tone & Effects

---

### PEQ4U — Passive Equalizer

Pultec-style passive EQ with simultaneous boost and cut.

| Control | What It Does |
|---------|-------------|
| Low Boost | Low-frequency boost amount |
| Low Atten | Low-frequency cut amount |
| Low Freq | 20 / 30 / 60 / 100 Hz |
| High Boost | High-frequency boost amount |
| High Boost BW | Bandwidth (1 = broad, 10 = sharp) |
| High Atten | High-frequency cut amount |
| High Boost Freq | 3k / 4k / 5k / 8k / 10k / 12k / 16k Hz |
| Tube Saturation | On/Off |
| Output | Output gain (dB) |

**Tips:**
- The Pultec trick: boost AND cut the low end simultaneously. The overlapping curves create a unique mid-dip that tightens bass without thinning it.
- Tube Saturation adds subtle warmth — leave it on unless you need surgical precision

---

### LMS Tube Saturator

Standalone saturation with 5 modes and full tone control.

| Control | What It Does |
|---------|-------------|
| Drive | Saturation amount (0–100%) |
| Output Gain | Output level (dB) |
| Dry/Wet | Parallel blend |
| Even Harmonics | 2nd harmonic content (warmth) |
| Odd Harmonics | 3rd harmonic content (edge) |
| Mode | Warm Tube / Hot Tube / Tape / Rectifier / Fuzz |
| Tone | Low-pass filter (Hz) |
| Bias | Asymmetry — adds even harmonics at the cost of headroom |

**Tips:**
- Tape mode at low Drive (10-20%) is great for gentle warming on mix bus
- Fuzz mode is NOT subtle. Use it on purpose.
- Even Harmonics high + Odd Harmonics low = warm. Opposite = aggressive.

---

### LMS Tape Machine

Tape saturation processor with spring reverb. Two sections: saturation and delay.

| Control | What It Does |
|---------|-------------|
| Sat Enable | Saturation on/off |
| Drive | Tape saturation intensity |
| Sat Mode | Saturation character |
| Even / Odd Harmonics | Harmonic balance |
| Bias | Tape bias |
| Sat Routing | Where saturation is applied |
| Delay Enable | Echo on/off |
| Head Mode | Tape head configuration |
| Repeat Rate | Echo time (ms) |
| Intensity | Feedback / regeneration |
| Echo Volume | Wet echo level |
| Wow & Flutter | Tape speed variation |
| Tape Age | Degradation — older tape = more lo-fi |
| Bass / Treble | Tone shaping |
| Tone | Master tone (Hz) |
| Spring Reverb | Built-in spring reverb amount |
| Output Gain | Output level (dB) |
| Dry/Wet | Master blend |

**Tips:**
- Great on vocals. Sat Enable on + Drive at 30% + Spring Reverb at 15% = instant vintage vocal
- Wow & Flutter at 10-20% adds subtle movement without sounding broken
- Tape Age at 0 = clean. Tape Age at 80+ = lo-fi warble

---

### Henge Delay — Space Tape Echo

Standalone tape delay with spring reverb. Inspired by the Roland Space Echo.

| Control | What It Does |
|---------|-------------|
| Mode | Tape head mode |
| Repeat Rate | Delay time (ms) |
| Intensity | Feedback |
| Echo Volume | Wet level |
| Bass / Treble | Echo tone |
| Wow & Flutter | Tape speed variation |
| Tape Age | Lo-fi degradation |
| Spring Reverb | Reverb on the echo signal |
| Dry/Wet | Master blend |

**Tips:**
- Intensity above 80% = self-oscillation. Careful.
- Spring Reverb on the echoes sounds massive for ambient stuff
- Tape Age at 50% + Wow & Flutter at 30% = dub delay

---

### Black In Bluhm Special — Physical Room Modeler

Physical room acoustics modeler. Everything emerges from geometry — no fake reverb knobs.

| Control | What It Does |
|---------|-------------|
| Walls | Room polygon sides (3-12) — 4 = rectangle, more = rounder |
| Room Width | Room width in meters |
| Room Depth | Room depth in meters |
| Ceiling Height | Room height in meters |
| Wall/Floor/Ceiling Material | Surface absorption (Concrete, Wood, Drywall, Glass, Brick, Carpet, Curtain, Foam) |
| Source X/Y | Sound source position — drag in room view |
| Source Angle | Source facing direction |
| Mic X/Y | Microphone position — drag in room view |
| Mic Angle | Mic facing direction |
| Mic Pattern | Omni / Cardioid / Figure-8 / Hypercardioid |
| Reflection Depth | 1st Order only or 2nd Order reflections |
| Compressor | Off / LA2A / 1176 / Distressor |
| Comp Amount | How hard you drive the compressor |
| Wet Mix | Wet/dry blend |
| Output Gain | Output level (dB) |

**Tips:**
- Parallel walls = comb filtering (move mic to hear it)
- Source near a wall = bass buildup (boundary effect)
- Carpet/Foam walls = dead room, Concrete = long RT60
- 1176 at high amount = all-buttons-in room crush
- Distressor adds harmonic saturation that thickens the verb
- Drag source and mic in the room view for real-time positioning

---

### Density Reverb — Harmonic Room Physics

Advanced FDN reverb with modal filtering and density-aware processing. Eight preset room types.

| Control | What It Does |
|---------|-------------|
| Preset | Plate / Spring / Pop Ambient / Basement / Studio Live / Studio Dampened / Cathedral / Garage |
| Room Size | Room dimensions (0–100%) |
| Decay | Reverb tail length (0–100%) |
| Tone | Brightness of the reverb (0–100%) |
| Pre-Delay | Gap before reverb starts (ms) |
| Diffusion | Density of early reflections (0–100%) |
| Density Drive | Density-aware harmonic saturation (0–100%) |
| Width | Stereo spread (0–100%) |
| Mix | Dry/wet blend (0–100%) |
| Low Cut | High-pass on the reverb signal (20–500 Hz) |
| Output Gain | Output level (dB) |

**Tips:**
- Start with a preset close to what you want, then tweak Size and Decay
- Density Drive adds harmonic content that responds to input dynamics — louder playing = richer reverb
- Low Cut at 80–120 Hz keeps reverb from muddying the low end
- Cathedral preset at low Mix (10-15%) adds depth without washing things out
- Pop Ambient is a good general-purpose starting point

---

## Pitch & Tuning

---

### LMS Pitch Detector — Monophonic Pitch Tracker

Real-time pitch detection using the YIN algorithm. Outputs MIDI and feeds pitch data to other plugins via the shared pitch bus.

| Control | What It Does |
|---------|-------------|
| Sensitivity | Detection threshold (0.05–0.50) — lower = stricter |
| Min Hz | Lowest frequency to detect (50–400 Hz) |
| Max Hz | Highest frequency to detect (200–1500 Hz) |
| MIDI Channel | Output MIDI channel (1–16) |
| MIDI Output | On/Off |
| Key | Root note (C through B) |
| Scale | Chromatic / Major / Minor |
| Min Note | Minimum note duration before latching (ms) |

**Tips:**
- Use this upstream of Autotune or any plugin that reads the pitch bus
- Sensitivity at 0.15 is a good starting point — raise it if you get false triggers, lower it for quieter signals
- Set Min/Max Hz to match your instrument range for more accurate detection
- Displays detected frequency, confidence, note name, and cents offset in the GUI

---

### LMS Autotune — Real-Time Pitch Correction

Pitch correction with embedded YIN detection, vibrato preservation, and scale snapping.

| Control | What It Does |
|---------|-------------|
| Speed | Correction speed (0–100%) — 100% = instant snap, lower = more natural |
| Dry/Wet | Blend between original and corrected signal (0–100%) |
| Output Gain | Output level (dB) |
| Vibrato Preserve | How much natural vibrato to keep (0–100%) |
| Lookahead | Prediction time for smoother correction (0–15 ms) |
| Sensitivity | Pitch detection threshold (0.05–0.50) |
| Key | Root note (C through B) |
| Scale | Chromatic / Major / Minor |
| Min Note | Minimum note duration before correction latches (ms) |

**Tips:**
- Speed at 100% + Dry/Wet at 100% = the robotic T-Pain effect
- Speed at 40-60% + Vibrato Preserve at 50% = transparent vocal tuning
- Set the correct Key and Scale to avoid correcting to wrong notes
- Works best on monophonic sources (vocals, solo instruments)

---

## Instruments

---

### DRUMBANGER — 16-Pad Drum Machine

Full-featured drum machine with sequencer, sampling, and per-pad effects.

**Pads:**
- 16 pads in a 4x4 grid
- Each pad has: Volume, Pan, Pitch (-24 to +24 semitones), LP Filter, HP Filter, Saturation, Compression
- Choke groups (1-8) — pads in the same group cut each other off (like hi-hat open/close)
- Copy/paste: Ctrl+click to copy a pad's settings to another

**Kits:**
- Kits are subfolders in the `pool/` directory
- Each kit holds up to 16 WAV samples
- Navigate kits with the [<] Kit [>] buttons
- Individual pads can override their kit sample with any sample from the pool

**Sequencer:**
- 8 patterns, each up to 4 bars of 16 steps
- Variable step resolution (1x, 2x, 4x subdivisions)
- Swing control
- Right-click steps to edit velocity
- Step ties for sustained hits across steps

**Sampling:**
- SAMPLE button captures audio from the timeline into the pool
- Requires the drumbanger_service.lua background script running
- Load samples manually with the drumbanger_load.lua script

**MIDI:**
- Receives MIDI notes (default C1–D#2 for pads 1–16)
- Configurable root note
- All MIDI passes through to downstream plugins

**P-Lock Recording:**
- Arm Record Input, start playback, and tweak any pad parameter
- Changes are recorded per-step as parameter locks
- Like Elektron-style parameter automation

**Tips:**
- Set drumbanger_service.lua as a startup action for seamless sampling
- Right-click velocity editing is the fastest way to program realistic patterns
- Use choke groups for hi-hat work — open hat in group 1, closed hat in same group

---

### Drum Trigger — Audio-to-DrumBanger Transient Detector

Converts audio transients into DrumBanger pad triggers. No MIDI routing needed.

| Control | What It Does |
|---------|-------------|
| Input Gain | Input level (dB) |
| MIDI Channel | Output MIDI channel |
| MIDI Note Base | Starting note for MIDI output |
| Band 0–3 Enable | Enable/disable each frequency band |
| Band 0–3 Threshold | Detection sensitivity per band |
| Band 0–3 Pad | Which DrumBanger pad to trigger |
| Release | How long before re-triggering (ms) |
| Cooldown | Minimum time between triggers (ms) |
| Hysteresis | Prevents double-triggers |
| Audio Passthrough | Pass audio through or mute |
| Velocity Sensitivity | How much level affects velocity |

**Tips:**
- Use 4 bands to split a full drum mix: Band 0 = kick (low), Band 1 = snare (mid), Band 2 = hats (high), Band 3 = toms
- Communicates directly with DrumBanger via shared memory — no MIDI routing needed
- Has MIDI output as a fallback for non-DrumBanger use

---

### NUUG 420 — Analog Mono Synth

Moog-inspired mono synth with ladder filter, 2 ADSR envelopes, LFO, and up to 8-voice unison.

| Section | Controls |
|---------|----------|
| OSC 1 | Wave, Tune (semitones), Fine (cents), Level, Pulse Width |
| OSC 2 | Wave, Tune, Fine, Level |
| Sub Osc | Type, Level |
| Noise | Level |
| Unison | Voices (1–8), Detune |
| Filter | Cutoff (Hz), Resonance, Mode (LP/HP/BP), Env Amount |
| Filter Envelope | Attack, Decay, Sustain, Release |
| Amp Envelope | Attack, Decay, Sustain, Release |
| LFO | Shape (6 types), Rate (Hz), Sync |
| LFO Destinations | Pitch, Filter, Amp, PWM |

**Tips:**
- Unison 4 voices + Detune at 15% = massive lead sound
- Filter resonance at max = self-oscillation (it's a ladder filter, it screams)
- LFO → Filter at low rate = classic filter sweep
- Responds to MIDI. Use with DrumBanger Drone MIDI satellite for generative stuff.

---

### Density Sequencer — Your Playing Is The Sequence

Reactive MIDI sequencer that generates patterns based on your playing dynamics.

| Control | What It Does |
|---------|-------------|
| Mode | Sequencer behavior mode |
| Sensitivity | How responsive to input dynamics |
| Density | Pattern complexity |
| BPM | Tempo (or host sync) |
| Root Note | Key center |
| Scale | Musical scale selection |
| Swing | Rhythmic swing |
| Humanize | Timing variation |
| Output Level | Output volume (dB) |
| Wet Mix | Blend with input |

**Tips:**
- Feed it a guitar or bass signal and it generates complementary MIDI patterns
- Higher Density = more complex patterns. Lower = sparse, rhythmic.
- Use with NUUG 420 on another track for generative accompaniment

---

### Drone Satellites (DrumBanger companions)

Two plugins that work together to create drone synth tracks triggered by DrumBanger.

**DroneMIDI2** — Converts DrumBanger pad triggers into musical MIDI notes.

| Control | What It Does |
|---------|-------------|
| Mode | Trigger behavior |
| MIDI Channel | Output channel |
| Root Note | Key center |
| Scale | Musical scale |
| Chord Mode | Chord voicing type |
| Octave | Octave range |

**DroneFX** — Effects processor for drone tracks.

| Control | What It Does |
|---------|-------------|
| Compressor | On/Off, Threshold, Ratio, Attack, Release |
| Duck Depth | Sidechain ducking amount |
| Delay | On/Off, Time, Feedback, Mix, Tape Age, Wow/Flutter |
| Flanger | On/Off, Rate, Depth, Feedback, Mix |
| Output | Output level (dB) |

**Signal chain per drone track:** DroneMIDI2 → NUUG 420 → DroneFX → Channel Strip

**Tips:**
- Set up 4-8 drone tracks with different scales/octaves for evolving ambient beds
- DroneFX's ducker makes drones breathe with the drums
- The BLEEP_BOOP preset has this all pre-configured

---

## Scripts

---

### Session Management

**LMS: Save Session** (`lms_save.lua`)
Saves all track names, fader positions (volume/pan/mute/solo), and complete FX chains with parameters to a `.lms` file. All tracks must be named.

**LMS: Load Session** (`lms_load.lua`)
Loads a `.lms` file into the current project. Matches tracks by name, creates missing tracks, replaces FX chains.

**LMS: Steal Session** (`lms_steal.lua`)
Imports the mix from any `.lms` file. Existing tracks get updated; new tracks get added. Great for pulling your mix settings from one project into another.

### DrumBanger Scripts

**DRUMBANGER: Load Sample** (`drumbanger_load.lua`)
File picker to load a WAV into the pool and assign it to the selected pad.

**DRUMBANGER: Rescan Pool** (`drumbanger_rescan.lua`)
Rescans the pool folder and rebuilds the manifest. Run this after manually adding samples.

**DRUMBANGER: Sample from Project** (`drumbanger_sample.lua`)
Captures a time selection or media item from the timeline as a WAV and loads it onto a pad.

**DRUMBANGER: Sampling Service** (`drumbanger_service.lua`)
Background service that enables the SAMPLE button inside DrumBanger. Set this as a REAPER startup action for seamless workflow.

**DRUMBANGER: Open Pool Folder** (`drumbanger_open_pool.lua`)
Opens the DrumBanger pool folder in your system file manager. Drop `.wav` files or kit folders directly. Subfolders become kit names; first 16 `.wav` files per folder map to pads 1–16.

**DRUMBANGER: Diagnose** (`drumbanger_diagnose.lua`)
Diagnostic tool that searches the REAPER Effects tree and reports all copies of DrumBanger, kits, and pool directories. Changes nothing — purely informational. Run this if kits aren't loading.

**DRUMBANGER: Fix Pool** (`drumbanger_fix_pool.lua`)
Nuclear option for broken pool directories. Reads all existing `.wav` files into memory, nukes the old pool/kits structure, writes a clean directory, deduplicates, and rebuilds `manifest.txt`. Safe to run — no sample data is lost.

---

## Presets

Three session presets included. Load them with the LMS: Load Session script.

**YOUR_BAND** — Full band template: 10 drum tracks (Kick x2, Snare x2, 3 Toms, OH L/R, Room), 4 guitars (2L punk, 2R mesa), bass, 3 vocals, master. Smart Gate on all audio tracks.

**DEMO_TIME** — Same as YOUR_BAND but with a single DrumBanger track replacing the 10 individual drum tracks. For when you're writing, not recording.

**BLEEP_BOOP** — Electronic template: DrumBanger + 8 drone synth tracks (DroneMIDI2 → NUUG 420 → DroneFX → Channel Strip) + bass + guitar + master.

---

## Shared Features

### Broadcast System
Most plugins include an instance manager panel at the bottom of the GUI. This lets multiple instances of the same plugin communicate:
- **Follow:** One instance mirrors another's settings in real time
- **Steal:** Copy settings from one instance to another
- Each instance gets a unique ID and name

### 4K / HiDPI Scaling
All GUIs scale automatically based on your display. Everything stays crisp at any resolution.

### BUY / NOTICE Buttons
Bottom-right of every plugin. BUY links to support the project. NOTICE contains the manifesto.

---

*github.com/LMSBAND | instagram.com/LMSSKABAND*
