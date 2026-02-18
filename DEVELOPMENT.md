# LMS Plugin Development Guide

How to build a new plugin in the LMS suite. Read this before starting. It covers the file structure, the shared DSP kernel, the broadcast system, the GFX conventions, and how to add new algorithms when what's in the core isn't enough.

---

## The Big Picture

Every LMS plugin is a single `.jsfx` file that imports `lms_core.jsfx-inc`. The core contains all the DSP primitives — filters, saturation, compression, reverb building blocks. The plugin file is just: sliders, DSP routing, and GFX. No duplication.

```
lms_core.jsfx-inc       ← shared DSP (biquads, sat, comp, DC blocker, etc.)
lms_your_plugin.jsfx    ← sliders + routing + GFX + broadcast
```

The broadcast system (follow/steal) is copy-pasted into every plugin's `@init`/`@block`/`@gfx`. It's boilerplate. Get it from any existing plugin, change the constants, done.

---

## Starting a New Plugin

### 1. Copy the template

Use `lms_tube_sat.jsfx` as your template — it's the leanest plugin that has everything: core import, broadcast system, GFX panel, serialize. Copy it, rename it, gut the DSP.

```bash
cp lms_tube_sat.jsfx lms_your_plugin.jsfx
```

### 2. Set the required constants at the top of `@init`

```jsfx
BC_BASE = 100000;
BC_MY_TYPE = X;       // pick a unique number — see table below
BC_SLOT_SIZE = 512;
BC_MAX_INST = 32;
BC_PARAM_COUNT = N;   // number of sliders you have
BC_MY_REGION = BC_BASE + BC_MY_TYPE * 16384;
BC_STALE_TIMEOUT = 2;

BC_STALE_HB = Y;      // local memory address — see table below
BC_STALE_CT = Y + 32; // always HB + 32 (one slot per instance)
```

### BC_MY_TYPE and memory address registry

Each plugin must have a unique type number AND unique local memory addresses for stale detection. **Never reuse these.**

| Plugin | BC_MY_TYPE | BC_STALE_HB | BC_STALE_CT |
|--------|-----------|-------------|-------------|
| lms_tube_sat | 1 | 10000 | 10032 |
| lms_tape_machine | 2 | 500000 | 500032 |
| lms_tape_echo | 3 | 200000 | 200032 |
| lms_channel_strip | 4 | 10000 | 10032 |
| lms_distressor | 5 | 300000 | 300032 |
| lms_passive_eq | 6 | 400000 | 400032 |
| lms_matchering | 7 | 70000 | 70032 |
| lms_moog_synth | 8 | 900000 | 900032 |
| lms_chris_bedroom | 9 | 600000 | 600032 |
| lms_amp_suite | 10 | 640000 | 640032 |
| **your new plugin** | **11+** | **pick unused** | **HB + 32** |

For new plugins: pick the next `BC_MY_TYPE` integer, pick a round memory address not in the table (e.g. `600000`), set `BC_STALE_CT = BC_STALE_HB + 32`.

### 3. Update the slider broadcast arrays

In `@block`, find the section that copies params to gmem:

```jsfx
pbase = sb + 8;
gmem[pbase + 0] = slider1;
gmem[pbase + 1] = slider2;
// ... one line per slider
```

And the follow section that reads from the leader:

```jsfx
slider1 = gmem[lbase + 0];
slider2 = gmem[lbase + 1];
// ...
```

And the steal section (identical to follow). All three must match. `BC_PARAM_COUNT` must equal your slider count.

### 4. Add to `@serialize`

```jsfx
@serialize
file_var(0, bc_following);
file_var(0, bc_my_id);
```

That's all that needs persisting. `bc_my_id` is the unique instance ID — preserving it means follow relationships survive project reopen.

---

## The Shared DSP Core

Import at the top of your file, before anything else:

```jsfx
import lms_core.jsfx-inc
```

That's it. All functions are available in every section (`@slider`, `@block`, `@sample`, `@gfx`).

### Section 1: Math

```jsfx
lms_tanh(x)              // soft clamp, -1 to 1
lms_db2lin(db)           // dB → linear gain
lms_lin2db(lin)          // linear → dB (returns -140 for silence)
```

### Section 2: Biquad Filters

One instance = one stereo filter band. Name your instances anything.

```jsfx
// @init
hp.lms_bq_init();
eq_lo.lms_bq_init();

// @slider or @block (recalculate when params change)
hp.lms_bq_set_hp(freq, q);           // highpass (q=0.707 = Butterworth)
hp.lms_bq_set_lp(freq, q);           // lowpass
hp.lms_bq_set_bp(freq, q);           // bandpass
eq_lo.lms_bq_set_peak(freq, db, q);  // parametric peak
eq_lo.lms_bq_set_loshelf(freq, db, q); // low shelf
eq_lo.lms_bq_set_hishelf(freq, db, q); // high shelf

// @sample (per sample, both channels)
l = hp.lms_bq_proc_l(l);
r = hp.lms_bq_proc_r(r);
```

