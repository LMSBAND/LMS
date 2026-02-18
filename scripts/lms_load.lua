-- LMS Load Session
-- -----------------
-- Loads session.lms from the current project folder.
-- Replaces the FX chain on every track that matches by name.
-- Hard error if any .lms track is not found in the current project.
--
-- Save with lms_save.lua. Steal from another session with lms_steal.lua.
--
-- Install: Actions > Show Action List > New ReaScript > Load this file

-- ============================================================
-- Minimal JSON parser
-- Handles the exact structure lms_save.lua produces.
-- ============================================================

local function skip_ws(s, i)
  while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
  return i
end

local function parse_string(s, i)
  -- i points at opening "
  i = i + 1  -- skip "
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

local parse_value  -- forward decl

local function parse_array(s, i)
  i = i + 1  -- skip [
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
  i = i + 1  -- skip {
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
    -- Number
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
-- Apply a track's state from .lms data
-- ============================================================

local function apply_track(track, track_data)
  -- Faders
  reaper.SetMediaTrackInfo_Value(track, "D_VOL",  track_data.volume or 1.0)
  reaper.SetMediaTrackInfo_Value(track, "D_PAN",  track_data.pan    or 0.0)
  reaper.SetMediaTrackInfo_Value(track, "B_MUTE", track_data.mute   and 1 or 0)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", track_data.solo   and 1 or 0)

  -- Clear existing FX chain (delete backwards to keep indices valid)
  local existing = reaper.TrackFX_GetCount(track)
  for fi = existing - 1, 0, -1 do
    reaper.TrackFX_Delete(track, fi)
  end

  -- Add FX and set params
  for _, fx_data in ipairs(track_data.fx or {}) do
    local fi = reaper.TrackFX_AddByName(track, fx_data.name, false, -1)
    if fi >= 0 then
      for pi, val in ipairs(fx_data.params or {}) do
        reaper.TrackFX_SetParam(track, fi, pi - 1, val)
      end
    else
      reaper.ShowConsoleMsg("LMS Load: Could not add FX '" .. fx_data.name .. "' — plugin missing?\n")
    end
  end
end

-- ============================================================
-- Main
-- ============================================================

local function main()
  local proj_path = reaper.GetProjectPath("")
  if not proj_path or proj_path == "" then
    reaper.ShowMessageBox("Save your project first.", "LMS Load Session", 0)
    return
  end

  local lms_path = proj_path .. "/session.lms"
  local f = io.open(lms_path, "r")
  if not f then
    reaper.ShowMessageBox("No session.lms found in:\n" .. proj_path .. "\n\nSave one first with LMS Save Session.", "LMS Load Session", 0)
    return
  end
  local content = f:read("*a")
  f:close()

  local ok, session = pcall(json_decode, content)
  if not ok or type(session) ~= "table" then
    reaper.ShowMessageBox("Could not parse session.lms.\n\n" .. tostring(session), "LMS Load Session", 0)
    return
  end

  -- Build name → track map for current project
  local track_map = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    track_map[name] = track
  end

  -- Validate: all .lms tracks must exist in project
  local missing = {}
  for _, td in ipairs(session.tracks or {}) do
    if not track_map[td.name] then
      missing[#missing + 1] = td.name
    end
  end
  if #missing > 0 then
    reaper.ShowMessageBox(
      "These tracks from session.lms don't exist in the current project:\n\n" ..
      table.concat(missing, "\n") .. "\n\nAdd them or use LMS Steal Session instead.",
      "LMS Load Session", 0)
    return
  end

  -- Apply
  reaper.Undo_BeginBlock()
  for _, td in ipairs(session.tracks or {}) do
    apply_track(track_map[td.name], td)
  end
  reaper.Undo_EndBlock("LMS Load Session", -1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)

  reaper.ShowMessageBox(
    "Loaded " .. #(session.tracks or {}) .. " tracks from session.lms.",
    "LMS Load Session", 0)
end

main()
