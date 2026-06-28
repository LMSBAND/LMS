-- LMS Plugin Manager
-- ==================
-- ReaImGui-based control plane for the entire LMS plugin suite.
-- Scans tracks for LMS instances, reads broadcast/gmem state,
-- and provides named follow/sync/pattern routing controls.
--
-- Requires: ReaImGui (install via ReaPack)
-- Install: Actions > Show Action List > New Action > Load ReaScript

local r = reaper

-- Check for ReaImGui
if not r.ImGui_CreateContext then
  r.ShowMessageBox(
    "LMS Manager requires the ReaImGui extension.\n\n" ..
    "Install via ReaPack:\n" ..
    "  Extensions > ReaPack > Browse Packages\n" ..
    "  Search: ReaImGui\n" ..
    "  Install, then restart REAPER.",
    "LMS Manager", 0)
  return
end

-- ============================================================================
-- Constants
-- ============================================================================

local BC_BASE = 100000
local BC_SLOT_SIZE = 512
local BC_MAX_INSTANCES = 32
local BC_SLOTS_PER_TYPE = 16384

local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local QUALITY_NAMES = {"maj","min","7","maj7","min7","dim","aug","sus4","sus2",
                       "add9","m9","9","6","m6","dim7","m7b5"}

local TYPE_REGISTRY = {
  [4]  = {name = "RTW Channel Strip", cat = "mix"},
  [5]  = {name = "Traumatizer",       cat = "mix"},
  [6]  = {name = "Passive EQ",        cat = "mix"},
  [7]  = {name = "Tube Sat",          cat = "mix"},
  [8]  = {name = "Henge",             cat = "reverb"},
  [9]  = {name = "Henge on Crack",    cat = "reverb"},
  [11] = {name = "Frenchie",          cat = "amp"},
  [12] = {name = "Punk Idol",         cat = "amp"},
  [13] = {name = "Fridge",            cat = "amp"},
  [14] = {name = "Ol' Reliable",      cat = "amp"},
  [15] = {name = "TRSOB",             cat = "amp"},
  [16] = {name = "Twins",             cat = "amp"},
  [17] = {name = "Area51",            cat = "amp"},
  [18] = {name = "Silver69",          cat = "comp"},
  [19] = {name = "Mega Increasinator",cat = "comp"},
  [20] = {name = "Drum Trigger",      cat = "drum"},
  [21] = {name = "Smart Gate",        cat = "gate"},
  [22] = {name = "Pitch Detector",    cat = "pitch"},
  [23] = {name = "Faker",             cat = "pitch"},
  [24] = {name = "Bottom Feeder",     cat = "amp"},
  [25] = {name = "Nightmare",         cat = "amp"},
  [26] = {name = "OJ95",              cat = "amp"},
  [27] = {name = "Reverb",            cat = "reverb"},
  [28] = {name = "Tomas Teknik",      cat = "amp"},
  [29] = {name = "Lil Stinker",       cat = "synth"},
  [30] = {name = "Harmony Map",       cat = "seq"},
  [31] = {name = "Satan's Pedalboard",cat = "fx"},
  [32] = {name = "Piece of Shit",     cat = "amp"},
  [33] = {name = "Nuug420",           cat = "synth"},
}

local DISPLAY_TO_TYPE = {
  ["punk idol"]            = 12,
  ["satan's little pedal"] = 31,
  ["pedal board"]          = 31,
  ["lms rtw"]              = 4,
  ["reinvents the wheel"]  = 4,
  ["mega increasinator"]   = 19,
  ["drumbanger"]           = "drumbanger",
  ["drum trigger"]         = 20,
  ["smart gate"]           = 21,
  ["silver sixty nine"]    = 18,
  ["silver69"]             = 18,
  ["the fridge"]           = 13,
  ["ol' reliable"]         = 14,
  ["ol reliable"]          = 14,
  ["area51"]               = 17,
  ["area 51"]              = 17,
  ["frenchie"]             = 11,
  ["bottom feeder"]        = 24,
  ["nightmare"]            = 25,
  ["tomas teknik"]         = 28,
  ["trsob"]                = 15,
  ["twins"]                = 16,
  ["oj95"]                 = 26,
  ["faker"]                = 23,
  ["lil stinker"]          = 29,
  ["nuug420"]              = 33,
  ["nuug 420"]             = 33,
  ["harmony map"]          = 30,
  ["pitch detector"]       = 22,
  ["piece of shit"]        = 32,
  ["traumatizer"]          = 5,
  ["passive eq"]           = 6,
  ["tube sat"]             = 7,
  ["henge on crack"]       = 9,
  ["henge"]                = 8,
  ["reverb"]               = 27,
}

