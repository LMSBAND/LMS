#!/usr/bin/env python3
"""Measurement rig for the LMS suite.

Ears tell you what to investigate. This tells you whether the thing you heard
is the thing you think it is. It works on WAV files, so the loop is:

    1. python tools/lms_measure.py gen --sine 997        -> test_sine997.wav
    2. drop that on a track in REAPER, insert the plugin, render
    3. python tools/lms_measure.py thd rendered.wav --f0 997

Nothing here talks to REAPER. That is deliberate: a file you rendered is a
result you can keep, re-measure, and compare against next month's build.

WHY 997 Hz AND NOT 1000: 997 is prime-ish against every common sample rate,
so its harmonics and any aliases they fold back to land on different bins.
At 1000 Hz into 48 kHz, alias products stack neatly on top of real harmonics
and the distortion measurement flatters itself.

Commands
    gen       write test signals to feed REAPER
    null      A vs B, inverted and summed: what is left is what changed
    response  magnitude response from a rendered impulse
    decay     RT60 by Schroeder backward integration
    thd       harmonic distortion AND aliasing, reported separately
"""
import argparse, math, os, struct, sys, wave
import numpy as np


# ---------------------------------------------------------------- WAV I/O
# REAPER renders 32-bit float by default and Python's `wave` module refuses
# float formats, so the header gets parsed by hand.

def wav_read(path):
    """-> (samples float64 [n, channels], samplerate)"""
    with open(path, 'rb') as fh:
        raw = fh.read()
    if raw[:4] != b'RIFF' or raw[8:12] != b'WAVE':
        raise ValueError(f'{path}: not a RIFF/WAVE file')

    pos, fmt, data = 12, None, None
    while pos + 8 <= len(raw):
        cid = raw[pos:pos + 4]
        csz = struct.unpack('<I', raw[pos + 4:pos + 8])[0]
        body = raw[pos + 8:pos + 8 + csz]
        if cid == b'fmt ':
            fmt = body
        elif cid == b'data':
            data = body
        pos += 8 + csz + (csz & 1)          # chunks are word-aligned

    if fmt is None or data is None:
        raise ValueError(f'{path}: missing fmt or data chunk')

    tag, ch, sr, _, _, bits = struct.unpack('<HHIIHH', fmt[:16])
    if tag == 0xFFFE and len(fmt) >= 40:     # WAVE_FORMAT_EXTENSIBLE
        tag = struct.unpack('<H', fmt[24:26])[0]

    if tag == 3 and bits == 32:
        x = np.frombuffer(data, dtype='<f4').astype(np.float64)
    elif tag == 3 and bits == 64:
        x = np.frombuffer(data, dtype='<f8')
    elif tag == 1 and bits == 16:
        x = np.frombuffer(data, dtype='<i2').astype(np.float64) / 32768.0
    elif tag == 1 and bits == 32:
        x = np.frombuffer(data, dtype='<i4').astype(np.float64) / 2147483648.0
    elif tag == 1 and bits == 24:
        b = np.frombuffer(data, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float64) / 8388608.0
    else:
        raise ValueError(f'{path}: unsupported format tag {tag}, {bits}-bit')

    return x.reshape(-1, ch) if ch > 1 else x.reshape(-1, 1), sr


def wav_write(path, x, sr):
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = x.reshape(-1, 1)
    n, ch = x.shape
    payload = x.astype('<f4').tobytes()
    fmt = struct.pack('<HHIIHH', 3, ch, sr, sr * ch * 4, ch * 4, 32)
    with open(path, 'wb') as fh:
        fh.write(b'RIFF' + struct.pack('<I', 4 + 8 + len(fmt) + 8 + len(payload)) + b'WAVE')
        fh.write(b'fmt ' + struct.pack('<I', len(fmt)) + fmt)
        fh.write(b'data' + struct.pack('<I', len(payload)) + payload)


def mono(x):
    return x.mean(axis=1) if x.ndim > 1 and x.shape[1] > 1 else x.reshape(-1)


