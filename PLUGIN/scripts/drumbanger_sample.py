"""
DRUMBANGER: Sample from Arrange
--------------------------------
Captures the current time selection into DrumBox16's sample pool.
Select a track first, or it samples the master bus.
The new sample auto-loads onto the selected pad in DrumBox16.

How to use:
1. Make a time selection in REAPER's arrange view
   (drag on the timeline ruler, or select a media item)
2. (Optional) Select a track — defaults to master bus
3. Run this script from Actions > Show Action List
4. The sample appears on the selected pad in DrumBox16 instantly

Install: Actions > Show Action List > New Action > Load ReaScript
Assign a keyboard shortcut for instant sampling.
"""

import os
import struct
import time

# reaper module provides new_array(), gmem_attach/read/write, defer, etc.
# It's injected by REAPER's Python environment but needs explicit import.
import reaper

GMEM_NAME = "DrumBanger"
MAX_DURATION = 5.0    # DrumBox16 buffer limit (seconds)
SAMPLE_RATE = 48000
NUM_CHANNELS = 2
BITS = 16


def write_wav(filepath, samples, srate, nch, num_frames):
    """Write interleaved float samples as 16-bit PCM WAV."""
    bps = BITS
    byte_rate = srate * nch * bps // 8
    block_align = nch * bps // 8
    data_size = num_frames * nch * bps // 8

    with open(filepath, 'wb') as f:
        # RIFF header
        f.write(b'RIFF')
        f.write(struct.pack('<I', 36 + data_size))
        f.write(b'WAVE')

        # fmt chunk
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16))
        f.write(struct.pack('<H', 1))         # PCM
        f.write(struct.pack('<H', nch))
        f.write(struct.pack('<I', srate))
        f.write(struct.pack('<I', byte_rate))
        f.write(struct.pack('<H', block_align))
        f.write(struct.pack('<H', bps))

        # data chunk
        f.write(b'data')
        f.write(struct.pack('<I', data_size))

        # Convert float samples to 16-bit signed PCM
        scale = 32767
        for s in samples:
            s = max(-1.0, min(1.0, s))
            f.write(struct.pack('<h', int(s * scale)))


def update_manifest(pool_dir):
    """Regenerate pool/manifest.txt from wav files in directory."""
    wav_files = sorted(
        f for f in os.listdir(pool_dir)
        if f.lower().endswith('.wav')
    )
    manifest_path = os.path.join(pool_dir, "manifest.txt")
    with open(manifest_path, 'w') as f:
        for wav in wav_files:
            f.write(wav + '\n')
    return wav_files


def main():
    # ---- Get time selection ----
    (_, _, start, end, _) = RPR_GetSet_LoopTimeRange(False, False, 0.0, 0.0, False)

    # Fallback: if no time selection, use selected media item bounds
    if end - start < 0.001:
        item = RPR_GetSelectedMediaItem(0, 0)
        if item:
            start = RPR_GetMediaItemInfo_Value(item, "D_POSITION")
            end = start + RPR_GetMediaItemInfo_Value(item, "D_LENGTH")

    if end - start < 0.001:
        RPR_ShowMessageBox(
            "No selection found!\n\n"
            "Either:\n"
            "- Drag on the TIMELINE RULER to make a time selection\n"
            "- Or click a media item to select it\n\n"
            "Then run this action again.",
            "DRUMBANGER", 0
        )
        return

    # Cap duration
    duration = min(end - start, MAX_DURATION)
    if end - start > MAX_DURATION:
        end = start + MAX_DURATION

    # ---- Get track to sample from ----
    track = RPR_GetSelectedTrack(0, 0)
    if track:
        (_, _, track_name, _) = RPR_GetTrackName(track, "", 256)
    else:
        track = RPR_GetMasterTrack(0)
        track_name = "Master"

    # ---- Read audio via AudioAccessor ----
    accessor = RPR_CreateTrackAudioAccessor(track)
    srate = SAMPLE_RATE
    nch = NUM_CHANNELS
    num_samples = int(duration * srate)

    # Read in chunks to avoid huge single buffer
    chunk_size = 8192
    all_samples = []
    pos = start
    remaining = num_samples

    while remaining > 0:
        to_read = min(chunk_size, remaining)
        buf = reaper.new_array(to_read * nch)
        RPR_GetAudioAccessorSamples(accessor, srate, nch, pos, to_read, buf.cfunc())
        for i in range(to_read * nch):
            all_samples.append(buf[i])
        pos += to_read / srate
        remaining -= to_read

    RPR_DestroyAudioAccessor(accessor)

    # ---- Determine pool path ----
    resource_path = RPR_GetResourcePath()
    pool_dir = os.path.join(resource_path, "Effects", "DrumBox16", "pool")
    if not os.path.exists(pool_dir):
        os.makedirs(pool_dir)

    # ---- Generate filename ----
    timestamp = int(time.time())
    # Clean track name for filename
    safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in track_name)
    safe_name = safe_name[:20]  # keep it short for the POOL menu
    filename = "samp_{}_{}.wav".format(safe_name, timestamp)
    filepath = os.path.join(pool_dir, filename)

    # ---- Write WAV ----
    write_wav(filepath, all_samples, srate, nch, num_samples)

    # ---- Update manifest and find new sample index ----
    wav_list = update_manifest(pool_dir)
    new_idx = wav_list.index(filename) if filename in wav_list else -1

    # ---- Signal DrumBox16 via gmem ----
    reaper.gmem_attach(GMEM_NAME)
    reaper.gmem_write(1, new_idx)    # pool index of new sample
    reaper.gmem_write(2, 1)          # auto-load onto selected pad
    reaper.gmem_write(0, 1)          # rescan signal (set last!)

    RPR_ShowConsoleMsg(
        "DRUMBANGER: Sampled {:.2f}s from '{}' -> {}\n".format(
            duration, track_name, filename
        )
    )


main()