local JSFX_TO_TYPE = {
  ["lms_rtw_channel_strip"]    = 4,
  ["lms_rtw"]                  = 4,
  ["lms_traumatizer"]          = 5,
  ["lms_passive_eq"]           = 6,
  ["lms_tube_sat"]             = 7,
  ["lms_henge"]                = 8,
  ["lms_henge_on_crack"]       = 9,
  ["lms_frenchie_v2"]          = 11,
  ["lms_punk_idol_v2"]         = 12,
  ["lms_fridge_v2"]            = 13,
  ["lms_ol_reliable_v2"]       = 14,
  ["lms_trsob_v2"]             = 15,
  ["lms_twins_v2"]             = 16,
  ["lms_area51_v2"]            = 17,
  ["lms_silver69"]             = 18,
  ["lms_mega_increasinator"]   = 19,
  ["lms_drum_trigger"]         = 20,
  ["lms_smart_gate"]           = 21,
  ["lms_pitch_detector"]       = 22,
  ["lms_faker"]                = 23,
  ["lms_bottom_feeder_v2"]     = 24,
  ["lms_nightmare_v2"]         = 25,
  ["lms_oj95_v2"]              = 26,
  ["lms_reverb"]               = 27,
  ["lms_tomasteknik_v2"]       = 28,
  ["lms_lil_stinker"]          = 29,
  ["lms_harmony_map"]          = 30,
  ["lms_satans_pedalboard"]    = 31,
  ["lms_piece_of_shit"]        = 32,
  ["lms_nuug420"]              = 33,
  ["lms_drumbanger"]           = "drumbanger",
  ["lms_spring_reverb"]        = "spring",
  ["lms_tape"]                 = "tape",
  ["lms_room"]                 = "room",
  ["lms_room_send"]            = "room_send",
  ["lms_the_space"]            = "the_space",
}

local CAT_COLORS = {
  amp    = 0xFF6644FF,
  comp   = 0x44AA66FF,
  mix    = 0x4488CCFF,
  drum   = 0xCC8844FF,
  gate   = 0xAA4444FF,
  pitch  = 0x8866CCFF,
  synth  = 0xCC44AAFF,
  seq    = 0x44CCAAFF,
  fx     = 0xAAAA44FF,
  reverb = 0x6688AAFF,
}

-- ============================================================================
-- State
-- ============================================================================

local instances = {}       -- all found LMS instances on tracks
local bc_state = {}        -- broadcast slot state per type_id
local db_state = {}        -- DrumBanger custom bus state
local hm_state = {}        -- Harmony Map state
local pitch_state = {}     -- Pitch bus state
local mega_state = {}      -- Mega Increasinator metering
local scan_timer = 0
local SCAN_INTERVAL = 1.0  -- rescan tracks every N seconds
local prev_heartbeats = {} -- track heartbeat changes to detect alive vs stale

-- ============================================================================
-- Track Scanning
-- ============================================================================

local function extract_lms_name(fx_name)
  local lower = fx_name:lower()
  for key, _ in pairs(JSFX_TO_TYPE) do
    if lower:find(key, 1, true) then
      return key
    end
  end
  for key, type_id in pairs(DISPLAY_TO_TYPE) do
    if lower:find(key, 1, true) then
      return key, type_id
    end
  end
  return nil
end

local debug_fx_names = {}

