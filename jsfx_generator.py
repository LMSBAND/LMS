#!/usr/bin/env python3
"""
JSFX Generator - creates a real-time Reaper plugin from matchering analysis params.
Reads the JSON output from matchering_analyzer.py and generates a .jsfx file.
"""

import sys
import os
import json


def generate_jsfx(params, output_path):
    mid_bands = params["mid_eq_bands"]
    side_bands = params["side_eq_bands"]
    rms_gain = params["rms_gain_db"]
    num_bands = len(mid_bands)

    # Build slider definitions
    sliders = []
    s = 1
    sliders.append(f"slider{s}:{rms_gain:.2f}<-20,20,0.1>Master Gain (dB)")
    s += 1
    sliders.append(f"slider{s}:100<0,100,1>Dry/Wet (%)")
    s += 1
    sliders.append(f"slider{s}:1<0,1,1{{Off,On}}>Limiter")
    s += 1
    sliders.append(f"slider{s}:-0.01<-6,0,0.01>Limiter Threshold (dB)")
    s += 1

    mid_start = s
    for band in mid_bands:
        sliders.append(f"slider{s}:{band['gain_db']:.2f}<-12,12,0.01>Mid {_freq_label(band['freq'])}")
        s += 1

    side_start = s
    for band in side_bands:
        sliders.append(f"slider{s}:{band['gain_db']:.2f}<-12,12,0.01>Side {_freq_label(band['freq'])}")
        s += 1

    # Build freq init lines
    freq_inits = []
    for i, band in enumerate(mid_bands):
        freq_inits.append(f"  mid_freqs[{i}] = {band['freq']:.1f};")
    for i, band in enumerate(side_bands):
        freq_inits.append(f"  side_freqs[{i}] = {band['freq']:.1f};")

    # Build slider update lines for mid
    mid_updates = []
    for i in range(num_bands):
        si = mid_start + i
        mid_updates.append(f"  this.calc_peaking_eq(mid_coeffs + {i*13}, mid_freqs[{i}], slider{si}, 1.5);")

    side_updates = []
    for i in range(num_bands):
        si = side_start + i
        side_updates.append(f"  this.calc_peaking_eq(side_coeffs + {i*13}, side_freqs[{i}], slider{si}, 1.5);")

    # Build mid apply lines
    mid_applies = []
    for i in range(num_bands):
        mid_applies.append(f"  mid = this.apply_biquad(mid_coeffs + {i*13}, mid, 5);")

    side_applies = []
    for i in range(num_bands):
        side_applies.append(f"  side = this.apply_biquad(side_coeffs + {i*13}, side, 9);")

    # GFX slider references
    mid_gfx_start = mid_start
    side_gfx_start = side_start

    jsfx = f"""desc:Matchering Realtime Master
//tags: mastering EQ limiter matchering
//author: Bryan + Claude

{chr(10).join(sliders)}

@init
  num_bands = {num_bands};
  mid_coeffs = 0;
  side_coeffs = {13 * num_bands};
  mid_freqs = {13 * num_bands * 2};
  side_freqs = {13 * num_bands * 2 + num_bands};

{chr(10).join(freq_inits)}

  // Peaking EQ biquad coefficient calculator
  function calc_peaking_eq(base, freq, gain_db, q)
    local(a, w0, alpha, a0)
  (
    a = 10 ^ (gain_db / 20);
    w0 = 2 * $pi * freq / srate;
    alpha = sin(w0) / (2 * q);

    a0 = 1 + alpha / a;
    base[0] = (1 + alpha * a) / a0;
    base[1] = (-2 * cos(w0)) / a0;
    base[2] = (1 - alpha * a) / a0;
    base[3] = (-2 * cos(w0)) / a0;
    base[4] = (1 - alpha / a) / a0;
  );

  // Biquad filter apply - state_offset is 5 for mid, 9 for side
  function apply_biquad(base, input, state_offset)
    local(output)
  (
    output = base[0] * input + base[1] * base[state_offset] + base[2] * base[state_offset+1]
           - base[3] * base[state_offset+2] - base[4] * base[state_offset+3];
    base[state_offset+1] = base[state_offset];
    base[state_offset] = input;
    base[state_offset+3] = base[state_offset+2];
    base[state_offset+2] = output;
    output;
  );

@slider
  master_gain = 10 ^ (slider1 / 20);
  dry_wet = slider2 / 100;
  limiter_on = slider3;
  limiter_thresh = 10 ^ (slider4 / 20);

{chr(10).join(mid_updates)}

{chr(10).join(side_updates)}

@sample
  dry_l = spl0;
  dry_r = spl1;

  // L/R to Mid/Side
  mid = (spl0 + spl1) * 0.5;
  side = (spl0 - spl1) * 0.5;

  // Mid EQ chain
{chr(10).join(mid_applies)}

  // Side EQ chain
{chr(10).join(side_applies)}

  // Master gain
  mid *= master_gain;
  side *= master_gain;

  // Mid/Side back to L/R
  wet_l = mid + side;
  wet_r = mid - side;

  // Brickwall limiter
  limiter_on ? (
    abs(wet_l) > limiter_thresh ? wet_l = sign(wet_l) * limiter_thresh;
    abs(wet_r) > limiter_thresh ? wet_r = sign(wet_r) * limiter_thresh;
  );

  // Dry/Wet
  spl0 = dry_l * (1 - dry_wet) + wet_l * dry_wet;
  spl1 = dry_r * (1 - dry_wet) + wet_r * dry_wet;

@gfx 600 300
  // Background
  gfx_r = 0.1; gfx_g = 0.1; gfx_b = 0.15;
  gfx_rect(0, 0, gfx_w, gfx_h);

  center_y = gfx_h * 0.5;

  // Grid lines
  gfx_r = 0.25; gfx_g = 0.25; gfx_b = 0.3;
  gfx_line(0, center_y, gfx_w, center_y);

  // +/-6dB lines
  gfx_r = 0.2; gfx_g = 0.2; gfx_b = 0.25;
  y6up = center_y - gfx_h * 0.25;
  y6dn = center_y + gfx_h * 0.25;
  gfx_line(0, y6up, gfx_w, y6up);
  gfx_line(0, y6dn, gfx_w, y6dn);

  // Frequency labels
  gfx_r = 0.3; gfx_g = 0.3; gfx_b = 0.35;
  gfx_x = log(100/20)/log(1000) * gfx_w; gfx_y = center_y + 2;
  gfx_drawstr("100");
  gfx_x = log(1000/20)/log(1000) * gfx_w; gfx_y = center_y + 2;
  gfx_drawstr("1k");
  gfx_x = log(10000/20)/log(1000) * gfx_w; gfx_y = center_y + 2;
  gfx_drawstr("10k");

  // dB labels
  gfx_x = gfx_w - 25; gfx_y = y6up - 5;
  gfx_drawstr("+6");
  gfx_x = gfx_w - 25; gfx_y = y6dn - 5;
  gfx_drawstr("-6");

  // Mid EQ curve (cyan)
  gfx_r = 0; gfx_g = 0.8; gfx_b = 0.9;
  i = 0;
  loop({num_bands},
    freq = mid_freqs[i];
    gain_db = slider({mid_gfx_start} + i);
    x = log(freq / 20) / log(20000 / 20) * gfx_w;
    y = center_y - gain_db * (gfx_h * 0.25 / 6);
    i > 0 ? gfx_lineto(x, y) : ( gfx_x = x; gfx_y = y; );
    gfx_circle(x, y, 4, 1);
    i += 1;
  );

  // Side EQ curve (orange)
  gfx_r = 0.9; gfx_g = 0.5; gfx_b = 0;
  i = 0;
  loop({num_bands},
    freq = side_freqs[i];
    gain_db = slider({side_gfx_start} + i);
    x = log(freq / 20) / log(20000 / 20) * gfx_w;
    y = center_y - gain_db * (gfx_h * 0.25 / 6);
    i > 0 ? gfx_lineto(x, y) : ( gfx_x = x; gfx_y = y; );
    gfx_circle(x, y, 3, 1);
    i += 1;
  );

  // Title
  gfx_r = 0.7; gfx_g = 0.7; gfx_b = 0.7;
  gfx_x = 5; gfx_y = 5;
  gfx_drawstr("MATCHERING REALTIME MASTER");

  // Legend
  gfx_x = 5; gfx_y = gfx_h - 18;
  gfx_r = 0; gfx_g = 0.8; gfx_b = 0.9;
  gfx_drawstr("Mid EQ  ");
  gfx_r = 0.9; gfx_g = 0.5; gfx_b = 0;
  gfx_drawstr("Side EQ");
"""

    with open(output_path, "w") as f:
        f.write(jsfx)

    print(f"JSFX written to: {output_path}")


def _freq_label(freq):
    if freq >= 1000:
        return f"{freq/1000:.1f}kHz"
    return f"{freq:.0f}Hz"


def main():
    if len(sys.argv) < 3:
        print("Usage: jsfx_generator.py <params.json> <output.jsfx>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        params = json.load(f)

    generate_jsfx(params, sys.argv[2])


if __name__ == "__main__":
    main()