Stack as many bands as you want — `hp`, `ls`, `lm`, `hm`, `hs`, whatever. Each is independent state.

### Section 3: Saturation

All stateless — call directly in `@sample`:

```jsfx
l = lms_sat_warm(l, drive, bias);   // tube warm — asymmetric tanh
l = lms_sat_hot(l, drive, bias);    // tube hot — harder clip
l = lms_sat_tape(l, drive, bias);   // tape — symmetric arctan
l = lms_sat_rect(l, drive, bias);   // rectifier — folds negative
l = lms_sat_fuzz(l, drive, bias);   // fuzz — hard clip + crossover
l = lms_sat_harmonics(l, even, odd); // harmonic generator — adds 2nd/3rd overtones
```

`drive` and `bias` are 0..1. After saturation, apply DC blocker (see Section 5) if using warm/hot/rect modes — asymmetric clippers generate DC offset.

### Section 4: Compressor

FET-style, stereo-linked peak detection.

```jsfx
// @init
comp.lms_comp_init();

// @slider or @block
comp.lms_comp_set(thresh_db, ratio, att_ms, rel_ms);
// thresh_db: e.g. -18.0
// ratio: linear e.g. 4.0 (not 4:1, just 4)
// att_ms: attack in milliseconds e.g. 5.0
// rel_ms: release in milliseconds e.g. 100.0

// @sample
comp.lms_comp_proc(l, r);
l *= comp.gr;      // apply gain reduction
r *= comp.gr;
// comp.gr_db has dB of reduction — use it for a GR meter
```

### Section 5: DC Blocker

Use after any asymmetric saturation:

```jsfx
// @init
dc.lms_dc_init();              // default 20 Hz
dc.lms_dc_init_freq(10);       // or custom cutoff

// @sample
l = dc.lms_dc_proc_l(l);
r = dc.lms_dc_proc_r(r);
```

### Section 6: Tone Filter

Simple 1-pole lowpass for a tone knob:

```jsfx
// @init
tone.lms_tone_init();

// @slider or @block
tone.lms_tone_set(freq);   // e.g. 8000 Hz

// @sample
l = tone.lms_tone_proc_l(l);
r = tone.lms_tone_proc_r(r);
```

Automatically bypasses when `freq >= 19999`.

### Section 7: Cubic Interpolation

For delay buffers — smoother than linear when reading fractional positions:

```jsfx
out = lms_interp_cubic(buf, read_pos, buf_max_size);
```

Use this any time you have a delay line with a non-integer read position (pitch shifting, chorus, tape wow/flutter).

### Section 8: Spring Reverb Allpass

Building block for reverb/diffusion networks:

```jsfx
out = lms_spring_ap(buf, pos, len, input, coeff);
pos += 1; pos >= len ? pos = 0;  // caller advances the pointer
```

Chain several of these together at different lengths for a Schroeder diffuser or spring reverb tail. See `lms_drum_room.jsfx` for a full reverb implementation using these.

### Section 9: Sag Simulator

Models tube rectifier voltage droop on loud transients. Creates the elastic "bloom" feel of vintage amps vs. silicon diode tightness.

```jsfx
sag.lms_sag_init();
sag.lms_sag_set(22);       // attack in ms (15-30ms typical for Mesa)
// in @sample:
gain = sag.lms_sag_proc(mono_input);
signal *= gain;
// sag.gr = current gain (0.7–1.0)
```

### Section 10: Cascaded Saturation

Two-stage warm tube saturation chain — models the JCM800's V1B→V1A cold-clipper preamp:

```jsfx
out = lms_sat_cascade(x, drive1, bias1, drive2, bias2);
// stage1 = lms_sat_warm(x, drive1, bias1)
// stage2 = lms_sat_warm(stage1, drive2, bias2)
```

### Section 11: Opto Compressor

LA-2A T4B photocell model. Program-dependent release: fast initial discharge (~60ms) followed by slow tail (~500ms). Musical and forgiving.

```jsfx
opto.lms_opto_init();
opto.lms_opto_set(-18, 4, 10);   // thresh_db, ratio, att_ms
// in @sample:
opto.lms_opto_proc(spl0, spl1);
spl0 *= opto.gr;
spl1 *= opto.gr;
// opto.gr = linear gain, opto.gr_db = dB reduction
```

---

## Adding a New Algorithm to the Core