def db(v, floor=-200.0):
    v = np.asarray(v, dtype=np.float64)
    with np.errstate(divide='ignore'):
        out = 20.0 * np.log10(np.maximum(np.abs(v), 1e-30))
    return np.maximum(out, floor)


# ---------------------------------------------------------------- generate

def cmd_gen(a):
    sr, secs = a.rate, a.seconds
    n = int(sr * secs)
    t = np.arange(n) / sr
    amp = 10 ** (a.level / 20.0)

    if a.impulse:
        x = np.zeros(n)
        x[int(sr * 0.1)] = amp            # 100 ms in, so the tail has room
        name = f'test_impulse_{a.level:+.0f}dB'
    elif a.sweep:
        # Exponential sweep: constant energy per octave, and the harmonic
        # distortion products separate cleanly in the deconvolved response.
        f1, f2 = 20.0, min(20000.0, sr * 0.45)
        k = math.log(f2 / f1)
        x = amp * np.sin(2 * np.pi * f1 * secs / k * (np.exp(t / secs * k) - 1))
        x *= np.minimum(1, np.minimum(t / 0.02, (secs - t) / 0.05))   # de-click
        name = f'test_sweep_{a.level:+.0f}dB'
    elif a.silence:
        x = np.zeros(n)
        name = 'test_silence'
    else:
        f0 = a.sine
        x = amp * np.sin(2 * np.pi * f0 * t)
        x *= np.minimum(1, np.minimum(t / 0.02, (secs - t) / 0.02))
        name = f'test_sine{f0:g}_{a.level:+.0f}dB'

    out = a.out or f'{name}.wav'
    wav_write(out, np.column_stack([x, x]), sr)
    print(f'  wrote {out}  ({secs:g}s, {sr} Hz, stereo, peak {a.level:+.1f} dBFS)')
    print(f'  render this through the plugin, then measure the result')


# ---------------------------------------------------------------- null test

def cmd_null(a):
    """Invert one against the other. What survives is exactly what changed.

    Plugins delay, so the residual is minimised over an integer-sample shift
    first -- otherwise a latency of one sample reads as a huge difference and
    tells you nothing about the processing.
    """
    A, sr_a = wav_read(a.a)
    B, sr_b = wav_read(a.b)
    if sr_a != sr_b:
        sys.exit(f'sample rates differ: {sr_a} vs {sr_b}')
    x, y = mono(A), mono(B)
    n = min(len(x), len(y))
    x, y = x[:n], y[:n]

    best = (None, None)
    for shift in range(-a.max_shift, a.max_shift + 1):
        yy = np.roll(y, -shift)
        m = slice(a.max_shift, n - a.max_shift)
        r = x[m] - yy[m]
        rms = math.sqrt(float(np.mean(r * r))) if len(r) else 1.0
        if best[0] is None or rms < best[0]:
            best = (rms, shift, r)

    rms, shift, resid = best
    ref = math.sqrt(float(np.mean(x[a.max_shift:n - a.max_shift] ** 2)))
    print(f'  aligned at {shift:+d} sample(s)')
    print(f'  reference RMS   {db(ref):8.2f} dBFS')
    print(f'  residual RMS    {db(rms):8.2f} dBFS')
    print(f'  residual peak   {db(np.max(np.abs(resid))):8.2f} dBFS')
    print(f'  suppression     {db(ref) - db(rms):8.2f} dB')
    if db(ref) - db(rms) > 100:
        print('  -> identical. If you expected a difference, the plugin did nothing.')
    elif db(ref) - db(rms) > 40:
        print('  -> subtle: a real but small change')
    else:
        print('  -> substantial processing')


# ---------------------------------------------------------------- response

