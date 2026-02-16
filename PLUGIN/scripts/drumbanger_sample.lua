-- DRUMBANGER: Sample from Arrange
-- --------------------------------
-- Captures the current time selection into DrumBox16's sample pool.
-- Select a track first, or it samples the master bus.
-- The new sample auto-loads onto the selected pad in DrumBox16.
--
-- How to use:
-- 1. Make a time selection (drag on timeline ruler) or select a media item
-- 2. (Optional) Select a track — defaults to master bus
-- 3. Run this script from Actions > Show Action List
-- 4. The sample appears on the selected pad in DrumBox16 instantly
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for instant sampling.

local GMEM_NAME  = "DrumBanger"
local MAX_DURATION = 5.0     -- DrumBox16 buffer limit (seconds)
local SAMPLE_RATE  = 48000
local NUM_CHANNELS = 2
local MAX_WAIT_CYCLES = 300  -- ~5 seconds at 60fps defer rate

-- ---- WAV helpers (little-endian) ----

local function write_u16(f, val)
  f:write(string.char(val % 256, math.floor(val / 256) % 256))
end

local function write_u32(f, val)
  f:write(string.char(
    val % 256,
    math.floor(val / 256) % 256,
    math.floor(val / 65536) % 256,
    math.floor(val / 16777216) % 256))
end

local function write_i16(f, val)
  if val < 0 then val = val + 65536 end
  f:write(string.char(val % 256, math.floor(val / 256) % 256))
end

-- ---- Recursive pool scan and manifest rebuild ----

local function scan_dir(base_dir, rel_prefix, results)
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(base_dir, i)
    if not fname then break end
    if fname:lower():match("%.wav$") then
      if rel_prefix == "" then
        results[#results + 1] = fname
      else
        results[#results + 1] = rel_prefix .. "/" .. fname
      end
    end
    i = i + 1
  end
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(base_dir, j)
    if not dirname then break end
    local new_prefix = rel_prefix == "" and dirname or (rel_prefix .. "/" .. dirname)
    scan_dir(base_dir .. "/" .. dirname, new_prefix, results)
    j = j + 1
  end
end

local function update_manifest(pool_dir)
  local results = {}
  scan_dir(pool_dir, "", results)
  table.sort(results)

  local f = io.open(pool_dir .. "/manifest.txt", "w")
  if f then
    for _, entry in ipairs(results) do
      f:write(entry .. "\n")
    end
    f:close()
  end
  return results
end

-- ---- Write WAV and finish ----

local function write_wav_and_finish(state)
  local srate = SAMPLE_RATE
  local nch   = NUM_CHANNELS
  local bps   = 16
  local byte_rate   = srate * nch * bps / 8
  local block_align = nch * bps / 8
  local data_size   = state.num_samples * nch * bps / 8

  local f = io.open(state.filepath, "wb")
  if not f then
    reaper.ShowMessageBox("Failed to create file:\n" .. state.filepath, "DRUMBANGER", 0)
    reaper.DestroyAudioAccessor(state.accessor)
    return
  end

  -- RIFF header
  f:write("RIFF")
  write_u32(f, 36 + data_size)
  f:write("WAVE")

  -- fmt chunk
  f:write("fmt ")
  write_u32(f, 16)
  write_u16(f, 1)            -- PCM
  write_u16(f, nch)
  write_u32(f, srate)
  write_u32(f, byte_rate)
  write_u16(f, block_align)
  write_u16(f, bps)

  -- data chunk header
  f:write("data")
  write_u32(f, data_size)

  -- Read audio and write PCM
  local chunk_size = 8192
  local pos = state.start_time
  local remaining = state.num_samples
  local peak = 0

  while remaining > 0 do
    local to_read = math.min(chunk_size, remaining)
    local buf = reaper.new_array(to_read * nch)
    buf.clear()
    reaper.GetAudioAccessorSamples(state.accessor, srate, nch, pos, to_read, buf)

    for i = 1, to_read * nch do
      local s = buf[i]
      local a = math.abs(s)
      if a > peak then peak = a end
      if s > 1.0 then s = 1.0 elseif s < -1.0 then s = -1.0 end
      write_i16(f, math.floor(s * 32767 + 0.5))
    end

    pos = pos + to_read / srate
    remaining = remaining - to_read
  end

  reaper.DestroyAudioAccessor(state.accessor)
  f:close()

  -- Check if we captured actual audio
  if peak < 0.0001 then
    reaper.ShowConsoleMsg(
      "DRUMBANGER WARNING: Captured audio appears silent!\n"..
      "  Make sure the track has rendered audio in the selected region.\n"..
      "  For MIDI/VSTi tracks: play the region first so REAPER caches it,\n"..
      "  or bounce/freeze the track, then run this action again.\n")
  end

  -- Update manifest and find new sample index
  local wav_list = update_manifest(state.pool_dir)
  local new_idx = -1
  for i, name in ipairs(wav_list) do
    if name == state.manifest_entry then
      new_idx = i - 1   -- 0-based index for JSFX
      break
    end
  end

  -- Signal DrumBox16 via gmem
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(1, new_idx)   -- pool index of new sample
  reaper.gmem_write(2, 1)         -- auto-load onto selected pad
  reaper.gmem_write(0, 1)         -- rescan signal (set last!)

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Sampled %.2fs from '%s' -> %s (peak: %.4f)\n",
      state.duration, state.track_name, state.filename, peak))