When you need DSP that doesn't exist yet, add it to `lms_core.jsfx-inc`. Every plugin gets it automatically.

**Rules:**
1. Add inside the existing `@init` block — never outside it
2. Use `lms_` prefix on all function names
3. Stateful functions use `this.*` so callers can have multiple independent instances
4. Follow the existing section pattern: header comment block, usage example, then functions
5. Stateless functions go in sections 1, 3, 7 pattern. Stateful go in sections 2, 4, 5, 6 pattern.
6. After adding, bump the version comment at the top of the file

**Template for a new stateful algorithm:**

```jsfx
// ============================================================================
//  SECTION N: Your Algorithm Name (stereo, this.* state)
//
//  One-line description.
//
//  Usage:
//    @init:   inst.lms_xxx_init();
//    @block:  inst.lms_xxx_set(param1, param2);
//    @sample: l = inst.lms_xxx_proc_l(l);
//             r = inst.lms_xxx_proc_r(r);
// ============================================================================

function lms_xxx_init()
(
  this.state = 0;
  // zero all state variables
);

function lms_xxx_set(param1, param2)
(
  // precompute coefficients from params
  this.coeff = ...;
);

function lms_xxx_proc_l(x)
  local(o)
(
  // process and return output
  o = ...;
  o;
);

function lms_xxx_proc_r(x)
  local(o)
(
  o = ...;
  o;
);
```

**After adding to the core:** update `index.xml` with a new version entry for `lms_core.jsfx-inc`.

---

## GFX Conventions

Every plugin uses the same color palette. Copy these constants into `@gfx` at the top:

```jsfx
COL_BG_R = 0.05; COL_BG_G = 0.05; COL_BG_B = 0.07;
COL_PANEL_R = 0.08; COL_PANEL_G = 0.08; COL_PANEL_B = 0.11;
COL_PANEL_HI_R = 0.12; COL_PANEL_HI_G = 0.12; COL_PANEL_HI_B = 0.16;
COL_BORDER_R = 0.20; COL_BORDER_G = 0.20; COL_BORDER_B = 0.25;
COL_TITLE_R = 0.95; COL_TITLE_G = 0.78; COL_TITLE_B = 0.35;   // gold
COL_SEC_R = 0.55; COL_SEC_G = 0.50; COL_SEC_B = 0.40;
COL_TEXT_R = 0.78; COL_TEXT_G = 0.78; COL_TEXT_B = 0.82;
COL_DIM_R = 0.38; COL_DIM_G = 0.38; COL_DIM_B = 0.42;
COL_ACCENT_R = 0.95; COL_ACCENT_G = 0.45; COL_ACCENT_B = 0.15; // orange
COL_GREEN_R = 0.25; COL_GREEN_G = 0.80; COL_GREEN_B = 0.50;
COL_CYAN_R = 0.20; COL_CYAN_G = 0.60; COL_CYAN_B = 0.85;
COL_BAR_BG_R = 0.12; COL_BAR_BG_G = 0.12; COL_BAR_BG_B = 0.16;
```

### Standard helpers

Every plugin has these helper functions defined in `@gfx`. Copy them verbatim:

- `draw_bar(x, y, w, h, val, vmin, vmax, label, show_val)` — interactive slider bar, returns new value
- `draw_panel(x, y, w, h, title)` — titled panel box with border
- `draw_toggle(x, y, is_on, label)` — on/off LED toggle, returns new state
- `draw_mode_sel(x, y, w, h, val, vmax, label, v0, v1, v2, v3)` — click-through mode selector

### Layout pattern

```jsfx
@gfx 560 420    // width height — set this in the header, not hardcoded in drawing

margin = 8;
gap = 6;
bar_h = 18;
bar_sp = 21;    // bar height + spacing
body_y = 50;    // below title bar

// Columns
col_w = floor((gfx_w - margin*2 - gap*2) / 3);
c1x = margin;
c2x = margin + col_w + gap;
c3x = margin + (col_w + gap)*2;
```

### Slider automate pattern

Every `draw_bar` / `draw_toggle` / `draw_mode_sel` call must feed back into `slider_automate` so REAPER knows the param changed (this is what makes the broadcast system work):

```jsfx
_old = slider1;
slider1 = draw_bar(x, y, w, h, slider1, min, max, "Label", 1);
slider1 != _old ? slider_automate(2^0);  // bit index = slider number - 1

_old = slider2;
slider2 = draw_toggle(x, y, slider2, "HPF");
slider2 != _old ? slider_automate(2^1);
```

### Mouse state tracking

At the very end of `@gfx`, always:

```jsfx
last_cap = mouse_cap;
```

