#!/usr/bin/env python3
"""
Matchering Analyzer - extracts DSP parameters for real-time JSFX plugin.
Called by the ReaScript as a subprocess.

Hooks into matchering's internals to capture:
- FIR filter coefficients (mid + side) for exact convolution
- RMS gain coefficient
- Limiter settings

Outputs a JSON file with all the parameters + generates a JSFX plugin.
"""

import sys
import os
import json
import numpy as np
import matchering as mg
from matchering.stage_helpers.match_frequencies import get_fir, __average_fft, __smooth_exponentially
from matchering.stage_helpers.match_levels import get_rms_c_and_amplify_pair
from matchering import defaults

# We'll store captured data here
captured = {
    "mid_fir": None,
    "side_fir": None,
    "mid_matching_fft": None,
    "side_matching_fft": None,
    "rms_gain_db": None,
    "sample_rate": 44100,
    "fft_size": 4096,
}


def _patched_get_fir(target_loudest_pieces, reference_loudest_pieces, name, config):
    """Monkey-patched get_fir that captures the FIR coefficients."""
    from matchering.log import debug
    from scipy import signal

    debug(f"Calculating the {name} FIR for the matching EQ...")

    target_average_fft = __average_fft(
        target_loudest_pieces, config.internal_sample_rate, config.fft_size
    )
    reference_average_fft = __average_fft(
        reference_loudest_pieces, config.internal_sample_rate, config.fft_size
    )

    np.maximum(config.min_value, target_average_fft, out=target_average_fft)
    matching_fft = reference_average_fft / target_average_fft

    matching_fft_filtered = __smooth_exponentially(matching_fft, config)

    # Capture the frequency response curve
    captured[f"{name}_matching_fft"] = matching_fft_filtered.tolist()
    captured["sample_rate"] = config.internal_sample_rate
    captured["fft_size"] = config.fft_size

    fir = np.fft.irfft(matching_fft_filtered)
    fir = np.fft.ifftshift(fir) * signal.windows.hann(len(fir))

    # Capture the actual FIR coefficients
    captured[f"{name}_fir"] = fir.tolist()

    return fir


def _patched_get_rms_c(array_main, array_additional, array_main_match_rms,
                        reference_match_rms, epsilon, name):
    """Monkey-patched to capture the initial RMS coefficient."""
    from matchering.dsp import amplify
    from matchering.log import debug
    from matchering.utils import to_db

    name_upper = name.upper()
    rms_coefficient = reference_match_rms / max(epsilon, array_main_match_rms)
    debug(f"The RMS coefficient is: {to_db(rms_coefficient)}")

    # Only capture the first (target) RMS coefficient
    if name == "target" and captured["rms_gain_db"] is None:
        captured["rms_gain_db"] = float(20 * np.log10(max(1e-10, rms_coefficient)))

    debug(f"Modifying the amplitudes of the {name_upper} audio...")
    array_main = amplify(array_main, rms_coefficient)
    array_additional = amplify(array_additional, rms_coefficient)

    return rms_coefficient, array_main, array_additional


def main():
    if len(sys.argv) < 4:
        print("Usage: matchering_analyzer.py <target> <reference> <output_json>", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1]
    reference = sys.argv[2]
    output_json = sys.argv[3]

    for f in [target, reference]:
        if not os.path.isfile(f):
            print(f"File not found: {f}", file=sys.stderr)
            sys.exit(1)

    # Monkey-patch matchering to capture intermediate values
    import matchering.stage_helpers as sh
    sh.get_fir = _patched_get_fir

    import matchering.stages as stages
    # Patch at the module level where it's imported
    stages.get_fir = _patched_get_fir
    stages.get_rms_c_and_amplify_pair = _patched_get_rms_c

    mg.log(print)

    # We still run the full process to get accurate results,
    # but our patches capture the intermediate values
    # Use a temp output just to make matchering happy
    temp_output = output_json.replace(".json", "_temp_analysis.wav")

    try:
        mg.process(
            target=target,
            reference=reference,
            results=[mg.pcm24(temp_output)],
        )
    finally:
        # Clean up temp file
        if os.path.isfile(temp_output):
            os.remove(temp_output)

    if not captured["mid_fir"]:
        print("WARNING: Could not capture FIR coefficients!", file=sys.stderr)
        sys.exit(1)

    fir_len = len(captured["mid_fir"])
    print(f"Captured FIR length: {fir_len} samples")

    # Build output
    params = {
        "mid_fir": captured["mid_fir"],
        "side_fir": captured["side_fir"],
        "fir_length": fir_len,
        "rms_gain_db": captured["rms_gain_db"] or 0.0,
        "limiter": {
            "attack_ms": 1.0,
            "hold_ms": 1.0,
            "release_ms": 3000.0,
            "threshold_db": -0.01,
        },
        "sample_rate": captured["sample_rate"],
        "fft_size": captured["fft_size"],
    }

    with open(output_json, "w") as f:
        json.dump(params, f)

    print(f"Parameters saved to: {output_json}")
    print(f"RMS gain: {params['rms_gain_db']:.2f} dB")
    print(f"FIR length: {fir_len} taps")


if __name__ == "__main__":
    main()
