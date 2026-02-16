-- DRUMBANGER: Background Sampling Service
-- -----------------------------------------
-- Runs as a persistent background action via defer().
-- Monitors gmem[3] for sample requests from DrumBox16.
-- When triggered, captures audio from the arrange view
-- (including the track's FX chain) and loads it onto
-- the requested DRUMBANGER pad instantly.
--
-- IMPORTANT: This script must be running for the SAMPLE
-- button inside DrumBox16 to work. Start it once per session.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Recommended: Set as a startup action so it runs automatically.
--
-- gmem protocol (namespace "DrumBanger"):
--   gmem[3] = 1   JSFX → Lua: sample request
--   gmem[4]        JSFX → Lua: target pad (0-15)
--   gmem[5]        Lua → JSFX: status (0=idle, 1=sampling, 2=done, 3=error)
--   gmem[6]        Lua → JSFX: heartbeat (increments each frame)

local GMEM_NAME      = "DrumBanger"
local MAX_DURATION    = 5.0       -- DrumBox16 buffer limit (seconds)
local SAMPLE_RATE     = 48000
local NUM_CHANNELS    = 2
local MAX_WAIT_CYCLES = 300       -- ~5 seconds at 60fps defer rate

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

-- ---- Write WAV and signal DRUMBANGER ----

local function write_wav_and_finish(state)
  local srate = SAMPLE_RATE
  local nch   = NUM_CHANNELS
  local bps   = 16
  local byte_rate   = srate * nch * bps / 8
  local block_align = nch * bps / 8
  local data_size   = state.num_samples * nch * bps / 8

  local f = io.open(state.filepath, "wb")
  if not f then
    reaper.ShowConsoleMsg("DRUMBANGER SERVICE: Failed to create file: " .. state.filepath .. "\n")
    reaper.DestroyAudioAccessor(state.accessor)
    reaper.gmem_write(5, 3)  -- error
    return false
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

  -- Warn if captured audio is silent
  if peak < 0.0001 then
    reaper.ShowConsoleMsg(
      "DRUMBANGER SERVICE: WARNING — captured audio appears silent!\n"..
      "  Make sure the track has rendered audio in the selected region.\n"..
      "  For MIDI/VSTi tracks: play the region first so REAPER caches it,\n"..
      "  or bounce/freeze the track, then try again.\n")
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

  -- Signal DrumBox16 via gmem (existing rescan + auto-load protocol)
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(1, new_idx)   -- pool index of new sample
  reaper.gmem_write(2, 1)         -- auto-load onto selected pad
  reaper.gmem_write(0, 1)         -- rescan signal (set last!)
  reaper.gmem_write(5, 2)         -- status = done

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER SERVICE: Sampled %.2fs from '%s' -> %s (peak: %.4f)\n",
      state.duration, state.track_name, state.filename, peak))

  return true
end

-- ---- Service state ----

local heartbeat = 0
local sampling_state = nil   -- nil when idle, table when sampling

-- ---- Async accessor wait (called each defer tick while sampling) ----

local function check_accessor()
  local state = sampling_state
  local changed = reaper.AudioAccessorStateChanged(state.accessor)
  if changed then
    reaper.AudioAccessorUpdate(state.accessor)
  end

  state.wait_count = state.wait_count + 1

  if changed and state.wait_count < MAX_WAIT_CYCLES then
    return false  -- still rendering, check again next tick
  end

  if state.wait_count >= MAX_WAIT_CYCLES then
    reaper.ShowConsoleMsg("DRUMBANGER SERVICE: Accessor wait timed out, reading anyway...\n")
  end

  write_wav_and_finish(state)
  sampling_state = nil
  return true
end

-- ---- Start sampling (gather parameters, create accessor) ----

local function start_sampling()
  local target_pad = math.floor(reaper.gmem_read(4))

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
    reaper.ShowConsoleMsg("DRUMBANGER SERVICE: No selection or item found — nothing to sample\n")
    reaper.gmem_write(5, 3)  -- error
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

  -- Generate filename
  local timestamp = os.time()
  local safe_name = track_name:gsub("[^%w%-_]", "_"):sub(1, 20)
  local filename = string.format("samp_%s_%d.wav", safe_name, timestamp)
  local manifest_entry = "sampled/" .. filename
  local filepath = sampled_dir .. "/" .. filename

  local num_samples = math.floor(duration * SAMPLE_RATE)

  -- Create audio accessor and start async wait
  local accessor = reaper.CreateTrackAudioAccessor(track)
  reaper.AudioAccessorUpdate(accessor)

  sampling_state = {
    accessor       = accessor,
    start_time     = start_time,
    end_time       = end_time,
    duration       = duration,
    num_samples    = num_samples,
    track_name     = track_name,
    pool_dir       = pool_dir,
    filename       = filename,
    manifest_entry = manifest_entry,
    filepath       = filepath,
    wait_count     = 0,
    target_pad     = target_pad,
  }

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER SERVICE: Sampling %.2fs from '%s' (pad %d)...\n",
      duration, track_name, target_pad + 1))
end

-- ---- Main tick (runs every defer frame) ----

local function tick()
  reaper.gmem_attach(GMEM_NAME)

  -- Heartbeat: let JSFX know we're alive
  heartbeat = heartbeat + 1
  if heartbeat > 1000000 then heartbeat = 0 end
  reaper.gmem_write(6, heartbeat)

  -- Check for sample request (only when idle)
  if sampling_state == nil then
    local req = reaper.gmem_read(3)
    if req == 1 then
      reaper.gmem_write(3, 0)   -- acknowledge immediately
      reaper.gmem_write(5, 1)   -- status = sampling
      start_sampling()
    end
  end

  -- Continue sampling if in progress
  if sampling_state then
    check_accessor()
  end

  reaper.defer(tick)
end

-- ---- Startup ----

reaper.gmem_attach(GMEM_NAME)
reaper.gmem_write(5, 0)   -- clear status
reaper.gmem_write(3, 0)   -- clear any stale request
reaper.ShowConsoleMsg("DRUMBANGER SERVICE: Started. SAMPLE button in DrumBox16 is now active.\n")
tick()