def cmd_response(a):
    """Magnitude response from a rendered impulse.

    Point this at a cab, and the 8-band table it was built from should be
    readable straight off the curve.
    """
    X, sr = wav_read(a.file)
    x = mono(X)
    peak = int(np.argmax(np.abs(x)))
    x = x[max(0, peak - 64):]
    nfft = 1 << int(math.ceil(math.log2(max(len(x), 4096))))
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x)) if a.window else x, nfft))
    freqs = np.fft.rfftfreq(nfft, 1 / sr)

    ref = np.max(mag)
    print(f'  {len(x)} samples, {sr} Hz, {nfft}-point FFT')
    print(f'  {"Hz":>9}  {"dB":>8}')
    for f in [20, 31.5, 50, 80, 125, 200, 315, 500, 800, 1250,
              2000, 3150, 5000, 8000, 12500, 16000, 20000]:
        if f >= sr / 2:
            break
        i = int(round(f / (sr / nfft)))
        print(f'  {f:>9g}  {db(mag[i] / ref):8.2f}')
    if a.csv:
        with open(a.csv, 'w') as fh:
            fh.write('hz,db\n')
            for f, m in zip(freqs, db(mag / ref)):
                if 10 <= f <= sr / 2:
                    fh.write(f'{f:.3f},{m:.4f}\n')
        print(f'  full curve -> {a.csv}')


# ---------------------------------------------------------------- decay

def cmd_decay(a):
    """RT60 by Schroeder backward integration.

    Black In Bluhm computes an RT60 from room geometry and materials and then
    builds an FDN it HOPES realises it. This measures what the FDN actually
    does, which is a falsifiable prediction the code already makes.
    """
    X, sr = wav_read(a.file)
    x = mono(X)
    x = x[int(np.argmax(np.abs(x))):]
    e = x * x
    sch = np.cumsum(e[::-1])[::-1]                      # backward integral
    sch = 10 * np.log10(np.maximum(sch / sch[0], 1e-30))

    def t_between(hi, lo):
        try:
            i0 = int(np.argmax(sch <= hi))
            i1 = int(np.argmax(sch <= lo))
        except ValueError:
            return None
        if i1 <= i0:
            return None
        slope = (sch[i1] - sch[i0]) / ((i1 - i0) / sr)   # dB per second
        return -60.0 / slope if slope < 0 else None

    t20, t30 = t_between(-5, -25), t_between(-5, -35)
    print(f'  {len(x)/sr:.2f}s of decay at {sr} Hz')
    print(f'  T20 -> RT60   {t20:.3f} s' if t20 else '  T20 unavailable (decay too short)')
    print(f'  T30 -> RT60   {t30:.3f} s' if t30 else '  T30 unavailable (decay too short)')
    if a.expect and t30:
        err = (t30 - a.expect) / a.expect * 100
        print(f'  predicted     {a.expect:.3f} s   -> {err:+.1f}% error')


# ---------------------------------------------------------------- thd/alias