This is how `draw_toggle` and `draw_mode_sel` detect single-click (rising edge) vs held.

### The broadcast panel

The instance manager panel lives at the bottom of every plugin's `@gfx`. It's ~200 lines of boilerplate. Copy it verbatim from any existing plugin. The only thing that changes per-plugin is the status bar text showing what you're following.

The panel shows:
- **[LEADER]** (gold) — someone is following this instance
- **[FOLLOWER]** (blue) — this instance is following another
- **[UNASSIGNED]** (gray) — free agent
- **[YOU]** (orange) — this instance in the list

---

## The `@block` Rule

REAPER does not call `@slider` when you move a slider via the GFX panel. So all coefficient recalculation must happen in **both** `@slider` and `@block`. The standard pattern:

```jsfx
@slider
  my_gain = lms_db2lin(slider1);
  lp.lms_bq_set_lp(slider2, 0.707);

@block
  // Repeat everything from @slider here
  my_gain = lms_db2lin(slider1);
  lp.lms_bq_set_lp(slider2, 0.707);

  // Then the broadcast system code...
```

Yes it's duplicated. That's intentional and correct.

---

## Deploy Workflow

```bash
# 1. Copy to REAPER Effects so it loads immediately
cp lms_your_plugin.jsfx ~/.config/REAPER/Effects/lms_your_plugin.jsfx

# 2. In REAPER: reload the plugin
# FX window → right-click → "Re-initialize" or close and reopen the FX chain

# 3. When happy, add to index.xml and commit
git add lms_your_plugin.jsfx lms_core.jsfx-inc index.xml
git commit -m "Add lms_your_plugin: description"
git push
```

On Windows: copy to `%APPDATA%\REAPER\Effects\`.

---

## Adding to ReaPack (index.xml)

When the plugin is ready to ship, add an entry to `index.xml`:

```xml
<reapack name="lms_your_plugin.jsfx" type="effect" desc="YOUR PLUGIN NAME — Short description">
  <version name="1.0" author="LMS" time="2026-XX-XXTXX:XX:XXZ">
    <changelog><![CDATA[Initial release — description of what it does.]]></changelog>
    <source>https://raw.githubusercontent.com/LMSBAND/LMS/master/lms_your_plugin.jsfx</source>
  </version>
</reapack>
```

Put it inside the `<category name="LMS">` block. Future versions just add more `<version>` entries inside the same `<reapack>` block — never edit or remove old ones.

If you added a new algorithm to `lms_core.jsfx-inc`, add a new version entry for that package too.

---

## CHRIS' BEDROOM Checklist

Since that's the next one — amp sim + bedroom reverb. Here's what to plan:

**DSP needed (all in core already or buildable from it):**
- Preamp gain → `lms_sat_warm` / `lms_sat_hot` (amp input stage)
- Tone stack (bass/mid/treble) → 3x `lms_bq_set_*`
- Power amp saturation → `lms_sat_tape` or `lms_sat_hot`
- Cabinet IR simulation → a short FIR or a few biquad notches to shape frequency response
- Room reverb → chain of `lms_spring_ap` units like drum_room does it (Schroeder or FDN)

**What's NOT in the core yet:**
- Cabinet EQ / speaker coloration — a set of preset biquad curves per "cabinet type" would work
- Room size → delay-based early reflections (need a delay buffer like drum_room's)

**Things to steal from drum_room:**
- The allpass chain for the reverb tail
- The early reflections array pattern
- The room visualization idea (could do a bedroom bird's-eye instead of a live room)

---

## Gotchas

- **`@init` rule**: functions in imported files are only available globally if defined inside `@init` in the imported file. `lms_core.jsfx-inc` already does this correctly. If you add a new `.inc` file, it must also open with `@init`.
- **`BC_STALE_CT = BC_STALE_HB + 32`**: the HB array is 32 slots wide. If you put CT at HB+8 it overlaps and everything breaks silently.
- **`bc_my_id == 0`**: the double-equals is intentional. JSFX initializes all vars to 0 on first load, but `@serialize` restores `bc_my_id` on project reload. The `==` check only generates a new ID if it's genuinely zero (first ever load), preserving follow relationships across project save/reopen.
- **Don't call `lms_bq_set_*` in `@sample`**: coefficient calculation is expensive. Set in `@slider`/`@block`, process in `@sample`.
- **gmem namespace**: all LMS plugins share the same `gmem=DrumBanger` namespace. The `BC_MY_TYPE * 16384` offset gives each plugin type its own non-overlapping region. 32 instances × 512 slots = 16384 exactly — do not shrink either constant without recalculating. Never use a multiplier smaller than `BC_MAX_INST * BC_SLOT_SIZE`.