end

-- ---- Async wait loop: yields to REAPER event loop via defer ----

local function wait_for_accessor(state)
  -- Check if accessor data has settled (no longer changing)
  local changed = reaper.AudioAccessorStateChanged(state.accessor)
  if changed then
    reaper.AudioAccessorUpdate(state.accessor)
  end

  state.wait_count = state.wait_count + 1

  if changed and state.wait_count < MAX_WAIT_CYCLES then
    -- Still rendering — yield back to REAPER and check again next frame
    reaper.defer(function() wait_for_accessor(state) end)
  else
    -- Either settled or timed out — read the audio now
    if state.wait_count >= MAX_WAIT_CYCLES then
      reaper.ShowConsoleMsg("DRUMBANGER: Accessor wait timed out, reading anyway...\n")
    end
    write_wav_and_finish(state)
  end
end

-- ---- Main: gather parameters, create accessor, start async wait ----

local function main()
  -- Get time selection
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  -- Fallback: use selected media item bounds
  if end_time - start_time < 0.001 then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      start_time = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      end_time   = start_time + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    end
  end

  if end_time - start_time < 0.001 then
    reaper.ShowMessageBox(
      "No selection found!\n\n"..
      "Either:\n"..
      "- Drag on the TIMELINE RULER to make a time selection\n"..
      "- Or click a media item to select it\n\n"..
      "Then run this action again.",
      "DRUMBANGER", 0)
    return
  end

  -- Cap duration
  local duration = math.min(end_time - start_time, MAX_DURATION)
  if end_time - start_time > MAX_DURATION then
    end_time = start_time + MAX_DURATION
  end

  -- Get track to sample from
  local track = reaper.GetSelectedTrack(0, 0)
  local track_name
  if track then
    _, track_name = reaper.GetTrackName(track)
  else
    track = reaper.GetMasterTrack(0)
    track_name = "Master"
  end

  -- Determine pool path
  local resource_path = reaper.GetResourcePath()
  local pool_dir = resource_path .. "/Effects/DrumBox16/pool"
  local sampled_dir = pool_dir .. "/sampled"
  reaper.RecursiveCreateDirectory(sampled_dir, 0)

  -- Generate filename (saved into pool/sampled/ subfolder)
  local timestamp = os.time()
  local safe_name = track_name:gsub("[^%w%-_]", "_"):sub(1, 20)
  local filename = string.format("samp_%s_%d.wav", safe_name, timestamp)
  local manifest_entry = "sampled/" .. filename
  local filepath = sampled_dir .. "/" .. filename

  local num_samples = math.floor(duration * SAMPLE_RATE)

  -- Create audio accessor and kick off async rendering
  local accessor = reaper.CreateTrackAudioAccessor(track)
  reaper.AudioAccessorUpdate(accessor)

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Sampling %.2fs from '%s'... please wait.\n",
      duration, track_name))

  -- Bundle all state for the async callbacks
  local state = {
    accessor    = accessor,
    start_time  = start_time,
    end_time    = end_time,
    duration    = duration,
    num_samples = num_samples,
    track_name  = track_name,
    pool_dir    = pool_dir,
    filename    = filename,
    manifest_entry = manifest_entry,
    filepath    = filepath,
    wait_count  = 0,
  }

  -- Yield to REAPER's event loop so the accessor can actually render audio
  reaper.defer(function() wait_for_accessor(state) end)
end

main()