def cmd_thd(a):
    """Harmonic distortion and aliasing, counted separately.

    This is the one that answers "is ADAA earning its keep". A nonlinearity
    makes harmonics; those above Nyquist fold back to frequencies that are NOT
    multiples of f0. So: energy on multiples of f0 is harmonic distortion and
    is the point. Everything else above the noise floor is alias, and is not.
    """
    X, sr = wav_read(a.file)
    x = mono(X)
    # Trim fades, then take a power-of-two block from the steady middle.
    n = 1 << int(math.floor(math.log2(len(x) * 0.6)))
    start = (len(x) - n) // 2
    seg = x[start:start + n]
    # 4-term Blackman-Harris: -92 dB sidelobes. A plain Blackman leaks its
    # -58 dB skirt into the unclaimed bins, and against a fundamental this
    # strong that leakage gets counted as aliasing -- it reported 0.17% on a
    # synthetic signal containing none.
    k = np.arange(n) * (2 * np.pi / n)
    w = (0.35875 - 0.48829 * np.cos(k) + 0.14128 * np.cos(2 * k)
         - 0.01168 * np.cos(3 * k))
    mag = np.abs(np.fft.rfft(seg * w))
    bin_hz = sr / n

    f0 = a.f0
    def band(f, halfwidth=6):        # wide enough for the BH4 main lobe
        i = int(round(f / bin_hz))
        lo, hi = max(0, i - halfwidth), min(len(mag), i + halfwidth + 1)
        return float(np.sum(mag[lo:hi] ** 2)), lo, hi

    fund_e, flo, fhi = band(f0)
    claimed = np.zeros(len(mag), dtype=bool)
    claimed[flo:fhi] = True

    harm_e, harm_rows = 0.0, []
    k = 2
    while k * f0 < sr / 2:
        e, lo, hi = band(k * f0)
        claimed[lo:hi] = True
        harm_e += e
        harm_rows.append((k, k * f0, e))
        k += 1

    total_e = float(np.sum(mag ** 2))
    alias_e = max(0.0, total_e - fund_e - harm_e)

    # Noise floor: median of everything unclaimed, so a genuinely quiet
    # render is not reported as full of aliasing.
    rest = mag[~claimed]
    floor_e = float(np.median(rest) ** 2 * len(rest)) if len(rest) else 0.0
    alias_e = max(0.0, alias_e - floor_e)

    thd = math.sqrt(harm_e / fund_e) * 100 if fund_e > 0 else 0.0
    alias_pct = math.sqrt(alias_e / fund_e) * 100 if fund_e > 0 else 0.0

    print(f'  f0 {f0:g} Hz, {sr} Hz, {n}-point FFT ({bin_hz:.2f} Hz/bin)')
    print(f'  fundamental      {db(math.sqrt(fund_e)):8.2f} dB')
    print(f'  THD              {thd:8.3f} %   ({db(thd/100):.1f} dB)')
    print(f'  aliasing / IMD   {alias_pct:8.3f} %   ({db(alias_pct/100):.1f} dB)')
    if thd > 0 and alias_pct > 0:
        print(f'  harmonic : alias {db(thd/100) - db(alias_pct/100):+.1f} dB '
              f'(higher is cleaner -- distortion where you asked for it)')
    print()
    print(f'  {"harmonic":>9} {"Hz":>10} {"dB rel f0":>11}')
    for k, f, e in harm_rows[:12]:
        if e > 0 and db(math.sqrt(e / fund_e)) > -140:
            print(f'  {k:>9} {f:>10.1f} {db(math.sqrt(e / fund_e)):>11.2f}')


# ---------------------------------------------------------------- main

def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)

    g = sub.add_parser('gen', help='write a test signal to render through REAPER')
    g.add_argument('--sine', type=float, default=997.0, help='sine frequency (default 997)')
    g.add_argument('--impulse', action='store_true')
    g.add_argument('--sweep', action='store_true')
    g.add_argument('--silence', action='store_true')
    g.add_argument('--level', type=float, default=-6.0, help='dBFS peak (default -6)')
    g.add_argument('--seconds', type=float, default=4.0)
    g.add_argument('--rate', type=int, default=48000)
    g.add_argument('--out')
    g.set_defaults(func=cmd_gen)

    n = sub.add_parser('null', help='A vs B: what is left is what changed')
    n.add_argument('a'); n.add_argument('b')
    n.add_argument('--max-shift', type=int, default=512, help='latency search, samples')
    n.set_defaults(func=cmd_null)

    r = sub.add_parser('response', help='magnitude response from a rendered impulse')
    r.add_argument('file')
    r.add_argument('--csv', help='write the full curve here')
    r.add_argument('--window', action='store_true', help='window before the FFT')
    r.set_defaults(func=cmd_response)

    d = sub.add_parser('decay', help='RT60 from a rendered impulse')
    d.add_argument('file')
    d.add_argument('--expect', type=float, help='predicted RT60 in seconds, to compare')
    d.set_defaults(func=cmd_decay)

    t = sub.add_parser('thd', help='harmonic distortion and aliasing, separately')
    t.add_argument('file')
    t.add_argument('--f0', type=float, default=997.0)
    t.set_defaults(func=cmd_thd)

    a = p.parse_args()
    a.func(a)


if __name__ == '__main__':
    main()
