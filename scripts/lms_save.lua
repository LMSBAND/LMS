-- LMS Save Session
-- -----------------
-- Saves the current project's track names, fader state (vol/pan/mute/solo),
-- and full FX chains (all plugins + all params) to session.lms in the
-- project folder.
--
-- ALL tracks must be named. Unnamed tracks = error.
-- Load with lms_load.lua. Steal from another session with lms_steal.lua.
--
-- Install: Actions > Show Action List > New ReaScript > Load this file

-- ============================================================
-- JSON encoder (hand-rolled, no external deps)
-- ============================================================

local function json_encode(val, indent)
  indent = indent or 0
  local t = type(val)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    if val ~= val then return "null" end  -- NaN guard
    return string.format("%.6g", val)
  elseif t == "string" then
    -- Escape special characters
    val = val:gsub('\\', '\\\\')
    val = val:gsub('"', '\\"')
    val = val:gsub('\n', '\\n')
    val = val:gsub('\r', '\\r')
    val = val:gsub('\t', '\\t')
    return '"' .. val .. '"'
  elseif t == "table" then
    -- Check if array (consecutive integer keys from 1)
    local is_array = true
    local max_n = 0
    for k, _ in pairs(val) do
      if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
        is_array = false
        break
      end
      if k > max_n then max_n = k end
    end
    if is_array and max_n ~= #val then is_array = false end

    local pad = string.rep("  ", indent + 1)
    local close_pad = string.rep("  ", indent)

    if is_array then
      if #val == 0 then return "[]" end
      local parts = {}
      for _, v in ipairs(val) do
        parts[#parts + 1] = pad .. json_encode(v, indent + 1)
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. close_pad .. "]"
    else
      local parts = {}
      -- Sort keys for deterministic output
      local keys = {}
      for k in pairs(val) do keys[#keys + 1] = k end
      table.sort(keys)
      for _, k in ipairs(keys) do
        parts[#parts + 1] = pad .. json_encode(tostring(k)) .. ": " .. json_encode(val[k], indent + 1)
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close_pad .. "}"
    end
  end
  return "null"
end

-- ============================================================
-- Main
-- ============================================================

local function main()
  -- Require project to be saved — get directory of actual .rpp file
  local _, proj_file = reaper.EnumProjects(-1)
  if not proj_file or proj_file == "" then
    reaper.ShowMessageBox("Save your project first.", "LMS Save Session", 0)
    return
  end
  local proj_path = proj_file:match("(.+)[/\\]") or ""
  if proj_path == "" then
    reaper.ShowMessageBox("Save your project first.", "LMS Save Session", 0)
    return
  end

  local num_tracks = reaper.CountTracks(0)
  if num_tracks == 0 then
    reaper.ShowMessageBox("No tracks in project.", "LMS Save Session", 0)
    return
  end

  -- Validate: all tracks must be named
  local unnamed = {}
  for i = 0, num_tracks - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    -- REAPER default names are "Track N" — treat those as unnamed
    if not name or name == "" or name:match("^Track %d+$") then
      unnamed[#unnamed + 1] = "Track " .. (i + 1) .. " (index " .. i .. ")"
    end
  end

  if #unnamed > 0 then
    reaper.ShowMessageBox(
      "Organize your shit, that's the whole point.\n\nUnnamed tracks:\n" .. table.concat(unnamed, "\n"),
      "LMS Save Session", 0)
    return
  end

  -- Prompt for session name
  local retval, sname = reaper.GetUserInputs("LMS Save Session", 1, "Session name:,extrawidth=200", "session")
  if not retval then return end
  sname = sname:gsub("[^%w%-%_]", "_")  -- sanitize: only alphanumeric, dash, underscore
  if sname == "" then sname = "session" end

  -- Build session data
  local session = {
    lms_version = "1.0",
    created = os.date("%Y-%m-%dT%H:%M:%S"),
    session_name = proj_path:match("([^/\\]+)$") or "session",
    tracks = {}
  }

  for i = 0, num_tracks - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    local pan    = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
    local mute   = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") ~= 0
    local solo   = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") ~= 0

    local track_data = {
      name   = name,
      volume = volume,
      pan    = pan,
      mute   = mute,
      solo   = solo,
      fx     = {}
    }

    local fx_count = reaper.TrackFX_GetCount(track)
    for fi = 0, fx_count - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, fi, "")
      local param_count = reaper.TrackFX_GetNumParams(track, fi)
      local params = {}
      for pi = 0, param_count - 1 do
        local val = reaper.TrackFX_GetParam(track, fi, pi)
        params[#params + 1] = val
      end
      track_data.fx[#track_data.fx + 1] = {
        name   = fx_name,
        params = params
      }
    end

    session.tracks[#session.tracks + 1] = track_data
  end

  -- Write file
  local out_path = proj_path .. "/" .. sname .. ".lms"
  local f = io.open(out_path, "w")
  if not f then
    reaper.ShowMessageBox("Could not write to:\n" .. out_path, "LMS Save Session", 0)
    return
  end
  f:write(json_encode(session))
  f:write("\n")
  f:close()

  reaper.ShowMessageBox(
    "Saved " .. num_tracks .. " tracks to:\n" .. out_path,
    "LMS Save Session", 0)
end

main()
