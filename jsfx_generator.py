#!/usr/bin/env python3
"""
JSFX Generator - creates a real-time Reaper plugin from matchering analysis params.
Reads the JSON output from matchering_analyzer.py and generates a .jsfx file
that does FFT convolution with the exact FIR filters matchering computed,
plus post-tweak controls.

FIR coefficients are stored in an external data file to avoid JSFX code size limits.
"""

import sys
import os
import json


def generate_jsfx(params, output_path):
    mid_fir = params["mid_fir"]
    side_fir = params["side_fir"]
    fir_len = params["fir_length"]
    rms_gain = params["rms_gain_db"]

    # FFT size must be >= chunk_size + fir_length - 1
    fft_size = 8192
    chunk_size = 4096

    # Write FIR coefficients to a data file next to the JSFX
    # Format: one value per line, mid coefficients first, then side
    data_dir = os.path.dirname(output_path)
    data_filename = "matchering_fir_data.txt"
    data_path = os.path.join(data_dir, data_filename)

    with open(data_path, "w") as f:
        for v in mid_fir:
            f.write(f"{v:.15e}\n")
        for v in side_fir:
            f.write(f"{v:.15e}\n")

    print(f"FIR data written to: {data_path}")

    jsfx = f"""desc:Matchering Realtime Master (FIR Convolution)
//tags: mastering EQ limiter matchering convolution
//author: Bryan + Claude

filename:0,{data_filename}

slider1:{rms_gain:.2f}<-20,20,0.1>Master Gain (dB)
slider2:100<0,100,1>Dry/Wet (%)
slider3:1<0,1,1{{Off,On}}>Limiter
slider4:-0.01<-6,0,0.01>Limiter Threshold (dB)
slider5:0<-6,6,0.1>Low Tweak (dB)
slider6:0<-6,6,0.1>Mid Tweak (dB)
slider7:0<-6,6,0.1>High Tweak (dB)
slider8:500<100,2000,1>Mid Freq (Hz)

@init
  fir_len = {fir_len};
  fft_size = {fft_size};
  chunk_size = {chunk_size};

  // Memory pointers - all FFT buffers within first 65536 block
  mid_fir_fft = 0;           // 0..8191
  side_fir_fft = 8192;       // 8192..16383
  // Double-buffer input
  input_buf_l0 = 16384;      // 16384..20479
  input_buf_r0 = 20480;      // 20480..24575
  input_buf_l1 = 24576;      // 24576..28671
  input_buf_r1 = 28672;      // 28672..32767
  work_buf_mid = 32768;      // 32768..40959
  work_buf_side = 40960;     // 40960..49151
  overlap_mid = 49152;       // 49152..53247
  overlap_side = 53248;      // 53248..57343
  output_buf_l = 57344;      // 57344..61439
  output_buf_r = 61440;      // 61440..65535

  buf_pos = 0;
  output_ready = 0;
  cur_input_l = input_buf_l0;
  cur_input_r = input_buf_r0;

  // Initialize slider-derived values (in case @slider hasn't run yet)
  master_gain = 10 ^ ({rms_gain:.2f} / 20);
  dry_wet = 1.0;
  limiter_on = 1;
  limiter_thresh = 10 ^ (-0.01 / 20);

  // --- Load FIR coefficients from data file ---
  // Clear both FFT buffers
  i = 0;
  loop(fft_size,
    mid_fir_fft[i] = 0;
    side_fir_fft[i] = 0;
    i += 1;
  );

  // Read mid FIR (first fir_len values) and side FIR (next fir_len values)
  fh = file_open(0);
  fh >= 0 ? (
    file_mem(fh, mid_fir_fft, fir_len);
    file_mem(fh, side_fir_fft, fir_len);
    file_close(fh);
  );

  // FFT both FIRs in place
  fft_real(mid_fir_fft, fft_size);
  fft_real(side_fir_fft, fft_size);

  // Clear overlap buffers
  i = 0;
  loop(fir_len,
    overlap_mid[i] = 0;
    overlap_side[i] = 0;
    i += 1;
  );

  // Clear output buffers
  i = 0;
  loop(chunk_size,
    output_buf_l[i] = 0;
    output_buf_r[i] = 0;
    i += 1;
  );

  // Post-tweak biquad state
  ls_b0 = 0; ls_b1 = 0; ls_b2 = 0; ls_a1 = 0; ls_a2 = 0;
  ls_xl1 = 0; ls_xl2 = 0; ls_yl1 = 0; ls_yl2 = 0;
  ls_xr1 = 0; ls_xr2 = 0; ls_yr1 = 0; ls_yr2 = 0;
  hs_b0 = 0; hs_b1 = 0; hs_b2 = 0; hs_a1 = 0; hs_a2 = 0;
  hs_xl1 = 0; hs_xl2 = 0; hs_yl1 = 0; hs_yl2 = 0;
  hs_xr1 = 0; hs_xr2 = 0; hs_yr1 = 0; hs_yr2 = 0;
  mp_b0 = 0; mp_b1 = 0; mp_b2 = 0; mp_a1 = 0; mp_a2 = 0;
  mp_xl1 = 0; mp_xl2 = 0; mp_yl1 = 0; mp_yl2 = 0;
  mp_xr1 = 0; mp_xr2 = 0; mp_yr1 = 0; mp_yr2 = 0;

  // Report latency to REAPER for PDC
  pdc_delay = chunk_size;
  pdc_bot_ch = 0;
  pdc_top_ch = 2;

  function calc_low_shelf(freq, gain_db)
    local(a, w0, cs, sn, alpha, ap1, am1, beta, a0_inv)
  (
    a = 10 ^ (gain_db / 40);
    w0 = 2 * $pi * freq / srate;
    cs = cos(w0); sn = sin(w0);
    alpha = sn / (2 * 0.707);
    ap1 = a + 1; am1 = a - 1;
    beta = 2 * sqrt(a) * alpha;
    a0_inv = 1 / (ap1 + am1 * cs + beta);
    ls_b0 = a * (ap1 - am1 * cs + beta) * a0_inv;
    ls_b1 = 2 * a * (am1 - ap1 * cs) * a0_inv;
    ls_b2 = a * (ap1 - am1 * cs - beta) * a0_inv;
    ls_a1 = -2 * (am1 + ap1 * cs) * a0_inv;
    ls_a2 = (ap1 + am1 * cs - beta) * a0_inv;
  );

  function calc_high_shelf(freq, gain_db)
    local(a, w0, cs, sn, alpha, ap1, am1, beta, a0_inv)
  (
    a = 10 ^ (gain_db / 40);
    w0 = 2 * $pi * freq / srate;
    cs = cos(w0); sn = sin(w0);
    alpha = sn / (2 * 0.707);
    ap1 = a + 1; am1 = a - 1;
    beta = 2 * sqrt(a) * alpha;
    a0_inv = 1 / (ap1 - am1 * cs + beta);
    hs_b0 = a * (ap1 + am1 * cs + beta) * a0_inv;
    hs_b1 = -2 * a * (am1 + ap1 * cs) * a0_inv;
    hs_b2 = a * (ap1 + am1 * cs - beta) * a0_inv;
    hs_a1 = 2 * (am1 - ap1 * cs) * a0_inv;
    hs_a2 = (ap1 - am1 * cs - beta) * a0_inv;
  );

  function calc_mid_peak(freq, gain_db, q)
    local(a, w0, alpha, a0_inv)
  (
    a = 10 ^ (gain_db / 20);
    w0 = 2 * $pi * freq / srate;
    alpha = sin(w0) / (2 * q);
    a0_inv = 1 / (1 + alpha / a);
    mp_b0 = (1 + alpha * a) * a0_inv;
    mp_b1 = (-2 * cos(w0)) * a0_inv;
    mp_b2 = (1 - alpha * a) * a0_inv;
    mp_a1 = (-2 * cos(w0)) * a0_inv;
    mp_a2 = (1 - alpha / a) * a0_inv;
  );

@slider
  master_gain = 10 ^ (slider1 / 20);
  dry_wet = slider2 / 100;
  limiter_on = slider3;
  limiter_thresh = 10 ^ (slider4 / 20);

  // Post-tweak EQ
  low_gain = slider5;
  mid_gain = slider6;
  high_gain = slider7;
  mid_freq = slider8;

  calc_low_shelf(200, low_gain);
  calc_high_shelf(8000, high_gain);
  calc_mid_peak(mid_freq, mid_gain, 0.7);

@sample
  // Store input samples into current input buffer
  cur_input_l[buf_pos] = spl0;
  cur_input_r[buf_pos] = spl1;

  // Output from previous processed block
  output_ready ? (
    spl0 = output_buf_l[buf_pos];
    spl1 = output_buf_r[buf_pos];
  ) : (
    spl0 = 0;
    spl1 = 0;
  );

  buf_pos += 1;

  // When we have a full chunk, process it
  buf_pos >= chunk_size ? (
    buf_pos = 0;

    // Swap input buffers: process the one we just filled,
    // start filling the other one
    proc_l = cur_input_l;
    proc_r = cur_input_r;
    cur_input_l == input_buf_l0 ? (
      cur_input_l = input_buf_l1;
      cur_input_r = input_buf_r1;
    ) : (
      cur_input_l = input_buf_l0;
      cur_input_r = input_buf_r0;
    );

    // Convert L/R to Mid/Side
    i = 0;
    loop(chunk_size,
      l = proc_l[i];
      r = proc_r[i];
      work_buf_mid[i] = (l + r) * 0.5;
      work_buf_side[i] = (l - r) * 0.5;
      i += 1;
    );

    // Zero-pad to fft_size
    i = chunk_size;
    loop(fft_size - chunk_size,
      work_buf_mid[i] = 0;
      work_buf_side[i] = 0;
      i += 1;
    );

    // FFT the mid and side chunks
    fft_real(work_buf_mid, fft_size);
    fft_real(work_buf_side, fft_size);

    // Convolve with pre-computed FIR FFTs
    convolve_c(work_buf_mid, mid_fir_fft, fft_size / 2);
    convolve_c(work_buf_side, side_fir_fft, fft_size / 2);

    // IFFT back to time domain
    ifft_real(work_buf_mid, fft_size);
    ifft_real(work_buf_side, fft_size);

    // Scale by 1/fft_size and overlap-add
    scale = 1 / fft_size;
    i = 0;

    // First part: add overlap from previous block
    loop(fir_len - 1,
      m = work_buf_mid[i] * scale + overlap_mid[i];
      s = work_buf_side[i] * scale + overlap_side[i];
      i < chunk_size ? (
        // Convert M/S back to L/R, apply master gain
        output_buf_l[i] = (m + s) * master_gain;
        output_buf_r[i] = (m - s) * master_gain;
      );
      i += 1;
    );

    // Middle part: no overlap needed (only if chunk_size > fir_len-1)
    loop(chunk_size - (fir_len - 1),
      m = work_buf_mid[i] * scale;
      s = work_buf_side[i] * scale;
      output_buf_l[i] = (m + s) * master_gain;
      output_buf_r[i] = (m - s) * master_gain;
      i += 1;
    );

    // Save the tail for overlap-add next block
    j = 0;
    loop(fir_len - 1,
      overlap_mid[j] = work_buf_mid[chunk_size + j] * scale;
      overlap_side[j] = work_buf_side[chunk_size + j] * scale;
      j += 1;
    );

    output_ready = 1;

    // Apply post-tweak EQ and dry/wet to output buffer
    i = 0;
    loop(chunk_size,
      wet_l = output_buf_l[i];
      wet_r = output_buf_r[i];

      // Low shelf
      abs(low_gain) > 0.05 ? (
        ol = ls_b0 * wet_l + ls_b1 * ls_xl1 + ls_b2 * ls_xl2 - ls_a1 * ls_yl1 - ls_a2 * ls_yl2;
        ls_xl2 = ls_xl1; ls_xl1 = wet_l; ls_yl2 = ls_yl1; ls_yl1 = ol;
        wet_l = ol;
        ol = ls_b0 * wet_r + ls_b1 * ls_xr1 + ls_b2 * ls_xr2 - ls_a1 * ls_yr1 - ls_a2 * ls_yr2;
        ls_xr2 = ls_xr1; ls_xr1 = wet_r; ls_yr2 = ls_yr1; ls_yr1 = ol;
        wet_r = ol;
      );

      // Mid peak
      abs(mid_gain) > 0.05 ? (
        ol = mp_b0 * wet_l + mp_b1 * mp_xl1 + mp_b2 * mp_xl2 - mp_a1 * mp_yl1 - mp_a2 * mp_yl2;
        mp_xl2 = mp_xl1; mp_xl1 = wet_l; mp_yl2 = mp_yl1; mp_yl1 = ol;
        wet_l = ol;
        ol = mp_b0 * wet_r + mp_b1 * mp_xr1 + mp_b2 * mp_xr2 - mp_a1 * mp_yr1 - mp_a2 * mp_yr2;
        mp_xr2 = mp_xr1; mp_xr1 = wet_r; mp_yr2 = mp_yr1; mp_yr1 = ol;
        wet_r = ol;
      );

      // High shelf
      abs(high_gain) > 0.05 ? (
        ol = hs_b0 * wet_l + hs_b1 * hs_xl1 + hs_b2 * hs_xl2 - hs_a1 * hs_yl1 - hs_a2 * hs_yl2;
        hs_xl2 = hs_xl1; hs_xl1 = wet_l; hs_yl2 = hs_yl1; hs_yl1 = ol;
        wet_l = ol;
        ol = hs_b0 * wet_r + hs_b1 * hs_xr1 + hs_b2 * hs_xr2 - hs_a1 * hs_yr1 - hs_a2 * hs_yr2;
        hs_xr2 = hs_xr1; hs_xr1 = wet_r; hs_yr2 = hs_yr1; hs_yr1 = ol;
        wet_r = ol;
      );

      // Limiter
      limiter_on ? (
        abs(wet_l) > limiter_thresh ? wet_l = sign(wet_l) * limiter_thresh;
        abs(wet_r) > limiter_thresh ? wet_r = sign(wet_r) * limiter_thresh;
      );

      // Dry/wet mix (dry from the just-processed input buffer)
      output_buf_l[i] = proc_l[i] * (1 - dry_wet) + wet_l * dry_wet;
      output_buf_r[i] = proc_r[i] * (1 - dry_wet) + wet_r * dry_wet;

      i += 1;
    );
  );

@gfx 500 200
  // Background
  gfx_r = 0.08; gfx_g = 0.08; gfx_b = 0.12;
  gfx_rect(0, 0, gfx_w, gfx_h);

  // Title
  gfx_r = 0.7; gfx_g = 0.7; gfx_b = 0.8;
  gfx_x = 10; gfx_y = 8;
  gfx_drawstr("MATCHERING REALTIME MASTER");

  // Subtitle
  gfx_r = 0.4; gfx_g = 0.4; gfx_b = 0.5;
  gfx_x = 10; gfx_y = 24;
  gfx_drawstr("FIR Convolution - {fir_len} taps");

  // Status
  gfx_x = 10; gfx_y = 44;
  output_ready ? (
    gfx_r = 0.2; gfx_g = 0.8; gfx_b = 0.3;
    gfx_drawstr("Active");
  ) : (
    gfx_r = 0.8; gfx_g = 0.3; gfx_b = 0.2;
    gfx_drawstr("Buffering...");
  );

  // Post-tweak indicator
  gfx_r = 0.5; gfx_g = 0.5; gfx_b = 0.6;
  gfx_x = 10; gfx_y = 70;
  gfx_drawstr("Post EQ: ");
  abs(low_gain) > 0.05 || abs(mid_gain) > 0.05 || abs(high_gain) > 0.05 ? (
    gfx_r = 0.9; gfx_g = 0.6; gfx_b = 0.2;
    gfx_drawstr("ON");
  ) : (
    gfx_r = 0.3; gfx_g = 0.3; gfx_b = 0.4;
    gfx_drawstr("Flat");
  );

  // Gain meter
  gfx_r = 0.3; gfx_g = 0.3; gfx_b = 0.4;
  gfx_x = 10; gfx_y = 90;
  gfx_drawstr("Master: ");
  gfx_r = 0.6; gfx_g = 0.8; gfx_b = 0.9;
  gfx_drawnumber(slider1, 1);
  gfx_drawstr(" dB");
"""

    with open(output_path, "w") as f:
        f.write(jsfx)

    print(f"JSFX written to: {output_path}")
    print(f"FIR length: {fir_len} taps, FFT size: {fft_size}")
    print(f"Latency: {chunk_size} samples ({chunk_size/44100*1000:.1f}ms at 44.1kHz)")


def main():
    if len(sys.argv) < 3:
        print("Usage: jsfx_generator.py <params.json> <output.jsfx>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        params = json.load(f)

    generate_jsfx(params, sys.argv[2])


if __name__ == "__main__":
    main()