local function scan_one_track(track, ti, track_name)
  local num_fx = r.TrackFX_GetCount(track)
  for fi = 0, num_fx - 1 do
    local _, fx_name = r.TrackFX_GetFXName(track, fi)
    debug_fx_names[#debug_fx_names + 1] = fx_name
    local lms_name, override_type = extract_lms_name(fx_name)
    local type_id = override_type or (lms_name and JSFX_TO_TYPE[lms_name])
    if lms_name and type_id then
      instances[#instances + 1] = {
        track = track,
        track_idx = ti,
        track_name = track_name,
        fx_idx = fi,
        fx_name = fx_name,
        lms_name = lms_name,
        type_id = type_id,
      }
    end
  end
end

local function scan_tracks()
  instances = {}
  debug_fx_names = {}

  local master = r.GetMasterTrack(0)
  if master then
    scan_one_track(master, -1, "MASTER")
  end

  local num_tracks = r.CountTracks(0)
  for ti = 0, num_tracks - 1 do
    local track = r.GetTrack(0, ti)
    local _, track_name = r.GetTrackName(track)
    scan_one_track(track, ti, track_name)
  end
end

-- ============================================================================
-- gmem Reading
-- ============================================================================

r.gmem_attach("DrumBanger")

local function read_broadcast_state()
  -- Full scan: rebuild alive set (runs on SCAN_INTERVAL only)
  bc_state = {}
  local new_hb = {}
  for type_id, info in pairs(TYPE_REGISTRY) do
    local base = BC_BASE + type_id * BC_SLOTS_PER_TYPE
    local slots = {}
    for s = 0, BC_MAX_INSTANCES - 1 do
      local addr = base + s * BC_SLOT_SIZE
      local hb = r.gmem_read(addr)
      if hb ~= 0 then
        local key = type_id .. "_" .. s
        local prev = prev_heartbeats[key]
        local alive = (prev ~= nil and prev ~= hb)
        new_hb[key] = hb
        if alive then
          slots[#slots + 1] = {
            slot = s,
            addr = addr,
            heartbeat = hb,
            alive = true,
            instance_id = r.gmem_read(addr + 1),
            type_id_read = r.gmem_read(addr + 2),
            following = r.gmem_read(addr + 3),
            param_count = r.gmem_read(addr + 4),
          }
        end
      end
    end
    if #slots > 0 then
      bc_state[type_id] = {info = info, slots = slots}
    end
  end
  prev_heartbeats = new_hb
end

local function update_broadcast_live()
  -- Fast per-frame update: just refresh follow state on existing slots
  for _, state in pairs(bc_state) do
    for _, slot in ipairs(state.slots) do
      slot.following = r.gmem_read(slot.addr + 3)
    end
  end
end

local function read_drumbanger_state()
  db_state = {
    heartbeat = r.gmem_read(10),
    seq_step = r.gmem_read(11),
    steps_per_measure = r.gmem_read(12),
    pattern = r.gmem_read(13),
    bpm = r.gmem_read(14),
    playing = r.gmem_read(15),
    seq_mode = r.gmem_read(16),
    measure = r.gmem_read(17),
    pads = {},
  }
  for p = 0, 15 do
    db_state.pads[p] = {
      velocity = r.gmem_read(100 + p),
      playing = r.gmem_read(120 + p),
    }
  end
end

local function read_harmony_state()
  hm_state = {
    heartbeat = r.gmem_read(960000),
    root = r.gmem_read(960001),
    quality = r.gmem_read(960002),
    step = r.gmem_read(960003),
    key = r.gmem_read(960004),
    scale = r.gmem_read(960005),
    mode = r.gmem_read(960006),
    divisions = r.gmem_read(960007),
    transport = r.gmem_read(960008),
    song_mode = r.gmem_read(960080),
    part_index = r.gmem_read(960081),
    mod_key = r.gmem_read(960082),
    mod_mode = r.gmem_read(960083),
    drum_pat = r.gmem_read(960084),
  }
end

local function read_pitch_state()
  pitch_state = {
    freq = r.gmem_read(950000),
    confidence = r.gmem_read(950001),
    midi_note = r.gmem_read(950002),
    heartbeat = r.gmem_read(950005),
  }
end

local function read_mega_state()
  mega_state = {
    gr_lin = r.gmem_read(50030),
    gr_db = r.gmem_read(50031),
    true_peak = r.gmem_read(50032),
  }
end

local function note_name(midi)
  if not midi or midi < 0 or midi > 127 then return "---" end
  local n = math.floor(midi) % 12
  local oct = math.floor(midi / 12) - 1
  return NOTE_NAMES[n + 1] .. oct
end

local function root_name(root)
  if not root or root < 0 or root > 11 then return "?" end
  return NOTE_NAMES[root + 1]
end

local function quality_name(q)
  if not q or q < 0 then return "?" end
  return QUALITY_NAMES[(q % #QUALITY_NAMES) + 1]
end

-- ============================================================================
-- Slot-to-Track Correlation
-- ============================================================================

local slot_to_track = {}    -- key: "type_slot" -> instance
local slot_id_cache = {}    -- key: "type_slot" -> instance_id (detect slot reuse)
local MATCH_PARAMS = 4

local function correlate_slots()
  local type_to_tracks = {}
  for _, inst in ipairs(instances) do
    if type(inst.type_id) == "number" then
      if not type_to_tracks[inst.type_id] then type_to_tracks[inst.type_id] = {} end
      type_to_tracks[inst.type_id][#type_to_tracks[inst.type_id] + 1] = inst
    end
  end

  for type_id, state in pairs(bc_state) do
    local tracks = type_to_tracks[type_id]
    if not tracks then goto continue end

    -- Check for stale tags (instance_id changed = slot was reclaimed)
    for _, slot in ipairs(state.slots) do
      local key = type_id .. "_" .. slot.slot
      local cached_id = slot_id_cache[key]
      local current_id = math.floor(slot.instance_id)
      if cached_id and cached_id ~= current_id then
        slot_to_track[key] = nil
        r.gmem_write(slot.addr + 6, 0)
      end
      slot_id_cache[key] = current_id
    end

    -- Read existing tags
    local tagged = {}
    local untagged = {}
    local used_tracks = {}
    for _, slot in ipairs(state.slots) do
      local key = type_id .. "_" .. slot.slot
      local tag = math.floor(r.gmem_read(slot.addr + 6))
      if tag > 0 then
        -- Tag exists — find the track by index
        local track_idx = tag - 1  -- 1-based in gmem, 0-based track idx (-1 = master)
        for _, inst in ipairs(tracks) do
          if inst.track_idx == track_idx then
            slot_to_track[key] = inst
            used_tracks[inst] = true
            break
          end
        end
        if not slot_to_track[key] then
          -- Tag is stale (track removed?), clear it
          r.gmem_write(slot.addr + 6, 0)
          untagged[#untagged + 1] = slot
        end
      else
        untagged[#untagged + 1] = slot
      end
    end

    -- Param-match untagged slots (one-time, before follow corrupts params)
    for _, slot in ipairs(untagged) do
      local key = type_id .. "_" .. slot.slot
      local bc_params = {}
      local pc = math.min(math.floor(slot.param_count), MATCH_PARAMS)
      for p = 0, pc - 1 do
        bc_params[p] = r.gmem_read(slot.addr + 8 + p)
      end

      local best_inst = nil
      local best_err = math.huge
      for _, inst in ipairs(tracks) do
        if not used_tracks[inst] then
          local err = 0
          for p = 0, pc - 1 do
            local val = r.TrackFX_GetParam(inst.track, inst.fx_idx, p)
            err = err + math.abs(val - (bc_params[p] or 0))
          end
          if err < best_err then
            best_err = err
            best_inst = inst
          end
        end
      end

      if best_inst then
        slot_to_track[key] = best_inst
        used_tracks[best_inst] = true
        -- Write the tag — lock it down
        local tag_val = best_inst.track_idx + 1  -- 1-based (0 = untagged)
        if best_inst.track_idx == -1 then tag_val = 9999 end  -- master
        r.gmem_write(slot.addr + 6, tag_val)
      end
    end
    ::continue::
  end
end

-- ============================================================================
-- Follow Controls
-- ============================================================================

local function slot_track_label(type_id, slot)
  local inst = slot_to_track[type_id .. "_" .. slot.slot]
  if inst then
    return inst.track_name
  end
  return "Instance " .. math.floor(slot.instance_id)
end

local function find_instances_of_type(type_id)
  local found = {}
  if bc_state[type_id] then
    for _, slot in ipairs(bc_state[type_id].slots) do
      local label = slot_track_label(type_id, slot)
      found[#found + 1] = {
        id = slot.instance_id,
        label = label,
        slot = slot,
      }
    end
  end
  return found
end

local function set_follow(slot_addr, target_id)
  -- Write to command channel (slot+5), not slot+3 which gets overwritten
  -- -1 = unfollow, positive = follow that instance ID
  r.gmem_write(slot_addr + 5, target_id == 0 and -1 or target_id)
end

-- ============================================================================
-- UI Rendering
-- ============================================================================

local ctx = r.ImGui_CreateContext("LMS Manager")

local FlagsNone = r.ImGui_WindowFlags_None()
local TreeDefault = r.ImGui_TreeNodeFlags_DefaultOpen()
local TreeLeaf = r.ImGui_TreeNodeFlags_Leaf()
local ColHeader = r.ImGui_Col_Header()
local ColText = r.ImGui_Col_Text()

local show_window = true
local selected_tab = 0

local function draw_status_dot(ctx, alive)
  local cx, cy = r.ImGui_GetCursorScreenPos(ctx)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  local color = alive and 0x44FF44FF or 0x444444FF
  r.ImGui_DrawList_AddCircleFilled(draw_list, cx + 6, cy + 9, 5, color)
  r.ImGui_Dummy(ctx, 16, 16)
  r.ImGui_SameLine(ctx)
end

local function toggle_fx(inst)
  if inst and inst.track and inst.fx_idx then
    local is_open = r.TrackFX_GetOpen(inst.track, inst.fx_idx)
    if is_open then
      r.TrackFX_Show(inst.track, inst.fx_idx, 2)
    else
      r.TrackFX_Show(inst.track, inst.fx_idx, 3)
    end
  end
end

local function draw_clickable_plugin(ctx, inst, label)
  if r.ImGui_Selectable(ctx, label) then
    toggle_fx(inst)
  end
end

-- ---- Overview Tab ----

local function draw_overview(ctx)
  r.ImGui_Text(ctx, string.format("Instances: %d   |   Broadcast types active: %d",
    #instances, (function() local n=0; for _ in pairs(bc_state) do n=n+1 end; return n end)()))
  r.ImGui_Separator(ctx)

  if #instances == 0 then
    r.ImGui_TextWrapped(ctx, "No LMS plugins found on any track. Add some JSFX and hit Rescan.")
    return
  end

  -- Group by category
  local by_cat = {}
  for _, inst in ipairs(instances) do
    local info = type(inst.type_id) == "number" and TYPE_REGISTRY[inst.type_id]
    local cat = info and info.cat or "other"
    if not by_cat[cat] then by_cat[cat] = {} end
    by_cat[cat][#by_cat[cat] + 1] = inst
  end

  local cat_order = {"amp","comp","mix","drum","gate","pitch","synth","seq","fx","reverb","other"}
  for _, cat in ipairs(cat_order) do
    local group = by_cat[cat]
    if group then
      local color = CAT_COLORS[cat] or 0xAAAAAAFF
      r.ImGui_PushStyleColor(ctx, ColHeader, color)
      if r.ImGui_CollapsingHeader(ctx, cat:upper() .. " (" .. #group .. ")") then
        for _, inst in ipairs(group) do
          local alive = false
          if type(inst.type_id) == "number" and bc_state[inst.type_id] then
            for _, slot in ipairs(bc_state[inst.type_id].slots) do
              if slot.alive then alive = true; break end
            end
          end
          if inst.type_id == "drumbanger" and db_state.heartbeat ~= 0 then alive = true end
          draw_status_dot(ctx, alive)
          local info = type(inst.type_id) == "number" and TYPE_REGISTRY[inst.type_id]
          local name = info and info.name or inst.lms_name
          local track_num = inst.track_idx == -1 and "MASTER" or tostring(inst.track_idx + 1)
          draw_clickable_plugin(ctx, inst, string.format("%-20s  Track %s: %s", name, track_num, inst.track_name))
        end
      end
      r.ImGui_PopStyleColor(ctx)
    end
  end
end

-- ============================================================================
-- Track Management Actions
-- ============================================================================

local function get_rtw_fxname()
  -- Find what REAPER calls RTW by checking an existing instance
  for _, inst in ipairs(instances) do
    if inst.type_id == 4 then
      return inst.fx_name
    end
  end
  -- Fallback: try common name formats
  return nil
end

local function track_has_fx_type(track, type_id)
  local num_fx = r.TrackFX_GetCount(track)
  for fi = 0, num_fx - 1 do
    local _, fx_name = r.TrackFX_GetFXName(track, fi)
    local lms_name, override = extract_lms_name(fx_name)
    local tid = override or (lms_name and JSFX_TO_TYPE[lms_name])
    if tid == type_id then return true, fi end
  end
  return false, -1
end

local function add_rtw_to_all_tracks()
  -- Find a track that already has RTW and copy from it
  local src_track = nil
  local src_fx = -1
  for _, inst in ipairs(instances) do
    if inst.type_id == 4 then
      src_track = inst.track
      src_fx = inst.fx_idx
      break
    end
  end

  if not src_track then
    r.ShowConsoleMsg("LMS Manager: No existing RTW found to copy from. Add one manually first.\n")
    return
  end

  local added = 0
  local num_tracks = r.CountTracks(0)
  for ti = 0, num_tracks - 1 do
    local track = r.GetTrack(0, ti)
    if not track_has_fx_type(track, 4) then
      local dst_count = r.TrackFX_GetCount(track)
      r.TrackFX_CopyToTrack(src_track, src_fx, track, dst_count, false)
      added = added + 1
    end
  end
  scan_tracks()
  r.ShowConsoleMsg(string.format("LMS Manager: Added RTW to %d tracks\n", added))
end

local function organize_track_fx(track)
  local num_fx = r.TrackFX_GetCount(track)
  if num_fx < 2 then return end

  -- Find Smart Gate and RTW positions
  local gate_idx = -1
  local rtw_idx = -1
  for fi = 0, num_fx - 1 do
    local _, fx_name = r.TrackFX_GetFXName(track, fi)
    local lms_name, override = extract_lms_name(fx_name)
    local tid = override or (lms_name and JSFX_TO_TYPE[lms_name])
    if tid == 21 then gate_idx = fi end
    if tid == 4 then rtw_idx = fi end
  end

  -- Move Smart Gate to position 0
  if gate_idx > 0 then
    r.TrackFX_CopyToTrack(track, gate_idx, track, 0, true)
    -- Indices shift after move
    if rtw_idx >= 0 then
      if rtw_idx < gate_idx then rtw_idx = rtw_idx + 1
      elseif rtw_idx == gate_idx then rtw_idx = 0
      end
    end
  end

  -- Move RTW to last position
  num_fx = r.TrackFX_GetCount(track)
  if rtw_idx >= 0 and rtw_idx < num_fx - 1 then
    r.TrackFX_CopyToTrack(track, rtw_idx, track, num_fx - 1, true)
  end
end

local function organize_all_tracks()
  local num_tracks = r.CountTracks(0)
  for ti = 0, num_tracks - 1 do
    organize_track_fx(r.GetTrack(0, ti))
  end
  scan_tracks()
  r.ShowConsoleMsg("LMS Manager: Organized FX on all tracks\n")
end

local function copy_fx_chain(src_track, dst_track)
  local src_fx = r.TrackFX_GetCount(src_track)
  for fi = 0, src_fx - 1 do
    r.TrackFX_CopyToTrack(src_track, fi, dst_track, fi, false)
  end
  scan_tracks()
end

-- context menu state
local ctx_menu_track = nil
local ctx_menu_track_name = nil

-- ---- Broadcast Tab ----

local function draw_broadcast(ctx)
  r.ImGui_Text(ctx, "Broadcast System — Follow / Steal Relationships")
  r.ImGui_Separator(ctx)

  -- Toolbar
  if r.ImGui_Button(ctx, "Add RTW to all tracks") then
    add_rtw_to_all_tracks()
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Organize all FX") then
    organize_all_tracks()
  end
  r.ImGui_SameLine(ctx)

  -- Dump button
  if r.ImGui_Button(ctx, "Dump to console") then
    r.ShowConsoleMsg("\n=== LMS Broadcast State ===\n")
    r.ShowConsoleMsg(string.format("Instances on tracks: %d\n", #instances))
    r.ShowConsoleMsg("\n-- Track Scan --\n")
    for _, inst in ipairs(instances) do
      local info = type(inst.type_id) == "number" and TYPE_REGISTRY[inst.type_id]
      local name = info and info.name or inst.lms_name
      local tn = inst.track_idx == -1 and "MASTER" or tostring(inst.track_idx + 1)
      r.ShowConsoleMsg(string.format("  Track %s (%s): %s  type_id=%s\n", tn, inst.track_name, name, tostring(inst.type_id)))
    end
    r.ShowConsoleMsg("\n-- Active Broadcast Slots --\n")
    for type_id, state in pairs(bc_state) do
      r.ShowConsoleMsg(string.format("\n  %s (type %d) — %d slot(s):\n", state.info.name, type_id, #state.slots))
      for _, slot in ipairs(state.slots) do
        r.ShowConsoleMsg(string.format("    slot %d: id=%d  following=%d  params=%d  alive=%s\n",
          slot.slot, math.floor(slot.instance_id), math.floor(slot.following),
          math.floor(slot.param_count), tostring(slot.alive)))
      end
    end
    r.ShowConsoleMsg("===========================\n")
  end

  r.ImGui_Spacing(ctx)

  -- Build track lookup for labeling
  local type_to_tracks = {}
  for _, inst in ipairs(instances) do
    if type(inst.type_id) == "number" then
      if not type_to_tracks[inst.type_id] then type_to_tracks[inst.type_id] = {} end
      type_to_tracks[inst.type_id][#type_to_tracks[inst.type_id] + 1] = inst
    end
  end

  local any = false
  for type_id, state in pairs(bc_state) do
    any = true
    local color = CAT_COLORS[state.info.cat] or 0xAAAAAAFF

    -- Build header with track names
    local tracks = type_to_tracks[type_id]
    local track_names = ""
    if tracks then
      local names = {}
      for _, t in ipairs(tracks) do names[#names + 1] = t.track_name end
      track_names = "  —  " .. table.concat(names, ", ")
    end
    local header = state.info.name .. " (" .. #state.slots .. ")" .. track_names

    r.ImGui_PushStyleColor(ctx, ColHeader, color)
    if r.ImGui_CollapsingHeader(ctx, header) then
      for _, slot in ipairs(state.slots) do
        local id = math.floor(slot.instance_id)
        local following = math.floor(slot.following)

        draw_status_dot(ctx, slot.alive)

        local label = slot_track_label(type_id, slot)
        local correlated_inst = slot_to_track[type_id .. "_" .. slot.slot]
        if correlated_inst then
          if r.ImGui_SmallButton(ctx, label .. "##bc_" .. type_id .. "_" .. slot.slot) then
            toggle_fx(correlated_inst)
          end
          if r.ImGui_IsItemClicked(ctx, 1) then
            ctx_menu_track = correlated_inst.track
            ctx_menu_track_name = correlated_inst.track_name
            ctx_menu_track_idx = correlated_inst.track_idx
            r.ImGui_OpenPopup(ctx, "track_ctx_menu")
          end
        else
          r.ImGui_Text(ctx, label)
        end
        r.ImGui_SameLine(ctx, 280)

        -- Follow dropdown
        local follow_label = "None"
        if following ~= 0 then
          local follow_found = false
          for _, peer_slot in ipairs(state.slots) do
            if math.floor(peer_slot.instance_id) == following then
              follow_label = slot_track_label(type_id, peer_slot)
              follow_found = true
              break
            end
          end
          if not follow_found then
            follow_label = "ID " .. following
          end
        end

        r.ImGui_SetNextItemWidth(ctx, 220)
        if r.ImGui_BeginCombo(ctx, "##follow_" .. type_id .. "_" .. id, "Follow: " .. follow_label) then
          if r.ImGui_Selectable(ctx, "None", following == 0) then
            set_follow(slot.addr, 0)
          end
          local peers = find_instances_of_type(type_id)
          for _, peer in ipairs(peers) do
            if math.floor(peer.id) ~= id then
              local sel = (following == math.floor(peer.id))
              if r.ImGui_Selectable(ctx, peer.label, sel) then
                set_follow(slot.addr, peer.id)
              end
            end
          end
          r.ImGui_EndCombo(ctx)
        end
      end
    end
    r.ImGui_PopStyleColor(ctx)
  end

  if not any then
    r.ImGui_TextWrapped(ctx, "No active broadcast instances. Load a project with LMS plugins.")
  end

  -- Right-click context menu
  if r.ImGui_BeginPopup(ctx, "track_ctx_menu") then
    r.ImGui_Text(ctx, ctx_menu_track_name or "?")
    r.ImGui_Separator(ctx)

    if r.ImGui_BeginMenu(ctx, "Send FX to...") then
      local num_tracks = r.CountTracks(0)
      for ti = 0, num_tracks - 1 do
        local track = r.GetTrack(0, ti)
        local _, tname = r.GetTrackName(track)
        if ti ~= ctx_menu_track_idx then
          if r.ImGui_MenuItem(ctx, tname .. "  [" .. (ti + 1) .. "]") then
            copy_fx_chain(ctx_menu_track, track)
            r.ShowConsoleMsg(string.format("LMS Manager: Copied FX from '%s' to '%s'\n",
              ctx_menu_track_name, tname))
          end
        end
      end
      r.ImGui_EndMenu(ctx)
    end

    if r.ImGui_MenuItem(ctx, "Organize FX (Gate first, RTW last)") then
      organize_track_fx(ctx_menu_track)
      scan_tracks()
      r.ShowConsoleMsg(string.format("LMS Manager: Organized FX on '%s'\n", ctx_menu_track_name))
    end

    r.ImGui_EndPopup(ctx)
  end
end

-- ---- DrumBanger Tab ----

local function draw_drumbanger(ctx)
  local alive = db_state.heartbeat ~= 0
  draw_status_dot(ctx, alive)
  r.ImGui_Text(ctx, alive and "DrumBanger ONLINE" or "DrumBanger OFFLINE")
  r.ImGui_Separator(ctx)

  if not alive then
    r.ImGui_TextWrapped(ctx, "No DrumBanger heartbeat detected.")
    return
  end

  -- Transport
  local playing = db_state.playing ~= 0
  r.ImGui_Text(ctx, string.format("Transport: %s   BPM: %.1f   Pattern: %d   Measure: %d",
    playing and "PLAYING" or "STOPPED",
    db_state.bpm,
    math.floor(db_state.pattern) + 1,
    math.floor(db_state.measure) + 1))

  -- Step display
  local step = math.floor(db_state.seq_step)
  local steps = math.floor(db_state.steps_per_measure)
  if steps > 0 and steps <= 64 then
    r.ImGui_Spacing(ctx)
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    local cx, cy = r.ImGui_GetCursorScreenPos(ctx)
    local box = 18
    local gap = 3
    for s = 0, steps - 1 do
      local x = cx + s * (box + gap)
      local color = (s == step) and 0x44FF44FF or 0x333333FF
      if s % 4 == 0 and s ~= step then color = 0x555555FF end
      r.ImGui_DrawList_AddRectFilled(draw_list, x, cy, x + box, cy + box, color)
    end
    r.ImGui_Dummy(ctx, steps * (box + gap), box + 4)
  end

  -- Pad grid
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Pad Activity:")
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  local cx, cy = r.ImGui_GetCursorScreenPos(ctx)
  local pad_size = 36
  local pad_gap = 4
  for p = 0, 15 do
    local col = p % 4
    local row = math.floor(p / 4)
    local x = cx + col * (pad_size + pad_gap)
    local y = cy + row * (pad_size + pad_gap)
    local vel = db_state.pads[p] and db_state.pads[p].velocity or 0
    local playing_pad = db_state.pads[p] and db_state.pads[p].playing or 0
    local brightness = math.max(vel / 127, playing_pad > 0 and 0.3 or 0)
    local g = math.floor(brightness * 200)
    local color = (0xFF000000) + (g * 256) + (math.floor(g * 0.5) * 65536) + 0xFF
    r.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + pad_size, y + pad_size, color)
    r.ImGui_DrawList_AddRect(draw_list, x, y, x + pad_size, y + pad_size, 0x666666FF)
    r.ImGui_DrawList_AddText(draw_list, x + 4, y + 4, 0xFFFFFFFF, tostring(p + 1))
  end
  r.ImGui_Dummy(ctx, 4 * (pad_size + pad_gap), 4 * (pad_size + pad_gap) + 4)

  -- Consumers
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, "Consumers listening to DrumBanger bus:")
  local consumers = {}
  for _, inst in ipairs(instances) do
    if inst.lms_name == "lms_lil_stinker" or inst.lms_name == "lms_nuug420" then
      consumers[#consumers + 1] = inst
    end
  end
  if #consumers > 0 then
    for _, c in ipairs(consumers) do
      local info = type(c.type_id) == "number" and TYPE_REGISTRY[c.type_id]
      r.ImGui_BulletText(ctx, string.format("%s on Track %d: %s",
        info and info.name or c.lms_name, c.track_idx + 1, c.track_name))
    end
  else
    r.ImGui_TextDisabled(ctx, "No synths (Lil Stinker / Nuug420) found on any track.")
  end
end

-- ---- Harmony Map Tab ----

local function draw_harmony(ctx)
  local alive = hm_state.heartbeat ~= 0
  draw_status_dot(ctx, alive)
  r.ImGui_Text(ctx, alive and "Harmony Map ONLINE" or "Harmony Map OFFLINE")
  r.ImGui_Separator(ctx)

  if not alive then
    r.ImGui_TextWrapped(ctx, "No Harmony Map heartbeat detected.")
    return
  end

  local root = root_name(math.floor(hm_state.root))
  local qual = quality_name(math.floor(hm_state.quality))
  local key = root_name(math.floor(hm_state.key))
  local step = math.floor(hm_state.step) + 1

  r.ImGui_Text(ctx, string.format("Key: %s   Step: %d   Current Chord: %s%s",
    key, step, root, qual))

  if hm_state.song_mode ~= 0 then
    r.ImGui_Text(ctx, string.format("Song Mode: ON   Part: %d   Drum Pattern: %d",
      math.floor(hm_state.part_index) + 1,
      math.floor(hm_state.drum_pat) + 1))
  else
    r.ImGui_Text(ctx, "Song Mode: OFF")
  end

  -- Chord readout for current pattern
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Current pattern chords:")
  local divs = math.floor(hm_state.divisions)
  if divs <= 0 then divs = 8 end
  local chord_line = {}
  for i = 0, divs - 1 do
    local cr = math.floor(r.gmem_read(960010 + i * 2))
    local cq = math.floor(r.gmem_read(960010 + i * 2 + 1))
    local highlight = (i == math.floor(hm_state.step))
    local chord_str = root_name(cr) .. quality_name(cq)
    if highlight then chord_str = "[" .. chord_str .. "]" end
    chord_line[#chord_line + 1] = string.format("%-8s", chord_str)
  end
  r.ImGui_TextWrapped(ctx, table.concat(chord_line, " "))
end

-- ---- Metering Tab ----

local function draw_metering(ctx)
  r.ImGui_Text(ctx, "Live Metering from LMS Plugins")
  r.ImGui_Separator(ctx)

  -- Mega Increasinator
  r.ImGui_Spacing(ctx)
  if mega_state.gr_db ~= 0 or mega_state.true_peak ~= 0 then
    r.ImGui_Text(ctx, "Mega Increasinator:")
    r.ImGui_Text(ctx, string.format("  GR: %.1f dB   True Peak: %.1f dB",
      mega_state.gr_db, mega_state.true_peak))
  else
    r.ImGui_TextDisabled(ctx, "Mega Increasinator: no data")
  end

  -- Pitch
  r.ImGui_Spacing(ctx)
  if pitch_state.heartbeat ~= 0 then
    r.ImGui_Text(ctx, "Pitch Detection:")
    r.ImGui_Text(ctx, string.format("  Freq: %.1f Hz   Note: %s   Confidence: %.0f%%",
      pitch_state.freq,
      note_name(pitch_state.midi_note),
      (pitch_state.confidence or 0) * 100))
  else
    r.ImGui_TextDisabled(ctx, "Pitch Detection: no data")
  end
end

-- ---- Main Window ----

local function draw_main(ctx)
  local visible, open = r.ImGui_Begin(ctx, "LMS Plugin Manager", true, FlagsNone)
  if visible then
    -- Toolbar
    if r.ImGui_Button(ctx, "Rescan Tracks") then
      scan_tracks()
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, string.format("(%d instances)", #instances))

    r.ImGui_Spacing(ctx)

    -- Tabs
    if r.ImGui_BeginTabBar(ctx, "main_tabs") then
      if r.ImGui_BeginTabItem(ctx, "Overview") then
        draw_overview(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Broadcast") then
        draw_broadcast(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "DrumBanger") then
        draw_drumbanger(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Harmony Map") then
        draw_harmony(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Metering") then
        draw_metering(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      r.ImGui_EndTabBar(ctx)
    end

    r.ImGui_End(ctx)
  end

  return open
end

-- ============================================================================
-- Main Loop
-- ============================================================================

scan_tracks()

local last_time = r.time_precise()

local function loop()
  -- Periodic rescan
  local now = r.time_precise()
  if now - last_time > SCAN_INTERVAL then
    scan_tracks()
    read_broadcast_state()
    correlate_slots()
    last_time = now
  end

  -- Read gmem every frame (lightweight updates only)
  update_broadcast_live()
  read_drumbanger_state()
  read_harmony_state()
  read_pitch_state()
  read_mega_state()

  -- Draw
  local open = draw_main(ctx)

  if open then
    r.defer(loop)
  end
end

r.defer(loop)
