-- LMS Steal Session
-- ------------------
-- Opens a file picker to select any session.lms from any project.
-- For each track in the .lms file:
--   1. Exact name match in current project → replace FX chain + faders
--   2. Unmatched tracks → show both orphan lists (source + project)
--   3. If mappable tracks exist → manual mapping dialog (up to 16 at a time)
--   4. Anything still unmatched → "Add as new tracks? Yes/No"
--
-- This lets you carry your mix from one song into another.
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

local function apply_track(track, track_data, restore_folders)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL",  track_data.volume or 1.0)
  reaper.SetMediaTrackInfo_Value(track, "D_PAN",  track_data.pan    or 0.0)
  reaper.SetMediaTrackInfo_Value(track, "B_MUTE", track_data.mute   and 1 or 0)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", track_data.solo   and 1 or 0)

  -- Folder structure — only during load, never during steal
  -- (steal applies to tracks in a different order, folder depth would corrupt the layout)
  if restore_folders and track_data.folder_depth then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", track_data.folder_depth)
  end

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
  -- Pick the source .lms file — start in project directory
  local start_dir = reaper.GetProjectPath("") or ""
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

  -- ============================================================
  -- Phase 1: Exact name match
  -- ============================================================

  local matched   = {}
  local unmatched_lms = {}
  local skipped   = {}
  local matched_names = {}  -- project names claimed by exact match

  for _, td in ipairs(session.tracks or {}) do
    local name = td.name
    if not name or name == "" or name:match("^Track %d+$") then
      skipped[#skipped + 1] = "(unnamed track)"
    elseif track_map[name] then
      matched[#matched + 1] = td
      matched_names[name] = true
    else
      unmatched_lms[#unmatched_lms + 1] = td
    end
  end

  -- Find project tracks not claimed by any exact match
  local unclaimed_project = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    if not matched_names[name]
       and not (name:match("^Track %d+$"))
       and name ~= "" then
      unclaimed_project[#unclaimed_project + 1] = name
    end
  end

  -- ============================================================
  -- Phase 2: Manual mapping (if both sides have orphans)
  -- ============================================================

  local manual_mapped = {}  -- { td = track_data, project_track = track_ref, rename = string }

  if #unmatched_lms > 0 and #unclaimed_project > 0 then
    -- Build numbered reference list for the info dialog
    local ref_lines = {}
    for i, name in ipairs(unclaimed_project) do
      ref_lines[#ref_lines + 1] = string.format("  (%d) %s", i, name)
    end

    local lms_lines = {}
    for _, td in ipairs(unmatched_lms) do
      lms_lines[#lms_lines + 1] = "  " .. td.name
    end

    local info = string.format(
      "%d matched automatically.\n\n"
      .. "SOURCE tracks not in project:\n%s\n\n"
      .. "PROJECT tracks (numbered):\n%s\n\n"
      .. "Map them manually? Type the number to assign.",
      #matched,
      table.concat(lms_lines, "\n"),
      table.concat(ref_lines, "\n"))

    -- 3 = Yes/No/Cancel
    local choice = reaper.ShowMessageBox(info, "LMS Steal — Track Mapping", 3)

    if choice == 2 then  -- Cancel
      reaper.ShowMessageBox("No changes made.", "LMS Steal Session", 0)
      return
    end

    if choice == 6 then  -- Yes — show mapping dialog(s)
      -- Print numbered reference to console so it stays visible during input
      reaper.ClearConsole()
      reaper.ShowConsoleMsg("=== PROJECT TRACKS — type the number to map ===\n")
      for i, name in ipairs(unclaimed_project) do
        reaper.ShowConsoleMsg(string.format("  (%d) %s\n", i, name))
      end
      reaper.ShowConsoleMsg("================================================\n")

      local batch_start = 1
      while batch_start <= #unmatched_lms do
        local batch_end = math.min(batch_start + 15, #unmatched_lms)
        local batch_size = batch_end - batch_start + 1

        local captions = {}
        local defaults = {}
        for i = batch_start, batch_end do
          local safe = unmatched_lms[i].name:gsub(",", ";")
          captions[#captions + 1] = safe
          defaults[#defaults + 1] = ""
        end
        -- extrawidth only works on the last caption entry
        captions[#captions] = captions[#captions] .. ",extrawidth=100"

        local title = "Type # to map (see console for list)"
        if #unmatched_lms > 16 then
          title = title .. string.format(" [%d-%d of %d]", batch_start, batch_end, #unmatched_lms)
        end

        local ret, vals = reaper.GetUserInputs(
          title, batch_size,
          table.concat(captions, ","),
          table.concat(defaults, ","))

        if not ret then break end  -- user cancelled this batch

        -- Parse comma-separated return values
        local val_list = {}
        for v in (vals .. ","):gmatch("(.-),") do
          val_list[#val_list + 1] = v
        end

        for i = 1, batch_size do
          local typed = val_list[i]
          if typed and typed ~= "" then
            local num = tonumber(typed:match("^%s*(%d+)%s*$"))
            local lms_idx = batch_start + i - 1
            if num and num >= 1 and num <= #unclaimed_project then
              local project_name = unclaimed_project[num]
              if track_map[project_name] then
                manual_mapped[#manual_mapped + 1] = {
                  td = unmatched_lms[lms_idx],
                  project_track = track_map[project_name],
                  rename = unmatched_lms[lms_idx].name
                }
                unmatched_lms[lms_idx].mapped = true
              end
            else
              reaper.ShowConsoleMsg(
                "LMS Steal: '" .. unmatched_lms[lms_idx].name
                .. "' — invalid number '" .. typed .. "', skipping\n")
            end
          end
        end

        batch_start = batch_end + 1
      end
    end
    -- choice == 7 (No) = skip mapping, fall through
  end

  -- Collect still-unmatched (not mapped, not skipped)
  local still_unmatched = {}
  for _, td in ipairs(unmatched_lms) do
    if not td.mapped then
      still_unmatched[#still_unmatched + 1] = td
    end
  end

  -- ============================================================
  -- Phase 3: Offer to add remaining unmatched as new tracks
  -- ============================================================

  local add_new = false
  if #still_unmatched > 0 then
    local names = {}
    for _, td in ipairs(still_unmatched) do
      names[#names + 1] = td.name
    end

    local proceed = reaper.ShowMessageBox(
      #still_unmatched .. " track(s) still unmatched:\n\n"
      .. table.concat(names, "\n")
      .. "\n\nAdd these as new tracks?",
      "LMS Steal Session — Remaining Tracks", 1)

    if proceed == 1 then
      add_new = true
    end
  end

  -- ============================================================
  -- Phase 4: Apply everything
  -- ============================================================

  local updated = 0
  local mapped_count = 0
  local added = 0

  reaper.Undo_BeginBlock()

  for _, td in ipairs(matched) do
    apply_track(track_map[td.name], td)
    updated = updated + 1
  end

  for _, m in ipairs(manual_mapped) do
    apply_track(m.project_track, m.td)
    -- Rename the project track to the .lms name
    reaper.GetSetMediaTrackInfo_String(m.project_track, "P_NAME", m.rename, true)
    mapped_count = mapped_count + 1
  end

  if add_new then
    for _, td in ipairs(still_unmatched) do
      local idx = reaper.CountTracks(0)
      reaper.InsertTrackAtIndex(idx, true)
      local new_track = reaper.GetTrack(0, idx)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", td.name, true)
      apply_track(new_track, td)
      added = added + 1
    end
  end

  reaper.Undo_EndBlock("LMS Steal Session", -1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)

  -- Summary
  local parts = {}
  if updated > 0 then
    parts[#parts + 1] = string.format("Updated %d track%s", updated, updated == 1 and "" or "s")
  end
  if mapped_count > 0 then
    parts[#parts + 1] = string.format("Mapped + renamed %d track%s", mapped_count, mapped_count == 1 and "" or "s")
  end
  if added > 0 then
    parts[#parts + 1] = string.format("Added %d new track%s", added, added == 1 and "" or "s")
  end
  if #parts == 0 then
    parts[#parts + 1] = "No changes made"
  end

  local msg = table.concat(parts, ". ") .. "."
  if #skipped > 0 then
    msg = msg .. "\n\nSkipped (unnamed in source):\n" .. table.concat(skipped, "\n")
  end

  reaper.ShowMessageBox(msg, "LMS Steal Session", 0)
end

main()
