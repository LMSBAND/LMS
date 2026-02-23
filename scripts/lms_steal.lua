-- LMS Steal Session
-- ------------------
-- Opens a file picker to select any session.lms from any project.
-- For each track in the .lms file:
--   - If the track NAME exists in the current project: replace its FX chain
--   - If it DOESN'T exist: add it as a new track at the end
--
-- This lets you carry your mix from one song into another.
-- New tracks bring everything. Existing tracks get fully updated.
--
-- Save with lms_save.lua. Load exact match with lms_load.lua.
--
-- Install: Actions > Show Action List > New ReaScript > Load this file

-- ============================================================
-- Minimal JSON parser (same as lms_load.lua)
-- ============================================================

local function skip_ws(s, i)
  while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
  return i
end

local function parse_string(s, i)
  i = i + 1
  local buf = {}
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(buf), i + 1
    elseif c == '\\' then
      i = i + 1
      local e = s:sub(i, i)
      if     e == '"'  then buf[#buf+1] = '"'
      elseif e == '\\' then buf[#buf+1] = '\\'
      elseif e == 'n'  then buf[#buf+1] = '\n'
      elseif e == 'r'  then buf[#buf+1] = '\r'
      elseif e == 't'  then buf[#buf+1] = '\t'
      else                   buf[#buf+1] = e
      end
    else
      buf[#buf+1] = c
    end
    i = i + 1
  end
  error("Unterminated string")
end

local parse_value

local function parse_array(s, i)
  i = i + 1
  local arr = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == ']' then return arr, i + 1 end
  while true do
    local val
    val, i = parse_value(s, i)
    arr[#arr+1] = val
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == ']' then return arr, i + 1 end
    if c ~= ',' then error("Expected , or ] in array at " .. i) end
    i = i + 1
    i = skip_ws(s, i)
  end
end

local function parse_object(s, i)
  i = i + 1
  local obj = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == '}' then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    local key
    key, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ':' then error("Expected : in object") end
    i = i + 1
    local val
    val, i = parse_value(s, i)
    obj[key] = val
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == '}' then return obj, i + 1 end
    if c ~= ',' then error("Expected , or } in object at " .. i) end
    i = i + 1
  end
end

parse_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == '"' then
    return parse_string(s, i)
  elseif c == '{' then
    return parse_object(s, i)
  elseif c == '[' then
    return parse_array(s, i)
  elseif c == 't' then
    return true, i + 4
  elseif c == 'f' then
    return false, i + 5
  elseif c == 'n' then
    return nil, i + 4
  else
    local num_str = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if not num_str then error("Unexpected character at " .. i .. ": " .. c) end
    return tonumber(num_str), i + #num_str
  end
end

local function json_decode(s)
  local val, _ = parse_value(s, 1)
  return val
end

-- ============================================================
-- Apply track state (shared with load logic)
-- ============================================================

local function apply_track(track, track_data)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL",  track_data.volume or 1.0)
  reaper.SetMediaTrackInfo_Value(track, "D_PAN",  track_data.pan    or 0.0)
  reaper.SetMediaTrackInfo_Value(track, "B_MUTE", track_data.mute   and 1 or 0)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", track_data.solo   and 1 or 0)

  local existing = reaper.TrackFX_GetCount(track)
  for fi = existing - 1, 0, -1 do
    reaper.TrackFX_Delete(track, fi)
  end

  for _, fx_data in ipairs(track_data.fx or {}) do
    local fi = reaper.TrackFX_AddByName(track, fx_data.name, false, -1)
    if fi >= 0 then
      reaper.TrackFX_Show(track, fi, 2)  -- 2 = hide floating window
      for pi, val in ipairs(fx_data.params or {}) do
        reaper.TrackFX_SetParam(track, fi, pi - 1, val)
      end
    else
      reaper.ShowConsoleMsg("LMS Steal: Could not add FX '" .. fx_data.name .. "' — plugin missing?\n")
    end
  end
end

-- ============================================================
-- Main
-- ============================================================

local function main()
  -- Pick the source .lms file — start in project directory if available
  local start_dir = ""
  local _, proj_file = reaper.EnumProjects(-1)
  if proj_file and proj_file ~= "" then
    start_dir = proj_file:match("(.+)[/\\]") or ""
  end
  local retval, lms_path = reaper.GetUserFileNameForRead(start_dir, "Steal session from...", "*.lms")
  if not retval or lms_path == "" then return end

  local f = io.open(lms_path, "r")
  if not f then
    reaper.ShowMessageBox("Could not open:\n" .. lms_path, "LMS Steal Session", 0)
    return
  end
  local content = f:read("*a")
  f:close()

  local ok, session = pcall(json_decode, content)
  if not ok or type(session) ~= "table" then
    reaper.ShowMessageBox("Could not parse session file.\n\n" .. tostring(session), "LMS Steal Session", 0)
    return
  end

  -- Build name → track map for current project
  local track_map = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    track_map[name] = track
  end

  -- Process each track from the stolen session
  local updated = 0
  local added   = 0
  local skipped = {}

  reaper.Undo_BeginBlock()

  for _, td in ipairs(session.tracks or {}) do
    local name = td.name
    if not name or name == "" or name:match("^Track %d+$") then
      skipped[#skipped + 1] = "(unnamed track)"
    elseif track_map[name] then
      -- Exists in current project — update it
      apply_track(track_map[name], td)
      updated = updated + 1
    else
      -- New track — add at end
      local idx = reaper.CountTracks(0)
      reaper.InsertTrackAtIndex(idx, true)
      local new_track = reaper.GetTrack(0, idx)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", name, true)
      apply_track(new_track, td)
      added = added + 1
    end
  end

  reaper.Undo_EndBlock("LMS Steal Session", -1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)

  local msg = string.format("Updated %d track%s. Added %d new track%s.",
    updated, updated == 1 and "" or "s",
    added,   added   == 1 and "" or "s")

  if #skipped > 0 then
    msg = msg .. "\n\nSkipped (unnamed in source):\n" .. table.concat(skipped, "\n")
  end

  reaper.ShowMessageBox(msg, "LMS Steal Session", 0)
end

main()
