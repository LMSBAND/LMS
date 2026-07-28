# Bibliography

Every source the suite draws on, one entry per key. Code cites a key with a
`@cite` line at the point of use:

    // @cite huovilainen-2004 -- nonlinear ladder, per-stage tanh

`tools/cite_audit.py` collects those, fails on a key that is not in this file,
and regenerates `CITATIONS.md`. So a citation lives next to the code that
depends on it and cannot quietly drift away from it.

**Status column:** `confirmed` means the code demonstrably implements what the
source describes — the coefficients or the structure match. `unverified` means
the technique is clearly present but I have not established which paper the
implementation actually came from. Bryan wrote this DSP; the unverified rows
need his memory, not my guess, and should be corrected or dropped rather than
left to look authoritative.

---

## Filters

**`stilson-smith-1996`** — `unverified`
Tim Stilson and Julius O. Smith, *Analyzing the Moog VCF with Considerations
for Digital Implementation*, CCRMA, Stanford University, 1996.
<https://ccrma.stanford.edu/~stilti/papers/moogvcf.pdf>
Used by: the ladder cutoff-compensation polynomials in `lms_lil_stinker.jsfx`
and `lms_nuug420.jsfx` (`kfcr`, `kacr` — the 1.8730 / 0.4955 / 0.6490 and
-3.9364 / 1.8409 fits).

**`huovilainen-2004`** — `confirmed`
Antti Huovilainen, *Non-linear digital implementation of the Moog ladder
filter*, Proc. DAFx-04, Naples, 2004.
Used by: the 4-stage ladder with a `tanh` saturator inside every stage and in
the feedback path, 2x oversampled — `lms_nuug420.jsfx`, `lms_lil_stinker.jsfx`.
Named in those files already.

**`rbj-cookbook`** — `unverified`
Robert Bristow-Johnson, *Cookbook formulae for audio EQ biquad filter
coefficients*.
<https://www.w3.org/TR/audio-eq-cookbook/>
Used by: `lms_bq_set_*` in `lms_core.jsfx-inc` — lowpass, highpass, bandpass,
peaking, and both shelves.

## Oscillators

**`valimaki-huovilainen-2007`** — `unverified`
Vesa Välimäki and Antti Huovilainen, *Antialiasing Oscillators in Subtractive
Synthesis*, IEEE Signal Processing Magazine 24(2), 2007.
Used by: the `polyblep()` correction on saw and square in `lms_nuug420.jsfx`
and `lms_lil_stinker.jsfx`. PolyBLEP is named in both; which paper it was taken
from is not recorded.

## Reverb

**`schroeder-1962`** — `unverified`
M. R. Schroeder, *Natural Sounding Artificial Reverberation*, JAES 10(3), 1962.
Used by: the allpass diffusion chains in `lms_core.jsfx-inc` — spring reverb
and the diffusion stages. Schroeder is named at those sites.

**`jot-chaigne-1991`** — `unverified`
Jean-Marc Jot and Antoine Chaigne, *Digital Delay Networks for Designing
Artificial Reverberators*, AES 90th Convention, 1991.
Used by: `lms_hall` in `lms_core.jsfx-inc` — 4 delay lines with Householder
unitary mixing; and the 8-line FDN in `lms_reverb.jsfx`.

## Pitch detection

**`decheveigne-kawahara-2002`** — `confirmed`
Alain de Cheveigné and Hideki Kawahara, *YIN, a fundamental frequency estimator
for speech and music*, JASA 111(4), 2002.
Used by: the YIN tracker in `lms_pitch_detector.jsfx` and `lms_faker.jsfx` —
difference function, cumulative mean normalisation, absolute threshold,
parabolic interpolation. Named in both.

## Antialiasing

**`parker-zavalishin-lebivic-2016`** — `unverified`
Julian Parker, Vadim Zavalishin and Efflam Le Bivic, *Reducing the Aliasing of
Nonlinear Waveshaping Using Continuous-Time Convolution*, Proc. DAFx-16, 2016.
Used by: `lms_adaa_eval` in `lms_core.jsfx-inc`. ADAA is named there.

---

## Samples

**`tr808-fischer`** — `confirmed`
Edward Loveall, TR-808 sample set, `tidalcycles/sounds-tr808-fischer`.
<https://github.com/tidalcycles/sounds-tr808-fischer> — CC0 1.0, licence file
present in the repository.

**`tmkd-vortex`** — `confirmed`
The Metal Kick Drum, *TMKD-VORTEX Free Pack*.
<https://themetalkickdrum.com/>
Licence: sharing permitted and encouraged, credit required, resale in another
format prohibited. Not currently redistributed with the suite.
