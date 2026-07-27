-- LMS Plugin Manager
-- ==================
-- ReaImGui control plane for the LMS plugin suite.
-- Scans tracks, provides follow/steal via direct TrackFX param copy.
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

local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local QUALITY_NAMES = {"maj","min","7","maj7","min7","dim","aug","sus4","sus2",
                       "add9","m9","9","6","m6","dim7","m7b5"}

local TYPE_REGISTRY = {
  [4]  = {name = "RTW Channel Strip", cat = "mix",    sliders = 35, jsfx = "lms_rtw.jsfx"},
  [5]  = {name = "Traumatizer",       cat = "mix",    sliders = 10, jsfx = "lms_traumatizer.jsfx"},
  [6]  = {name = "Passive EQ",        cat = "mix",    sliders = 9,  jsfx = "lms_passive_eq.jsfx"},
  [7]  = {name = "Tube Sat",          cat = "mix",    sliders = 8,  jsfx = "lms_tube_sat.jsfx"},
  [8]  = {name = "Henge",             cat = "reverb", sliders = 10, jsfx = "lms_henge.jsfx"},
  [9]  = {name = "Henge on Crack",    cat = "reverb", sliders = 20, jsfx = "lms_henge_on_crack.jsfx"},
  [11] = {name = "Frenchie",          cat = "amp",    sliders = 20, jsfx = "lms_frenchie_v2.jsfx"},
  [12] = {name = "Punk Idol",         cat = "amp",    sliders = 24, jsfx = "lms_punk_idol_v2.jsfx"},
  [13] = {name = "Fridge",            cat = "amp",    sliders = 32, jsfx = "lms_fridge_v2.jsfx"},
  [14] = {name = "Ol' Reliable",      cat = "amp",    sliders = 26, jsfx = "lms_ol_reliable_v2.jsfx"},
  [15] = {name = "TRSOB",             cat = "amp",    sliders = 28, jsfx = "lms_trsob_v2.jsfx"},
  [16] = {name = "Twins",             cat = "amp",    sliders = 25, jsfx = "lms_twins_v2.jsfx"},
  [17] = {name = "Area51",            cat = "amp",    sliders = 28, jsfx = "lms_area51_v2.jsfx"},
  [18] = {name = "Silver69",          cat = "comp",   sliders = 8,  jsfx = "lms_silver69.jsfx"},
  [19] = {name = "Mega Increasinator",cat = "comp",   sliders = 9,  jsfx = "lms_mega_increasinator.jsfx"},
  [20] = {name = "Drum Trigger",      cat = "drum",   sliders = 20, jsfx = "lms_drum_trigger.jsfx"},
  [21] = {name = "Smart Gate",        cat = "gate",   sliders = 16, jsfx = "lms_smart_gate.jsfx"},
  [22] = {name = "Pitch Detector",    cat = "pitch",  sliders = 8,  jsfx = "lms_pitch_detector.jsfx"},
  [23] = {name = "Faker",             cat = "pitch",  sliders = 9,  jsfx = "lms_faker.jsfx"},
  [24] = {name = "Bottom Feeder",     cat = "amp",    sliders = 25, jsfx = "lms_bottom_feeder_v2.jsfx"},
  [25] = {name = "Nightmare",         cat = "amp",    sliders = 24, jsfx = "lms_nightmare_v2.jsfx"},
  [26] = {name = "OJ95",              cat = "amp",    sliders = 26, jsfx = "lms_oj95_v2.jsfx"},
  [27] = {name = "Reverb",            cat = "reverb", sliders = 11, jsfx = "lms_reverb.jsfx"},
  [28] = {name = "Tomas Teknik",      cat = "amp",    sliders = 37, jsfx = "lms_tomasteknik_v2.jsfx"},
  [29] = {name = "Lil Stinker",       cat = "synth",  sliders = 44, jsfx = "lms_lil_stinker.jsfx"},
  [30] = {name = "Harmony Map",       cat = "seq",    sliders = 7,  jsfx = "lms_harmony_map.jsfx"},
  [31] = {name = "Satan's Pedalboard",cat = "fx",     sliders = 71, jsfx = "lms_satans_pedalboard.jsfx"},
  [32] = {name = "Piece of Shit",     cat = "amp",    sliders = 4,  jsfx = "lms_piece_of_shit.jsfx"},
  [33] = {name = "Nuug420",           cat = "synth",  sliders = 52, jsfx = "lms_nuug420.jsfx"},
  [36] = {name = "Black In Bluhm",   cat = "reverb", sliders = 24, jsfx = "lms_room.jsfx"},
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
  ["area 50"]              = 17,
  ["frenchie"]             = 11,
  ["bottom feeder"]        = 24,
  ["nightmare"]            = 25,
  ["tomas teknik"]         = 28,
  ["tomasteknik"]          = 28,   -- desc says "TOMASTEKNIK", no space
  ["trsob"]                = 15,
  ["twins"]                = 16,
  ["oj95"]                 = 26,
  ["oj 95"]                = 26,   -- desc says "OJ 95", with the space
  ["faker"]                = 23,
  ["lil stinker"]          = 29,
  ["nuug420"]              = 33,
  ["nuug 420"]             = 33,
  ["harmony map"]          = 30,
  ["drone voice"]          = 34,
  ["pitch detector"]       = 22,
  ["piece of shit"]        = 32,
  ["traumatizer"]          = 5,
  ["kitty kats"]           = 5,    -- desc is "Kitty Kats Big Krush"
  ["passive eq"]           = 6,
  ["peq4u"]                = 6,    -- desc is "PEQ4U"
  ["tube sat"]             = 7,
  ["henge on crack"]       = 9,
  ["henge"]                = 8,
  ["reverb"]               = 27,
  ["black in bluhm"]       = 36,
  ["bluhm send"]           = "room_send",
  ["bloody glue"]          = "bloody_glue",
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
  ["lms_drone_voice"]          = 34,
  ["lms drone voice"]          = 34,
  ["lms_drumbanger"]           = "drumbanger",
  ["lms_spring_reverb"]        = "spring",
  ["lms_tape"]                 = "tape",
  ["lms_room"]                 = 36,
  ["lms_room_send"]            = "room_send",
  ["lms_the_space"]            = "the_space",   -- retired, superseded by Black In Bluhm; kept so old projects still resolve
}

local TRACK_COLORS = {
  {230, 80, 80},   {80, 180, 230},  {120, 200, 100}, {230, 180, 50},
  {180, 100, 220}, {230, 130, 60},  {100, 210, 190}, {220, 100, 160},
  {160, 200, 60},  {100, 130, 230}, {210, 160, 200}, {80, 160, 130},
  {200, 200, 100}, {140, 100, 180}, {230, 160, 130}, {100, 200, 220},
}
local color_idx = 0

-- ---- JSFX resolution -------------------------------------------------------
-- Where our .jsfx files land is NOT fixed. Under ReaPack the folder is
-- "<remote name>/<category>/", and the remote name is chosen by whoever
-- imports the repo -- it is only "LMS Plugins" by convention. A manual install
-- per the README puts them somewhere else again. Hardcoding a prefix meant
-- TrackFX_AddByName silently returned -1 on any rig that named things
-- differently: the track got built and the FX never appeared.
--
-- So: search <resource>/Effects for the file and use whatever relative path we
-- actually find. Keep the old prefix and the bare name as fallbacks.
local JSFX_PREFIX = "LMS Plugins/LMS/"

local jsfx_path_cache = {}

local function find_jsfx(filename)
  local cached = jsfx_path_cache[filename]
  if cached ~= nil then
    return cached or nil
  end

  local root = r.GetResourcePath() .. "/Effects"
  local found = nil
  local queue = { "" }

  while #queue > 0 and not found do
    local rel = table.remove(queue, 1)
    local dir = (rel == "") and root or (root .. "/" .. rel)

    local i = 0
    while true do
      local f = r.EnumerateFiles(dir, i)
      if not f then break end
      if f == filename then
        found = (rel == "") and f or (rel .. "/" .. f)
        break
      end
      i = i + 1
    end

    if not found then
      local d = 0
      while true do
        local sub = r.EnumerateSubdirectories(dir, d)
        if not sub then break end
        queue[#queue + 1] = (rel == "") and sub or (rel .. "/" .. sub)
        d = d + 1
      end
    end
  end

  jsfx_path_cache[filename] = found or false
  return found
end

-- Add an LMS JSFX to a track. Returns the FX index, or -1 if every candidate
-- failed. Never use ShowMessageBox to report this: it is modal, and blocking
-- the defer loop lets ReaImGui garbage-collect our context mid-frame.
local function add_lms_fx(track, filename)
  local tried = {}
  local discovered = find_jsfx(filename)
  if discovered then tried[#tried + 1] = discovered end
  tried[#tried + 1] = JSFX_PREFIX .. filename
  tried[#tried + 1] = filename

  for _, candidate in ipairs(tried) do
    local fx = r.TrackFX_AddByName(track, candidate, false, -1)
    if fx >= 0 then return fx end
  end

  r.ShowConsoleMsg(
    "LMS Manager: could not add " .. filename .. "\n" ..
    "  tried: " .. table.concat(tried, ", ") .. "\n" ..
    "  If the plugin is installed, restart REAPER -- it scans the Effects\n" ..
    "  folder on launch and cannot insert a JSFX it has not scanned yet.\n")
  return -1
end

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

local instances = {}
local db_state = {}
local hm_state = {}
local pitch_state = {}
local mega_state = {}
local scan_timer = 0
local SCAN_INTERVAL = 1.0
local db_edit_pad = 0
local db_step_queue = {}
local drone_states = {}
local drone_arp_timer = 0
local MAT_NAMES = {"Concrete", "Wood", "Drywall", "Glass", "Brick", "Carpet", "Curtain", "Foam"}
local room_verb_enabled = false
local notice_open = false

-- Follow: follows[type_id][follower_track_idx] = leader_track_idx
local follows = {}

-- ============================================================================
-- Track Scanning
-- ============================================================================

-- Returns (key, type_id_override). NOTE: the returned key is whichever table
-- matched, so it is NOT a stable identifier. TrackFX_GetFXName gives REAPER's
-- display name ("JS: LMS DRUMBANGER"), not the filename, so the JSFX_TO_TYPE
-- lookup usually misses on the underscore and DISPLAY_TO_TYPE answers instead
-- -- yielding "drumbanger" rather than "lms_drumbanger". Always compare
-- inst.type_id, never inst.lms_name: type_id is identical from either table.
--
-- Longest key first, and in a fixed order. Several keys are prefixes of others
-- -- "lms_room" of "lms_room_send", "henge" of "henge on crack" -- and pairs()
-- walks a hash table in whatever order it likes, so which one matched was down
-- to luck: a Bluhm Send could identify as Black In Bluhm on one run and itself
-- on the next. The longest match is the specific one.
local function sorted_keys(tbl)
  local keys = {}
  for key in pairs(tbl) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if #a ~= #b then return #a > #b end
    return a < b
  end)
  return keys
end

local JSFX_KEYS_BY_LEN = sorted_keys(JSFX_TO_TYPE)
local DISPLAY_KEYS_BY_LEN = sorted_keys(DISPLAY_TO_TYPE)

local function extract_lms_name(fx_name)
  local lower = fx_name:lower()
  for _, key in ipairs(JSFX_KEYS_BY_LEN) do
    if lower:find(key, 1, true) then
      return key
    end
  end
  for _, key in ipairs(DISPLAY_KEYS_BY_LEN) do
    if lower:find(key, 1, true) then
      return key, DISPLAY_TO_TYPE[key]
    end
  end
  return nil
end

local function scan_one_track(track, ti, track_name)
  local num_fx = r.TrackFX_GetCount(track)
  for fi = 0, num_fx - 1 do
    local _, fx_name = r.TrackFX_GetFXName(track, fi)
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

local function ensure_low_latency(track)
  local flags = r.GetMediaTrackInfo_Value(track, "I_PERFFLAGS")
  local int_flags = math.floor(flags)
  if int_flags & 2 == 0 then
    r.SetMediaTrackInfo_Value(track, "I_PERFFLAGS", int_flags | 2)
  end
end

local function scan_tracks()
  instances = {}

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

  for _, inst in ipairs(instances) do
    if inst.type_id == "drumbanger" then
      ensure_low_latency(inst.track)
    end
  end
end

-- ============================================================================
-- Follow / Steal — pure TrackFX param copy
-- ============================================================================

local function find_instance(type_id, track_idx)
  for _, inst in ipairs(instances) do
    if inst.type_id == type_id and inst.track_idx == track_idx then
      return inst
    end
  end
  return nil
end

local function set_follow(type_id, follower_track_idx, leader_track_idx)
  if not follows[type_id] then follows[type_id] = {} end
  follows[type_id][follower_track_idx] = leader_track_idx
end

local function get_follow(type_id, track_idx)
  return follows[type_id] and follows[type_id][track_idx]
end

local function copy_params(src_inst, dst_inst)
  local info = TYPE_REGISTRY[src_inst.type_id]
  local count = info and info.sliders or 0
  if count <= 0 then return end
  for p = 0, count - 1 do
    local val = r.TrackFX_GetParam(src_inst.track, src_inst.fx_idx, p)
    local cur = r.TrackFX_GetParam(dst_inst.track, dst_inst.fx_idx, p)
    if math.abs(val - cur) > 1e-6 then
      r.TrackFX_SetParam(dst_inst.track, dst_inst.fx_idx, p, val)
    end
  end
end

local function apply_follows()
  for type_id, type_follows in pairs(follows) do
    for follower_tidx, leader_tidx in pairs(type_follows) do
      local follower = find_instance(type_id, follower_tidx)
      local leader = find_instance(type_id, leader_tidx)
      if follower and leader then
        copy_params(leader, follower)
      end
    end
  end
end

local function steal_params(type_id, dst_track_idx, src_track_idx)
  local dst = find_instance(type_id, dst_track_idx)
  local src = find_instance(type_id, src_track_idx)
  if dst and src then
    copy_params(src, dst)
  end
end

-- ============================================================================
-- gmem Reading (DrumBanger, Harmony Map, Pitch, Mega — these still use gmem)
-- ============================================================================

r.gmem_attach("DrumBanger")

local function find_db_instance()
  for _, inst in ipairs(instances) do
    if inst.type_id == "drumbanger" then return inst end
  end
  return nil
end

local function find_hm_instance()
  for _, inst in ipairs(instances) do
    if inst.type_id == 30 then return inst end
  end
  return nil
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
    display_bar = r.gmem_read(397),
    steps_per_bar = r.gmem_read(398),
    total_steps = r.gmem_read(399),
    bar_count = r.gmem_read(310),
    kit = r.gmem_read(308),
    record = r.gmem_read(303),
    selected_pad = r.gmem_read(304),
    pads = {},
  }
  for p = 0, 15 do
    db_state.pads[p] = {
      velocity = r.gmem_read(100 + p),
      playing = r.gmem_read(120 + p),
      volume = r.gmem_read(365 + p),
      pan = r.gmem_read(381 + p),
    }
  end
end

local function read_harmony_state()
  hm_state = {
    heartbeat = r.gmem_read(960000),
    chord_root = r.gmem_read(960001),
    chord_qual = r.gmem_read(960002),
    step = r.gmem_read(960003),
    num_steps = r.gmem_read(960004),
    key_root = r.gmem_read(960005),
    key_mode = r.gmem_read(960006),
    midi_ch = r.gmem_read(960007),
    transport = r.gmem_read(960008),
    pattern_steps = r.gmem_read(960010),
    song_mode = r.gmem_read(960080),
    part_index = r.gmem_read(960081),
    mod_key = r.gmem_read(960082),
    mod_mode = r.gmem_read(960083),
    drum_pat = r.gmem_read(960084),
    current_pat = r.gmem_read(960085),
    num_pats = r.gmem_read(960086),
    -- Song structure from COND_BUS
    song_num_parts = math.floor(r.gmem_read(960103)),
    song_seq_len = math.floor(r.gmem_read(960104)),
    song_sel_part = math.floor(r.gmem_read(960106)),
    song_cur_src = math.floor(r.gmem_read(960107)),
  }
  hm_state.chords = {}
  for i = 0, 31 do
    hm_state.chords[i] = {
      root = math.floor(r.gmem_read(960011 + i)),
      qual = math.floor(r.gmem_read(960043 + i)),
    }
  end
  -- Song parts (16 × 8 fields)
  hm_state.parts = {}
  for i = 0, 15 do
    local base = 960110 + i * 8
    hm_state.parts[i] = {
      cat = math.floor(r.gmem_read(base)),
      num = math.floor(r.gmem_read(base + 1)),
      pat = math.floor(r.gmem_read(base + 2)),
      rep = math.floor(r.gmem_read(base + 3)),
      mod_key = math.floor(r.gmem_read(base + 4)),
      mod_mode = math.floor(r.gmem_read(base + 5)),
      mod_vel = math.floor(r.gmem_read(base + 6)),
      arp = math.floor(r.gmem_read(base + 7)),
    }
  end
  -- Song sequence (64 entries) + drum patterns
  hm_state.seq = {}
  hm_state.seq_drum = {}
  for i = 0, 63 do
    hm_state.seq[i] = math.floor(r.gmem_read(960240 + i))
    hm_state.seq_drum[i] = math.floor(r.gmem_read(960240 + 64 + i))
  end
  -- Part octaves
  hm_state.oct = {}
  for i = 0, 15 do
    hm_state.oct[i] = math.floor(r.gmem_read(960310 + i))
  end
end

local function update_drones()
  local drone_count = 0
  local hm_root = math.floor(r.gmem_read(960001))
  local hm_qual = math.floor(r.gmem_read(960002))

  for _, inst in ipairs(instances) do
    if inst.type_id == 34 then
      local slot = drone_count
      drone_count = drone_count + 1

      local ds_key = inst.track_idx
      if not drone_states[ds_key] then
        local r_role = r.TrackFX_GetParam(inst.track, inst.fx_idx, 1)
        local r_oct = r.TrackFX_GetParam(inst.track, inst.fx_idx, 2)
        local r_vel = r.TrackFX_GetParam(inst.track, inst.fx_idx, 3)
        local r_arp = r.TrackFX_GetParam(inst.track, inst.fx_idx, 4)
        local r_dir = r.TrackFX_GetParam(inst.track, inst.fx_idx, 5)
        local r_hint = r.TrackFX_GetParam(inst.track, inst.fx_idx, 6)
        drone_states[ds_key] = {
          role = math.floor(r_role),
          oct = math.floor(r_oct),
          vel = math.floor(r_vel),
          arp_rate = math.floor(r_arp),
          arp_dir = math.floor(r_dir),
          harm_off = math.max(1, math.floor(r_hint))
        }
      end
      local ds = drone_states[ds_key]

      if not r.ValidatePtr(inst.track, "MediaTrack*") then goto drone_update_next end

      r.TrackFX_SetParam(inst.track, inst.fx_idx, 0, slot)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 1, ds.role)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 2, ds.oct)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 3, ds.vel)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 4, ds.arp_rate)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 5, ds.arp_dir)
      r.TrackFX_SetParam(inst.track, inst.fx_idx, 6, ds.harm_off)

      local gbase = 961100 + slot * 20
      local chord = {}
      if hm_root >= 0 and hm_root < 12 and hm_qual >= 0 then
        local base_note = 48 + ds.oct * 12 + hm_root
        local third, fifth, seventh
        local q = hm_qual
        if q == 0 or q == 2 or q == 4 or q == 9 or q == 11 or q == 13 or q == 14 then
          third = 4; fifth = 7
        elseif q == 1 or q == 3 or q == 8 or q == 12 or q == 15 then
          third = 3; fifth = 7
        elseif q == 5 or q == 7 then
          third = 3; fifth = 6
        elseif q == 6 then
          third = 4; fifth = 8
        elseif q == 10 then
          third = 5; fifth = 7
        else
          third = 2; fifth = 7
        end
        seventh = nil
        if q == 2 or q == 14 then seventh = 11
        elseif q == 3 or q == 8 or q == 12 then seventh = 10
        elseif q == 4 or q == 13 or q == 15 then seventh = 10
        elseif q == 7 then seventh = 9
        end
        chord = {base_note, base_note + third, base_note + fifth}
        if seventh then chord[#chord + 1] = base_note + seventh end
      end

      r.gmem_write(gbase + 6, #chord)
      for ci = 1, 8 do
        r.gmem_write(gbase + 6 + ci, chord[ci] or -1)
      end

      ::drone_update_next::
    end
  end
end

local function read_pitch_state()
  pitch_state = {
    freq = r.gmem_read(950000),
    confidence = r.gmem_read(950001),
    midi_note = r.gmem_read(950002),
    heartbeat = r.gmem_read(950005),
  }
end

-- MEGA's output analyser publishes here. It used to write three values into
-- gmem[50030..50032] -- three addresses squatting in unclaimed space,
-- documented nowhere. This bus is a declared region, and carries loudness,
-- spectrum and output density as well.
local MEGA_BUS = 970000
local MEGA_BANDS = 12

local function read_mega_state()
  local bands, centers, in_bands = {}, {}, {}
  for i = 1, MEGA_BANDS do
    bands[i] = r.gmem_read(MEGA_BUS + 20 + i)
    centers[i] = r.gmem_read(MEGA_BUS + 40 + i)
    in_bands[i] = r.gmem_read(MEGA_BUS + 80 + i)
  end
  mega_state = {
    heartbeat = r.gmem_read(MEGA_BUS + 0),
    gr_lin    = r.gmem_read(MEGA_BUS + 1),
    gr_db     = r.gmem_read(MEGA_BUS + 2),
    true_peak = r.gmem_read(MEGA_BUS + 3),
    lufs_m    = r.gmem_read(MEGA_BUS + 4),
    lufs_s    = r.gmem_read(MEGA_BUS + 5),
    lufs_i    = r.gmem_read(MEGA_BUS + 6),
    out_peak  = r.gmem_read(MEGA_BUS + 7),
    ceiling   = r.gmem_read(MEGA_BUS + 8),
    target    = r.gmem_read(MEGA_BUS + 9),
    density   = r.gmem_read(MEGA_BUS + 10),
    mid_density = r.gmem_read(MEGA_BUS + 11),
    hi_density  = r.gmem_read(MEGA_BUS + 12),
    air_density = r.gmem_read(MEGA_BUS + 13),
    bands = bands,
    centers = centers,
    in_bands = in_bands,
    eq_active  = r.gmem_read(MEGA_BUS + 14),
    eq_profile = r.gmem_read(MEGA_BUS + 15),
    eq_lo  = r.gmem_read(MEGA_BUS + 16),
    eq_mid = r.gmem_read(MEGA_BUS + 17),
    eq_hi  = r.gmem_read(MEGA_BUS + 18),
    eq_air = r.gmem_read(MEGA_BUS + 19),
    env_lo  = r.gmem_read(MEGA_BUS + 100),
    env_mid = r.gmem_read(MEGA_BUS + 101),
    env_hi  = r.gmem_read(MEGA_BUS + 102),
    env_air = r.gmem_read(MEGA_BUS + 103),
  }
end

local function sync_drumbanger_routing()
  local db_inst = find_db_instance()
  if not db_inst or db_inst.track_idx < 0 then
    for p = 0, 15 do r.gmem_write(413 + p, 0) end
    return
  end
  local db_track = db_inst.track
  local routed = {}
  local num_sends = r.GetTrackNumSends(db_track, 0)
  for si = 0, num_sends - 1 do
    local src_ch = r.GetTrackSendInfo_Value(db_track, 0, si, "I_SRCCHAN")
    src_ch = math.floor(src_ch)
    if src_ch >= 2 and src_ch <= 32 and (src_ch - 2) % 2 == 0 then
      local pad_idx = (src_ch - 2) / 2
      local dest_track = r.GetTrackSendInfo_Value(db_track, 0, si, "P_DESTTRACK")
      if dest_track then routed[pad_idx] = true end
    end
  end
  for p = 0, 15 do
    r.gmem_write(413 + p, routed[p] and 1 or 0)
  end
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
-- UI Rendering
-- ============================================================================

local ctx = r.ImGui_CreateContext("LMS Manager")
local ui_scale = 1.0

-- Locate the logo. ReaPack ships it as a "data" source, so it installs to
-- <resource>/Data, while a git checkout keeps it at the repo root beside
-- scripts/. Try both layouts, and never let a missing or unreadable image
-- take the whole manager down -- the header simply renders without it.
local script_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or ""
local sep = package.config:sub(1,1)

local logo = nil
local logo_candidates = {
  r.GetResourcePath() .. sep .. "Data" .. sep .. "shakebot_logo.png", -- ReaPack install
  script_dir .. ".." .. sep .. "shakebot_logo.png",                   -- git checkout / manual
  script_dir .. "shakebot_logo.png",
}
for _, path in ipairs(logo_candidates) do
  local f = io.open(path, "rb")
  if f then
    f:close()
    local ok, img = pcall(r.ImGui_CreateImage, path)
    if ok and img then
      logo = img
      break
    end
  end
end
if logo then r.ImGui_Attach(ctx, logo) end

local FlagsNone = r.ImGui_WindowFlags_None()
local ColHeader = r.ImGui_Col_Header()

local show_window = true

-- Rename state
local rename_track = nil       -- track MediaTrack* being renamed
local rename_track_idx = nil
local rename_buf = ""
local rename_focus = false

-- Send FX context menu state
local send_fx_src_track = nil
local send_fx_src_tidx = nil
local send_fx_src_name = ""

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

-- ============================================================================
-- Track Management Actions
-- ============================================================================

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

-- Canonical chain order, as ranks. It follows how the rig is actually plugged
-- together: nothing can be processed before it is generated, the gate cleans
-- the input before anything amplifies its noise floor, pedals hit the amp, and
-- tone, dynamics and ambience happen to what came out of it.
--
-- Ties are allowed on purpose -- every amp shares a rank -- and the sort below
-- is stable, so plugins on the same rank keep the order you put them in.
local FX_ORDER = {
  -- Generators. MIDI first, since the synths downstream play what it sends.
  [30]  = 10,   -- Harmony Map
  [34]  = 11,   -- Drone Voice
  ["drumbanger"] = 20,
  [29]  = 21,   -- Lil Stinker
  [33]  = 22,   -- Nuug420

  [21]  = 30,   -- Smart Gate -- on the raw input, before any gain stage
  [20]  = 40,   -- Drum Trigger -- wants the untouched transient
  [22]  = 50,   -- Pitch Detector -- tracks a clean signal, not a clipped one
  [23]  = 51,   -- Faker

  [31]  = 60,   -- Satan's Pedalboard -- pedals go in front of the amp

  [11]  = 70,   -- Frenchie
  [12]  = 70,   -- Punk Idol
  [13]  = 70,   -- Fridge
  [14]  = 70,   -- Ol' Reliable
  [15]  = 70,   -- TRSOB
  [16]  = 70,   -- Twins
  [17]  = 70,   -- Area51
  [24]  = 70,   -- Bottom Feeder
  [25]  = 70,   -- Nightmare
  [26]  = 70,   -- OJ95
  [28]  = 70,   -- Tomas Teknik
  [32]  = 70,   -- Piece of Shit

  [6]   = 90,   -- Passive EQ -- shape first, then colour it
  [7]   = 95,   -- Tube Sat
  [5]   = 96,   -- Traumatizer
  [18]  = 110,  -- Silver69
  [19]  = 115,  -- Mega Increasinator -- the loudest link goes after the comp
  [8]   = 120,  -- Henge
  [9]   = 121,  -- Henge on Crack
  [27]  = 122,  -- Reverb
  [36]  = 125,  -- Black In Bluhm

  [4]   = 200,  -- RTW Channel Strip -- the strip is the end of the path

  -- Taps. These read the track and pass it through untouched, so they belong
  -- after everything that shapes it: what they publish should be what the
  -- master hears.
  ["bloody_glue"] = 210,
  ["room_send"]   = 220,
}

-- Anything we do not recognise -- a third-party EQ, compressor or saturator --
-- lands after the amp with the tone plugins, which is where most of them go.
-- Unknown plugins keep their order among themselves.
local FX_ORDER_UNKNOWN = 80

local function organize_track_fx(track)
  local num_fx = r.TrackFX_GetCount(track)
  if num_fx < 2 then return end

  local chain = {}
  for fi = 0, num_fx - 1 do
    local _, fx_name = r.TrackFX_GetFXName(track, fi)
    local lms_name, override = extract_lms_name(fx_name)
    local tid = override or (lms_name and JSFX_TO_TYPE[lms_name])
    chain[#chain + 1] = {
      idx  = fi,
      rank = (tid and FX_ORDER[tid]) or FX_ORDER_UNKNOWN,
    }
  end

  -- Stable: rank decides, and the current index breaks ties. table.sort is not
  -- stable on its own, so the index is part of the comparison rather than a
  -- hope about how it behaves.
  table.sort(chain, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.idx < b.idx
  end)

  -- Selection sort with moves. Moving an FX from `cur` down to `target` shifts
  -- everything in between up by one, so the indices read before the first move
  -- go stale immediately -- pos[] tracks where each plugin actually sits.
  local pos = {}
  for _, e in ipairs(chain) do pos[e.idx] = e.idx end

  for target = 0, #chain - 1 do
    local want = chain[target + 1].idx
    local cur = pos[want]
    if cur ~= target then
      r.TrackFX_CopyToTrack(track, cur, track, target, true)
      for k, v in pairs(pos) do
        if v >= target and v < cur then pos[k] = v + 1 end
      end
      pos[want] = target
    end
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

local function colorize_all_tracks()
  local num = r.CountTracks(0)
  for ti = 0, num - 1 do
    local track = r.GetTrack(0, ti)
    local c = TRACK_COLORS[(ti % #TRACK_COLORS) + 1]
    r.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", r.ColorToNative(c[1], c[2], c[3]) | 0x1000000)
  end
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
end

-- ---- Amp swapping ----
-- Amps are interchangeable: same job in the chain, different flavor. Swapping
-- is delete + insert at the same slot so the rest of the chain keeps its order.

local AMP_TYPES = {}
for type_id, info in pairs(TYPE_REGISTRY) do
  if info.cat == "amp" and info.jsfx then AMP_TYPES[#AMP_TYPES + 1] = type_id end
end
table.sort(AMP_TYPES, function(a, b) return TYPE_REGISTRY[a].name < TYPE_REGISTRY[b].name end)

local function swap_amp(inst, new_type_id)
  local info = TYPE_REGISTRY[new_type_id]
  if not info or not info.jsfx then return end
  local track, slot = inst.track, inst.fx_idx
  if not r.ValidatePtr(track, "MediaTrack*") then return end

  local was_enabled = r.TrackFX_GetEnabled(track, slot)
  local was_open = r.TrackFX_GetOpen(track, slot)

  -- add_lms_fx appends to the end of the chain.
  local added = add_lms_fx(track, info.jsfx)
  if added < 0 then return end

  -- Move the newcomer into the old amp's slot; that pushes the old amp down one.
  r.TrackFX_CopyToTrack(track, added, track, slot, true)
  r.TrackFX_Delete(track, slot + 1)

  r.TrackFX_SetEnabled(track, slot, was_enabled)
  if was_open then r.TrackFX_Show(track, slot, 3) end
  scan_tracks()
end

-- ---- Overview Tab ----

-- Which track headers are expanded. This is the user's state, not a mirror of
-- REAPER's track selection -- deriving it from selection every frame is what
-- made an expanded header snap shut as soon as another track got selected.
-- Expanding a header selects that track in REAPER instead, so the two agree
-- without one overwriting the other.
local ov_open = {}
local ov_last_sel = nil

local function draw_overview(ctx)
  -- Whole-project actions. These live here rather than buried in Broadcast and
  -- Track Setup because they all operate on the track list this tab shows.
  -- Above the empty-project bail-out: colorizing is worth having on a project
  -- that has no LMS plugins on it yet.
  if r.ImGui_Button(ctx, "Colorize All Tracks") then
    colorize_all_tracks()
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Organize all FX") then
    organize_all_tracks()
  end
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_SetTooltip(ctx,
      "Reorders every track's FX into signal-chain order:\n"
      .. "generators > gate > pitch > pedals > amp > EQ/saturation > comp > reverb > RTW > sends.\n"
      .. "Plugins that share a stage keep the order you put them in, and anything\n"
      .. "non-LMS is treated as post-amp tone.")
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Add RTW to all tracks") then
    add_rtw_to_all_tracks()
  end
  r.ImGui_Separator(ctx)

  if #instances == 0 then
    r.ImGui_TextWrapped(ctx, "No LMS plugins found on any track. Add some JSFX and hit Rescan.")
    return
  end

  -- Group by track
  local by_track = {}
  local track_order = {}
  for _, inst in ipairs(instances) do
    local key = inst.track_idx
    if not by_track[key] then
      by_track[key] = {track = inst.track, track_idx = inst.track_idx, track_name = inst.track_name, plugins = {}}
      track_order[#track_order + 1] = key
    end
    by_track[key].plugins[#by_track[key].plugins + 1] = inst
  end

  -- Track count + plugin count
  r.ImGui_Text(ctx, string.format("%d tracks  |  %d plugins", #track_order, #instances))
  r.ImGui_Separator(ctx)

  local sel_tracks = {}
  local sel_first = nil
  for si = 0, r.CountSelectedTracks(0) - 1 do
    local st = r.GetSelectedTrack(0, si)
    local sidx = r.CSurf_TrackToID(st, false) - 1
    sel_tracks[sidx] = true
    if not sel_first then sel_first = sidx end
  end

  -- Selecting a track in REAPER (track panel, arrow keys) expands it here. Our
  -- own header clicks update ov_last_sel too, so this never fights them.
  if sel_first ~= ov_last_sel then
    ov_last_sel = sel_first
    if sel_first then ov_open[sel_first] = true end
  end

  for _, tidx in ipairs(track_order) do
    local tinfo = by_track[tidx]
    local track_num = tidx == -1 and "M" or tostring(tidx + 1)

    -- Track header with mute/solo indicators
    local muted = tidx >= 0 and r.GetMediaTrackInfo_Value(tinfo.track, "B_MUTE") == 1
    local soloed = tidx >= 0 and r.GetMediaTrackInfo_Value(tinfo.track, "I_SOLO") > 0
    local flags = ""
    if muted then flags = flags .. " [MUTE]" end
    if soloed then flags = flags .. " [SOLO]" end

    local is_selected = sel_tracks[tidx] or false
    local header_label = string.format("%sT%s: %s  (%d fx)%s###track_%d",
      is_selected and "> " or "  ", track_num, tinfo.track_name, #tinfo.plugins, flags, tidx)

    -- First sighting of a track defaults to REAPER's selection; after that the
    -- header is whatever the user last left it as.
    if ov_open[tidx] == nil then ov_open[tidx] = is_selected end
    r.ImGui_SetNextItemOpen(ctx, ov_open[tidx])
    local hdr_open = r.ImGui_CollapsingHeader(ctx, header_label)

    if hdr_open ~= ov_open[tidx] then
      ov_open[tidx] = hdr_open
      -- Expanding here selects the track in REAPER, so the arrange view follows
      -- what you are looking at.
      if hdr_open and tidx >= 0 and r.ValidatePtr(tinfo.track, "MediaTrack*") then
        r.SetOnlyTrackSelected(tinfo.track)
        ov_last_sel = tidx
        r.TrackList_AdjustWindows(false)
      end
    end

    if hdr_open then

      -- Right-click track header → send FX menu
      if r.ImGui_IsItemClicked(ctx, 1) and tidx >= 0 then
        send_fx_src_track = tinfo.track
        send_fx_src_tidx = tidx
        send_fx_src_name = tinfo.track_name
        r.ImGui_OpenPopup(ctx, "##send_fx_popup")
      end

      -- Rename: double-click the header to start renaming
      if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) and tidx >= 0 then
        rename_track = tinfo.track
        rename_track_idx = tidx
        rename_buf = tinfo.track_name
        rename_focus = true
      end

      -- Show rename input if this track is being renamed
      if rename_track_idx == tidx then
        r.ImGui_SetNextItemWidth(ctx, 200)
        if rename_focus then
          r.ImGui_SetKeyboardFocusHere(ctx)
          rename_focus = false
        end
        local enter_pressed, new_buf = r.ImGui_InputText(ctx, "##rename_" .. tidx, rename_buf,
          r.ImGui_InputTextFlags_EnterReturnsTrue())
        rename_buf = new_buf
        if enter_pressed then
          r.GetSetMediaTrackInfo_String(rename_track, "P_NAME", rename_buf, true)
          tinfo.track_name = rename_buf
          -- Update all instances for this track
          for _, inst in ipairs(instances) do
            if inst.track_idx == tidx then inst.track_name = rename_buf end
          end
          rename_track = nil
          rename_track_idx = nil
          scan_tracks()
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_SmallButton(ctx, "Cancel##ren") then
          rename_track = nil
          rename_track_idx = nil
        end
      end

      -- Track controls: mute / solo / bypass all FX
      if tidx >= 0 then
        if muted then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xCC4444FF) end
        if r.ImGui_SmallButton(ctx, muted and "M##mute_" .. tidx or "M##mute_" .. tidx) then
          r.SetMediaTrackInfo_Value(tinfo.track, "B_MUTE", muted and 0 or 1)
        end
        if muted then r.ImGui_PopStyleColor(ctx) end
        r.ImGui_SameLine(ctx)

        if soloed then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF) end
        if r.ImGui_SmallButton(ctx, "S##solo_" .. tidx) then
          r.SetMediaTrackInfo_Value(tinfo.track, "I_SOLO", soloed and 0 or 2)
        end
        if soloed then r.ImGui_PopStyleColor(ctx) end
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, "|")
        r.ImGui_SameLine(ctx)
      end

      -- Plugin list
      for pi, inst in ipairs(tinfo.plugins) do
        local info = type(inst.type_id) == "number" and TYPE_REGISTRY[inst.type_id]
        local name = info and info.name or inst.lms_name
        local cat = info and info.cat or "other"
        local color = CAT_COLORS[cat] or 0xAAAAAAFF

        -- FX enabled/disabled
        local enabled = r.TrackFX_GetEnabled(inst.track, inst.fx_idx)

        if not enabled then
          r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x666666FF)
        end

        -- Category dot
        local cx, cy = r.ImGui_GetCursorScreenPos(ctx)
        local draw_list = r.ImGui_GetWindowDrawList(ctx)
        r.ImGui_DrawList_AddCircleFilled(draw_list, cx + 6, cy + 9, 4, enabled and color or 0x444444FF)
        r.ImGui_Dummy(ctx, 14, 16)
        r.ImGui_SameLine(ctx)

        -- Clickable plugin name — opens FX window
        if r.ImGui_SmallButton(ctx, name .. "##ov_" .. tidx .. "_" .. pi) then
          toggle_fx(inst)
        end

        -- Right-click to bypass
        if r.ImGui_IsItemClicked(ctx, 1) then
          r.TrackFX_SetEnabled(inst.track, inst.fx_idx, not enabled)
        end

        if not enabled then
          r.ImGui_PopStyleColor(ctx)
        end

        -- Amps get a swap caret. It is its own button rather than a left-click
        -- on the name so amps still open like every other plugin here.
        if cat == "amp" then
          local popup_id = "ampswap_" .. tidx .. "_" .. pi
          r.ImGui_SameLine(ctx, 0, 4)
          if r.ImGui_SmallButton(ctx, "v##" .. popup_id) then
            r.ImGui_OpenPopup(ctx, popup_id)
          end
          if r.ImGui_IsItemHovered(ctx) then
            r.ImGui_SetTooltip(ctx, "Swap this amp for another")
          end
          if r.ImGui_BeginPopup(ctx, popup_id) then
            r.ImGui_Text(ctx, "Swap " .. name .. " for:")
            r.ImGui_Separator(ctx)
            for _, atype in ipairs(AMP_TYPES) do
              if atype ~= inst.type_id then
                if r.ImGui_MenuItem(ctx, TYPE_REGISTRY[atype].name .. "##" .. popup_id .. "_" .. atype) then
                  swap_amp(inst, atype)
                end
              end
            end
            r.ImGui_EndPopup(ctx)
          end
        end
      end
    end
  end

  -- Send FX popup — lists all project tracks as destinations
  if r.ImGui_BeginPopup(ctx, "##send_fx_popup") then
    r.ImGui_Text(ctx, "Send FX from: " .. send_fx_src_name)
    r.ImGui_Separator(ctx)
    local num_tracks = r.CountTracks(0)
    for ti = 0, num_tracks - 1 do
      if ti ~= send_fx_src_tidx then
        local dst_track = r.GetTrack(0, ti)
        local _, dst_name = r.GetTrackName(dst_track)
        local label = string.format("T%d: %s", ti + 1, dst_name)
        if r.ImGui_MenuItem(ctx, label) then
          copy_fx_chain(send_fx_src_track, dst_track)
          send_fx_src_track = nil
          send_fx_src_tidx = nil
        end
      end
    end
    r.ImGui_EndPopup(ctx)
  end
end

local ctx_menu_track = nil
local ctx_menu_track_name = nil
local ctx_menu_track_idx = nil

-- Smart Gate constants
local SG_MODE_NAMES = {"Single", "Drum"}
local SG_DRUM_NAMES = {"Kick", "Snare", "Tom", "OH"}

-- ---- Broadcast Tab ----

local function draw_broadcast(ctx)
  r.ImGui_Text(ctx, "Follow / Steal — Manager copies params directly between plugins")
  r.ImGui_Separator(ctx)

  -- Toolbar
  if r.ImGui_Button(ctx, "Clear All Follows") then
    follows = {}
  end

  r.ImGui_Spacing(ctx)

  -- Group instances by type
  local by_type = {}
  for _, inst in ipairs(instances) do
    if type(inst.type_id) == "number" then
      if not by_type[inst.type_id] then by_type[inst.type_id] = {} end
      by_type[inst.type_id][#by_type[inst.type_id] + 1] = inst
    end
  end

  local any = false
  for type_id, group in pairs(by_type) do
    if #group > 0 then
      any = true
      local info = TYPE_REGISTRY[type_id]
      local color = info and CAT_COLORS[info.cat] or 0xAAAAAAFF
      local name = info and info.name or ("Type " .. type_id)
      local can_follow = info and info.sliders > 0 and #group > 1

      local names = {}
      for _, inst in ipairs(group) do names[#names + 1] = inst.track_name end
      local header = name .. " (" .. #group .. ")  —  " .. table.concat(names, ", ")

      r.ImGui_PushStyleColor(ctx, ColHeader, color)
      if r.ImGui_CollapsingHeader(ctx, header) then
        for _, inst in ipairs(group) do
          local tn = inst.track_idx == -1 and "MASTER" or tostring(inst.track_idx + 1)

          draw_status_dot(ctx, true)

          -- Clickable name
          local label = inst.track_name .. " [T" .. tn .. "]"
          if r.ImGui_SmallButton(ctx, label .. "##bc_" .. type_id .. "_" .. inst.track_idx) then
            toggle_fx(inst)
          end
          if r.ImGui_IsItemClicked(ctx, 1) then
            ctx_menu_track = inst.track
            ctx_menu_track_name = inst.track_name
            ctx_menu_track_idx = inst.track_idx
            r.ImGui_OpenPopup(ctx, "track_ctx_menu")
          end

          if can_follow then
            r.ImGui_SameLine(ctx, 250)

            -- Follow dropdown
            local leader_tidx = get_follow(type_id, inst.track_idx)
            local follow_label = "None"
            if leader_tidx then
              local leader = find_instance(type_id, leader_tidx)
              follow_label = leader and leader.track_name or ("Track " .. (leader_tidx + 1))
            end

            r.ImGui_SetNextItemWidth(ctx, 200)
            if r.ImGui_BeginCombo(ctx, "##fol_" .. type_id .. "_" .. inst.track_idx, "Follow: " .. follow_label) then
              if r.ImGui_Selectable(ctx, "None", not leader_tidx) then
                set_follow(type_id, inst.track_idx, nil)
              end
              for _, peer in ipairs(group) do
                if peer.track_idx ~= inst.track_idx then
                  local peer_tn = peer.track_idx == -1 and "MASTER" or tostring(peer.track_idx + 1)
                  local sel = (leader_tidx == peer.track_idx)
                  if r.ImGui_Selectable(ctx, peer.track_name .. " [T" .. peer_tn .. "]", sel) then
                    set_follow(type_id, inst.track_idx, peer.track_idx)
                  end
                end
              end
              r.ImGui_EndCombo(ctx)
            end

            -- Steal button
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, 100)
            if r.ImGui_BeginCombo(ctx, "##stl_" .. type_id .. "_" .. inst.track_idx, "Steal") then
              for _, peer in ipairs(group) do
                if peer.track_idx ~= inst.track_idx then
                  local peer_tn = peer.track_idx == -1 and "MASTER" or tostring(peer.track_idx + 1)
                  if r.ImGui_Selectable(ctx, peer.track_name .. " [T" .. peer_tn .. "]") then
                    steal_params(type_id, inst.track_idx, peer.track_idx)
                  end
                end
              end
              r.ImGui_EndCombo(ctx)
            end
          end

          -- Smart Gate: inline mode + drum type controls
          if type_id == 21 then
            local sg_id = "##sg_" .. inst.track_idx .. "_"
            local mode_raw = r.TrackFX_GetParam(inst.track, inst.fx_idx, 1)
            local mode = mode_raw >= 0.5 and 1 or 0

            r.ImGui_SameLine(ctx)
            r.ImGui_TextDisabled(ctx, "|")
            r.ImGui_SameLine(ctx)
            if r.ImGui_SmallButton(ctx, SG_MODE_NAMES[mode + 1] .. sg_id .. "mode") then
              r.TrackFX_SetParam(inst.track, inst.fx_idx, 1, mode == 0 and 1.0 or 0.0)
            end

            if mode == 1 then
              local dt_val = r.TrackFX_GetParam(inst.track, inst.fx_idx, 10)
              local dt = math.min(3, math.max(0, math.floor(dt_val + 0.5)))
              r.ImGui_SameLine(ctx)
              r.ImGui_SetNextItemWidth(ctx, 80)
              if r.ImGui_BeginCombo(ctx, sg_id .. "drum", SG_DRUM_NAMES[dt + 1]) then
                for di = 0, 3 do
                  if r.ImGui_Selectable(ctx, SG_DRUM_NAMES[di + 1], di == dt) then
                    r.TrackFX_SetParam(inst.track, inst.fx_idx, 10, di)
                  end
                end
                r.ImGui_EndCombo(ctx)
              end
            end
          end
        end
      end
      r.ImGui_PopStyleColor(ctx)
    end
  end

  if not any then
    r.ImGui_TextWrapped(ctx, "No LMS plugins found. Add some and hit Rescan.")
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

    if r.ImGui_MenuItem(ctx, "Organize FX (gate > pedals > amp > tone > strip)") then
      organize_track_fx(ctx_menu_track)
      scan_tracks()
      r.ShowConsoleMsg(string.format("LMS Manager: Organized FX on '%s'\n", ctx_menu_track_name))
    end

    r.ImGui_EndPopup(ctx)
  end
end

-- ---- DrumBanger Tab ----

-- Map JSFX slider number to TrackFX param index (0-based declaration order)
local function db_slider_to_param(s)
  if s <= 25 then return s - 1 end       -- sliders 1-25: params 0-24
  if s <= 45 then return s - 5 end       -- sliders 30-45: params 25-40
  if s <= 65 then return s - 9 end       -- sliders 50-65: params 41-56
  if s <= 75 then return s + 19 end      -- sliders 70-75: params 89-94
  if s <= 95 then return s - 23 end      -- sliders 80-95: params 57-72
  if s <= 115 then return s - 27 end     -- sliders 100-115: params 73-88
  return s - 1
end

local function db_set_param(slider_num, value)
  local inst = find_db_instance()
  if inst then
    r.TrackFX_SetParam(inst.track, inst.fx_idx, db_slider_to_param(slider_num), value)
  end
end

local function db_get_param(slider_num)
  local inst = find_db_instance()
  if inst then
    return r.TrackFX_GetParam(inst.track, inst.fx_idx, db_slider_to_param(slider_num))
  end
  return 0
end

local function draw_drumbanger(ctx)
  local db_inst = find_db_instance()
  local alive = db_inst ~= nil and (db_state.heartbeat or 0) ~= 0
  draw_status_dot(ctx, alive)
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, alive and "DrumBanger ONLINE" or "DrumBanger OFFLINE")
  if alive then
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "Open##db_open") then
      r.TrackFX_SetOpen(db_inst.track, db_inst.fx_idx, true)
    end
  end

  if not alive then
    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "No DrumBanger heartbeat detected.")
    r.ImGui_Spacing(ctx)
    if r.ImGui_Button(ctx, "Create DRUMBANGER Track") then
      local idx = r.CountTracks(0)
      r.InsertTrackAtIndex(idx, true)
      local track = r.GetTrack(0, idx)
      r.GetSetMediaTrackInfo_String(track, "P_NAME", "DRUMBANGER", true)
      r.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", r.ColorToNative(204, 136, 68) | 0x1000000)
      add_lms_fx(track, "lms_drumbanger.jsfx")
      ensure_low_latency(track)
      scan_tracks()
    end
    return
  end

  -- Auto-enable Follow Harmony Map (slider9 / param 8) when HM is alive
  local hm_alive = find_hm_instance() ~= nil and (hm_state.heartbeat or 0) ~= 0
  if hm_alive then
    local follow = r.TrackFX_GetParam(db_inst.track, db_inst.fx_idx, 8)
    if follow < 0.5 then
      r.TrackFX_SetParam(db_inst.track, db_inst.fx_idx, 8, 1.0)
    end
  end

  local playing = db_state.playing ~= 0
  local seq_on = (db_state.seq_mode or 0) ~= 0
  local pattern = math.floor(db_state.pattern or 0)
  local bar_count = math.max(1, math.floor(db_state.bar_count or 1))
  local display_bar = math.floor(db_state.display_bar or 0)
  local steps_per_bar = math.max(1, math.floor(db_state.steps_per_bar or 16))
  local total_steps = math.max(1, math.floor(db_state.total_steps or 16))
  local cur_step = math.floor(db_state.seq_step or 0)

  -- === TRANSPORT BAR ===
  r.ImGui_SameLine(ctx, r.ImGui_GetWindowWidth(ctx) - 220)
  if r.ImGui_SmallButton(ctx, seq_on and "SEQ ON##db" or "SEQ OFF##db") then
    r.gmem_write(403, 1)
  end
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, string.format("BPM: %.0f  Kit: %d", db_state.bpm or 120, math.floor(db_state.kit or 0) + 1))

  r.ImGui_Separator(ctx)

  -- Pattern select buttons
  r.ImGui_Text(ctx, "Pattern:")
  r.ImGui_SameLine(ctx)
  for pat = 0, 7 do
    if pat > 0 then r.ImGui_SameLine(ctx) end
    local label = tostring(pat + 1)
    if pat == pattern then
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x55CC55FF)
    end
    if r.ImGui_SmallButton(ctx, label .. "##pat") then
      r.gmem_write(402, pat + 1)
    end
    if pat == pattern then
      r.ImGui_PopStyleColor(ctx, 2)
    end
  end

  -- Bar select buttons
  if bar_count > 1 then
    r.ImGui_SameLine(ctx, 0, 20)
    r.ImGui_TextDisabled(ctx, "|")
    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, "Bar:")
    r.ImGui_SameLine(ctx)
    for b = 0, bar_count - 1 do
      if b > 0 then r.ImGui_SameLine(ctx) end
      if b == display_bar then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x4488CCFF)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x55AAEEFF)
      end
      if r.ImGui_SmallButton(ctx, tostring(b + 1) .. "##bar" .. b) then
        r.gmem_write(406, b + 1)
      end
      if b == display_bar then
        r.ImGui_PopStyleColor(ctx, 2)
      end
    end
    r.ImGui_SameLine(ctx, 0, 10)
    if r.ImGui_SmallButton(ctx, "Copy##bar_copy") then
      local src = display_bar
      local dst = (display_bar + 1) % bar_count
      r.gmem_write(408, dst + 1)
      r.gmem_write(407, src + 1)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "Clear##bar_clear") then
      r.gmem_write(409, display_bar + 1)
    end
  end

  r.ImGui_Spacing(ctx)

  -- === PAD GRID (4x4) + PAD CONTROLS side by side ===
  local avail_w = r.ImGui_GetContentRegionAvail(ctx)
  local pad_size = 48
  local pad_gap = 4
  local grid_w = 4 * (pad_size + pad_gap)

  -- Pad grid (left side)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  local gx, gy = r.ImGui_GetCursorScreenPos(ctx)

  for p = 0, 15 do
    local col = p % 4
    local row = math.floor(p / 4)
    local x = gx + col * (pad_size + pad_gap)
    local y = gy + row * (pad_size + pad_gap)
    local vel = db_state.pads[p] and db_state.pads[p].velocity or 0
    local pad_playing = db_state.pads[p] and db_state.pads[p].playing or 0
    local is_selected = (p == db_edit_pad)

    local brightness = math.max(vel / 127, pad_playing > 0 and 0.3 or 0)
    local g = math.floor(brightness * 200)
    local bg = (0xFF000000) + (g * 256) + (math.floor(g * 0.5) * 65536) + 0xFF
    r.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + pad_size, y + pad_size, bg)

    local border = is_selected and 0xFFFF44FF or 0x666666FF
    local thickness = is_selected and 2 or 1
    r.ImGui_DrawList_AddRect(draw_list, x, y, x + pad_size, y + pad_size, border, 0, 0, thickness)
    r.ImGui_DrawList_AddText(draw_list, x + 4, y + 4, 0xFFFFFFFF, tostring(p + 1))
  end

  r.ImGui_Dummy(ctx, grid_w, 4 * (pad_size + pad_gap))

  -- Invisible buttons over pads for click detection
  r.ImGui_SetCursorScreenPos(ctx, gx, gy)
  for p = 0, 15 do
    local col = p % 4
    local row = math.floor(p / 4)
    r.ImGui_SetCursorScreenPos(ctx, gx + col * (pad_size + pad_gap), gy + row * (pad_size + pad_gap))
    if r.ImGui_InvisibleButton(ctx, "##pad" .. p, pad_size, pad_size) then
      db_edit_pad = p
      r.gmem_write(401, 100)
      r.gmem_write(400, p + 1)
    end
  end
  r.ImGui_SetCursorScreenPos(ctx, gx, gy + 4 * (pad_size + pad_gap) + 4)

  -- Pad controls (below grid)
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, string.format("Pad %d Controls:", db_edit_pad + 1))

  local inst = find_db_instance()
  if inst then
    local vol = db_get_param(10 + db_edit_pad)
    local pan = db_get_param(30 + db_edit_pad)
    local pitch = db_get_param(50 + db_edit_pad)

    r.ImGui_SetNextItemWidth(ctx, 120)
    local v_chg, v_new = r.ImGui_SliderDouble(ctx, "Vol##padctl_vol", vol, 0, 1, "%.2f")
    if v_chg then db_set_param(10 + db_edit_pad, v_new) end
    r.ImGui_SameLine(ctx)

    r.ImGui_SetNextItemWidth(ctx, 120)
    local p_chg, p_new = r.ImGui_SliderDouble(ctx, "Pan##padctl_pan", pan, -1, 1, "%.2f")
    if p_chg then db_set_param(30 + db_edit_pad, p_new) end
    r.ImGui_SameLine(ctx)

    r.ImGui_SetNextItemWidth(ctx, 120)
    local pt_chg, pt_new = r.ImGui_SliderDouble(ctx, "Pitch##padctl_pitch", pitch, -24, 24, "%.1f st")
    if pt_chg then db_set_param(50 + db_edit_pad, pt_new) end
  end

  -- === BEAT PRESETS ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Beat Presets:")
  r.ImGui_SameLine(ctx)

  -- Beat presets use command bus gmem[430-434] to set steps in DrumBanger's internal buffer
  -- One step per @block — queue all steps and flush via db_step_queue
  local function apply_beat_preset(preset_data)
    -- preset_data: table of {pad=0-15, steps={list of 0-indexed step positions}, vel=1-127}
    -- First queue clears for all pads used, then queue the active steps
    local pads_used = {}
    for _, entry in ipairs(preset_data) do
      pads_used[entry.pad] = true
    end
    for pad in pairs(pads_used) do
      for s = 0, total_steps - 1 do
        table.insert(db_step_queue, {pattern, s, pad, 0})
      end
    end
    for _, entry in ipairs(preset_data) do
      for _, s in ipairs(entry.steps) do
        if s < total_steps then
          table.insert(db_step_queue, {pattern, s, entry.pad, entry.vel or 100})
        end
      end
    end
  end

  -- Generate step lists based on total_steps
  local quarter = math.max(1, math.floor(total_steps / 4))
  local eighth = math.max(1, math.floor(total_steps / 8))
  local all_quarters = {}
  local all_eighths = {}
  local beats_13 = {}
  local beats_24 = {}
  for i = 0, 3 do all_quarters[#all_quarters + 1] = i * quarter end
  for i = 0, 7 do all_eighths[#all_eighths + 1] = i * eighth end
  beats_13 = {0, 2 * quarter}
  beats_24 = {1 * quarter, 3 * quarter}
  local upbeats = {}  -- the "and" of each beat (between quarters)
  for i = 0, 3 do
    local s = i * quarter + math.floor(quarter / 2)
    if s < total_steps then upbeats[#upbeats + 1] = s end
  end

  if r.ImGui_SmallButton(ctx, "4 Floor##bp_floor") then
    apply_beat_preset({
      {pad = 0, steps = all_quarters, vel = 110},
      {pad = 1, steps = beats_24, vel = 100},
      {pad = 4, steps = all_eighths, vel = 80},
    })
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_SmallButton(ctx, "Boots & Cats##bp_boots") then
    apply_beat_preset({
      {pad = 0, steps = beats_13, vel = 110},
      {pad = 1, steps = beats_24, vel = 100},
      {pad = 4, steps = upbeats, vel = 80},
    })
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_SmallButton(ctx, "Rock##bp_rock") then
    apply_beat_preset({
      {pad = 0, steps = {0, 2 * quarter + math.floor(quarter/2)}, vel = 110},
      {pad = 1, steps = beats_24, vel = 100},
      {pad = 4, steps = all_eighths, vel = 70},
    })
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_SmallButton(ctx, "Halftime##bp_half") then
    apply_beat_preset({
      {pad = 0, steps = {0}, vel = 110},
      {pad = 1, steps = {2 * quarter}, vel = 100},
      {pad = 4, steps = all_quarters, vel = 70},
    })
  end

  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)

  -- === STEP SEQUENCER (selected pad, current bar) ===
  r.ImGui_Text(ctx, string.format("Steps — Pad %d, Bar %d:", db_edit_pad + 1, display_bar + 1))

  local bar_start = display_bar * steps_per_bar
  local bar_end = math.min(bar_start + steps_per_bar, total_steps)
  local step_count = bar_end - bar_start
  if step_count > 0 and step_count <= 64 then
    local seq_box = 24
    local seq_gap = 3
    local sx, sy = r.ImGui_GetCursorScreenPos(ctx)

    for s = 0, step_count - 1 do
      local abs_step = bar_start + s
      local addr = 1000 + pattern * 1024 + abs_step * 16 + db_edit_pad
      local vel = r.gmem_read(addr)
      local is_active = vel > 0
      local is_playhead = (abs_step == cur_step) and playing

      local x = sx + s * (seq_box + seq_gap)
      local bg
      if is_playhead and is_active then
        bg = 0x44FF44FF
      elseif is_playhead then
        bg = 0x228822FF
      elseif is_active then
        local b = math.floor(math.min(vel / 127, 1) * 180) + 75
        bg = (0xFF000000) + (b * 65536) + (math.floor(b * 0.4) * 256) + 0xFF
      else
        bg = (s % 4 == 0) and 0x444444FF or 0x2A2A2AFF
      end

      r.ImGui_DrawList_AddRectFilled(draw_list, x, sy, x + seq_box, sy + seq_box, bg)
      r.ImGui_DrawList_AddRect(draw_list, x, sy, x + seq_box, sy + seq_box, 0x666666FF)

      if is_active then
        local bar_h = math.floor(vel / 127 * (seq_box - 4))
        r.ImGui_DrawList_AddRectFilled(draw_list,
          x + 2, sy + seq_box - 2 - bar_h,
          x + seq_box - 2, sy + seq_box - 2,
          0xFFFFFF44)
      end
    end

    r.ImGui_Dummy(ctx, step_count * (seq_box + seq_gap), seq_box + 4)

    -- Click detection for step toggles
    r.ImGui_SetCursorScreenPos(ctx, sx, sy)
    for s = 0, step_count - 1 do
      local abs_step = bar_start + s
      r.ImGui_SetCursorScreenPos(ctx, sx + s * (seq_box + seq_gap), sy)
      if r.ImGui_InvisibleButton(ctx, "##step" .. s, seq_box, seq_box) then
        r.gmem_write(405, db_edit_pad)
        r.gmem_write(404, abs_step + 1)
      end
    end
    r.ImGui_SetCursorScreenPos(ctx, sx, sy + seq_box + 4)
  end

  -- === FULL GRID VIEW (all pads, compact) ===
  r.ImGui_Spacing(ctx)
  if r.ImGui_TreeNode(ctx, "Full Grid View") then
    local fg_box = 14
    local fg_gap = 2
    local fgx, fgy = r.ImGui_GetCursorScreenPos(ctx)

    -- Pad labels column
    for p = 0, 15 do
      local ly = fgy + p * (fg_box + fg_gap)
      local label_col = (p == db_edit_pad) and 0xFFFF44FF or 0xAAAAAAFF
      r.ImGui_DrawList_AddText(draw_list, fgx, ly, label_col, string.format("%2d", p + 1))
    end

    local grid_offset_x = fgx + 24
    for p = 0, 15 do
      for s = 0, step_count - 1 do
        local abs_step = bar_start + s
        local addr = 1000 + pattern * 1024 + abs_step * 16 + p
        local vel = r.gmem_read(addr)
        local is_active = vel > 0
        local is_playhead = (abs_step == cur_step) and playing

        local x = grid_offset_x + s * (fg_box + fg_gap)
        local y = fgy + p * (fg_box + fg_gap)

        local bg
        if is_playhead and is_active then
          bg = 0x44FF44FF
        elseif is_playhead then
          bg = 0x1A441AFF
        elseif is_active then
          local b = math.floor(math.min(vel / 127, 1) * 160) + 60
          bg = (0xFF000000) + (b * 65536) + (math.floor(b * 0.3) * 256) + 0xFF
        else
          bg = (s % 4 == 0) and 0x333333FF or 0x222222FF
        end

        r.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + fg_box, y + fg_box, bg)
      end
    end

    local grid_h = 16 * (fg_box + fg_gap)
    local grid_w_full = step_count * (fg_box + fg_gap) + 24
    r.ImGui_Dummy(ctx, grid_w_full, grid_h)

    -- Click detection for full grid
    for p = 0, 15 do
      for s = 0, step_count - 1 do
        local abs_step = bar_start + s
        local x = grid_offset_x + s * (fg_box + fg_gap)
        local y = fgy + p * (fg_box + fg_gap)
        r.ImGui_SetCursorScreenPos(ctx, x, y)
        if r.ImGui_InvisibleButton(ctx, "##fg" .. p .. "_" .. s, fg_box, fg_box) then
          db_edit_pad = p
          r.gmem_write(405, p)
          r.gmem_write(404, abs_step + 1)
        end
      end
    end
    r.ImGui_SetCursorScreenPos(ctx, fgx, fgy + grid_h)

    r.ImGui_TreePop(ctx)
  end

  -- === PAD ROUTING ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)

  local db_inst = find_db_instance()
  if db_inst and db_inst.track_idx >= 0 then
    local db_track = db_inst.track
    local db_idx = r.CSurf_TrackToID(db_track, false) - 1
    local pad_names = {"Kick","Snare","HH Closed","HH Open",
                       "Tom Hi","Tom Mid","Tom Lo","Crash",
                       "Ride","Perc 1","Perc 2","Perc 3",
                       "FX 1","FX 2","FX 3","FX 4"}

    -- Check which pads have data in any pattern
    local pad_has_data = {}
    for p = 0, 15 do
      for pat = 0, 7 do
        for s = 0, 63 do
          if r.gmem_read(1000 + pat * 1024 + s * 16 + p) > 0 then
            pad_has_data[p] = true
            break
          end
        end
        if pad_has_data[p] then break end
      end
    end

    -- Detect existing routed pads via sends (source channel → pad index)
    local existing_pad_tracks = {}
    local num_sends = r.GetTrackNumSends(db_track, 0)
    for si = 0, num_sends - 1 do
      local src_ch = math.floor(r.GetTrackSendInfo_Value(db_track, 0, si, "I_SRCCHAN"))
      if src_ch >= 2 and src_ch <= 32 and (src_ch - 2) % 2 == 0 then
        existing_pad_tracks[(src_ch - 2) / 2] = true
      end
    end

    -- Count how many new tracks would be created
    local new_count = 0
    for p = 0, 15 do
      if pad_has_data[p] and not existing_pad_tracks[p] then
        new_count = new_count + 1
      end
    end

    local active_count = 0
    for p = 0, 15 do
      if pad_has_data[p] then active_count = active_count + 1 end
    end

    if new_count > 0 then
      if r.ImGui_Button(ctx, string.format("Route %d Active Pads", new_count)) then
        r.Undo_BeginBlock()

        r.SetMediaTrackInfo_Value(db_track, "I_NCHAN", 34)

        local insert_at = db_idx + 1
        -- Skip past existing send destinations below DrumBanger
        local dest_indices = {}
        for si = 0, num_sends - 1 do
          local dt = r.GetTrackSendInfo_Value(db_track, 0, si, "P_DESTTRACK")
          if dt then
            local di = r.CSurf_TrackToID(dt, false) - 1
            dest_indices[di] = true
          end
        end
        local num_tracks_now = r.CountTracks(0)
        for ti = db_idx + 1, num_tracks_now - 1 do
          if dest_indices[ti] then insert_at = ti + 1 else break end
        end

        for p = 0, 15 do
          if pad_has_data[p] and not existing_pad_tracks[p] then
            r.InsertTrackAtIndex(insert_at, false)
            local child = r.GetTrack(0, insert_at)
            r.GetSetMediaTrackInfo_String(child, "P_NAME", pad_names[p + 1], true)
            local c = TRACK_COLORS[(p % #TRACK_COLORS) + 1]
            r.SetMediaTrackInfo_Value(child, "I_CUSTOMCOLOR", r.ColorToNative(c[1], c[2], c[3]) | 0x1000000)

            local send_idx = r.CreateTrackSend(db_track, child)
            r.SetTrackSendInfo_Value(db_track, 0, send_idx, "I_SRCCHAN", 2 + p * 2)
            r.SetTrackSendInfo_Value(db_track, 0, send_idx, "I_DSTCHAN", 0)

            add_lms_fx(child, "lms_rtw.jsfx")
            insert_at = insert_at + 1
          end
        end

        r.Undo_EndBlock("DrumBanger: route pads to tracks", -1)
        r.TrackList_AdjustWindows(false)
        r.UpdateArrange()
        scan_tracks()
      end
      r.ImGui_SameLine(ctx)
      r.ImGui_TextDisabled(ctx, string.format("%d active pads, %d already routed", active_count, active_count - new_count))
    else
      if active_count > 0 then
        r.ImGui_TextDisabled(ctx, string.format("All %d active pads already routed", active_count))
      else
        r.ImGui_TextDisabled(ctx, "No pads with pattern data to route")
      end
    end
  end

  -- === CONSUMERS ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Consumers:")
  r.ImGui_SameLine(ctx)
  local has_consumer = false
  for _, inst_c in ipairs(instances) do
    if inst_c.type_id == 29 or inst_c.type_id == 33 then
      local info = type(inst_c.type_id) == "number" and TYPE_REGISTRY[inst_c.type_id]
      r.ImGui_SameLine(ctx)
      r.ImGui_TextDisabled(ctx, string.format("%s (T%d)", info and info.name or inst_c.lms_name, inst_c.track_idx + 1))
      has_consumer = true
    end
  end
  if not has_consumer then
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "None")
  end
end

-- ---- Harmony Map Tab ----

local hm_edit_step = 0
local hm_chord_popup_open = false
local hm_song_view = false  -- song structure panel open
local hm_seq_drag_src = -1
local hm_builder_open = false
local hm_markers_dirty = false

-- Song command FIFO: one command processed per @block (~1ms)
-- Queue ensures rapid-fire commands from Lua don't clobber each other
local hm_cmd_queue = {}

local function hm_song_cmd(opcode, a1, a2, a3)
  table.insert(hm_cmd_queue, {opcode, a1 or 0, a2 or 0, a3 or 0})
end

local function flush_hm_cmd_queue()
  if #hm_cmd_queue == 0 then return end
  if r.gmem_read(960330) ~= 0 then return end  -- previous cmd not yet consumed
  local cmd = table.remove(hm_cmd_queue, 1)
  r.gmem_write(960331, cmd[2])
  r.gmem_write(960332, cmd[3])
  r.gmem_write(960333, cmd[4])
  r.gmem_write(960330, cmd[1])
end

local function flush_db_step_queue()
  if #db_step_queue == 0 then return end
  if r.gmem_read(430) ~= 0 then return end
  local count = math.min(#db_step_queue, 128)
  for i = 1, count do
    local cmd = db_step_queue[i]
    local base = 431 + (i - 1) * 4
    r.gmem_write(base, cmd[1])
    r.gmem_write(base + 1, cmd[2])
    r.gmem_write(base + 2, cmd[3])
    r.gmem_write(base + 3, cmd[4])
  end
  r.gmem_write(430, count)
  for i = 1, count do table.remove(db_step_queue, 1) end
end

-- tick_drone_arps removed: arp stepping now runs in JSFX from beat_position

local PART_NAMES = {"Verse", "Chorus", "Bridge", "Intro", "Outro"}
local PART_COLORS = {0x3358AAFF, 0xAA4433FF, 0x7744AAFF, 0x33AA44FF, 0xAA8822FF}
local PART_COLORS_DIM = {0x223366FF, 0x662222FF, 0x442266FF, 0x226633FF, 0x664411FF}

-- Song builder presets: well-known structures with chord progressions
-- Chord intervals are semitones from root (transposed by current key at apply time)
-- patterns table: per-pattern chord progressions {[pat_idx] = {chords, steps}}
local SONG_PRESETS = {
  {name = "Pop (I-V-vi-IV)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=0, num=2, pat=0, rep=2},
    {cat=1, num=2, pat=1, rep=2},
    {cat=2, num=1, pat=2, rep=1},
    {cat=1, num=3, pat=1, rep=2},
    {cat=4, num=1, pat=1, rep=1},
  }, seq = {0,1,2,3,4,5,6,7},
  patterns = {
    [0] = {steps=4, chords={{0,0},{7,0},{9,1},{5,0}}},       -- verse: I V vi IV
    [1] = {steps=4, chords={{5,0},{7,0},{0,0},{0,0}}},       -- chorus: IV V I I
    [2] = {steps=4, chords={{9,1},{5,0},{2,1},{7,0}}},       -- bridge: vi IV ii V
  }},

  {name = "Blues (12-bar)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=3},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2},
  patterns = {
    [0] = {steps=12, chords={{0,2},{0,2},{0,2},{0,2},{5,2},{5,2},{0,2},{0,2},{7,2},{5,2},{0,2},{7,2}}},
  }},

  {name = "Rock (I-IV-V)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=0, num=2, pat=0, rep=2},
    {cat=1, num=2, pat=1, rep=2},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2,3,4,5},
  patterns = {
    [0] = {steps=4, chords={{0,0},{5,0},{7,0},{0,0}}},       -- verse: I IV V I
    [1] = {steps=4, chords={{5,0},{0,0},{7,0},{7,0}}},       -- chorus: IV I V V
  }},

  {name = "Minor Ballad (i-VI-III-VII)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=2, num=1, pat=2, rep=1},
    {cat=1, num=2, pat=1, rep=2},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2,3,4,5},
  patterns = {
    [0] = {steps=4, chords={{0,1},{8,0},{3,0},{10,0}}},      -- verse: i bVI bIII bVII
    [1] = {steps=4, chords={{3,0},{8,0},{0,1},{10,0}}},      -- chorus: bIII bVI i bVII
    [2] = {steps=4, chords={{5,1},{7,0},{8,0},{10,0}}},      -- bridge: iv V bVI bVII
  }},

  {name = "Punk (I-V-vi-IV fast)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=4},
    {cat=4, num=1, pat=1, rep=1},
  }, seq = {0,1,2,1,2,3},
  patterns = {
    [0] = {steps=4, chords={{0,0},{7,0},{9,1},{5,0}}},       -- verse: I V vi IV
    [1] = {steps=4, chords={{0,0},{5,0},{7,0},{5,0}}},       -- chorus: I IV V IV
  }},

  {name = "Jazz (ii-V-I-vi)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=2, num=1, pat=2, rep=1},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2,1,2,3,4},
  patterns = {
    [0] = {steps=4, chords={{2,4},{7,2},{0,3},{9,4}}},       -- verse: ii7 V7 Imaj7 vi7
    [1] = {steps=4, chords={{5,3},{9,4},{2,4},{7,2}}},       -- chorus: IVmaj7 vi7 ii7 V7
    [2] = {steps=4, chords={{4,4},{9,2},{2,4},{7,2}}},       -- bridge: iii7 VI7 ii7 V7
  }},

  {name = "Metal (i-bVI-bVII-i)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=0, num=2, pat=0, rep=2},
    {cat=1, num=2, pat=1, rep=2},
    {cat=2, num=1, pat=2, rep=1},
    {cat=1, num=3, pat=1, rep=2},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2,3,4,5,6,7},
  patterns = {
    [0] = {steps=4, chords={{0,1},{8,0},{10,0},{0,1}}},      -- verse: i bVI bVII i
    [1] = {steps=4, chords={{0,1},{3,0},{8,0},{10,0}}},      -- chorus: i bIII bVI bVII
    [2] = {steps=4, chords={{5,1},{8,0},{10,0},{7,0}}},      -- bridge: iv bVI bVII V
  }},

  {name = "Country (I-IV-V-I)", parts = {
    {cat=3, num=1, pat=0, rep=1},
    {cat=0, num=1, pat=0, rep=2},
    {cat=1, num=1, pat=1, rep=2},
    {cat=0, num=2, pat=0, rep=2},
    {cat=1, num=2, pat=1, rep=2},
    {cat=4, num=1, pat=0, rep=1},
  }, seq = {0,1,2,3,4,5},
  patterns = {
    [0] = {steps=4, chords={{0,0},{5,0},{7,0},{0,0}}},       -- verse: I IV V I
    [1] = {steps=4, chords={{5,0},{0,0},{7,0},{0,0}}},       -- chorus: IV I V I
  }},
}

local hm_builder_queue = nil

local function apply_song_preset(preset)
  -- All commands go into the FIFO — they'll be sent one per frame
  hm_song_cmd(8)  -- clear all song
  -- Add parts (clear leaves 1, add the rest)
  for i = 2, #preset.parts do
    hm_song_cmd(2)
  end
  -- Configure each part
  for i, p in ipairs(preset.parts) do
    local idx = i - 1
    hm_song_cmd(1, idx, 0, p.cat)
    hm_song_cmd(1, idx, 1, p.num)
    hm_song_cmd(1, idx, 2, p.pat)
    hm_song_cmd(1, idx, 3, p.rep)
  end
  -- Build sequence
  for _, s in ipairs(preset.seq) do
    hm_song_cmd(4, s)
  end
  -- Defer chord writing until structure commands drain
  local key_root = math.floor(hm_state.key_root or 0)
  hm_builder_queue = {preset = preset, key = key_root}
end

local function process_builder_queue()
  if not hm_builder_queue then return end
  if #hm_cmd_queue > 0 then return end  -- wait for song FIFO to drain

  local q = hm_builder_queue
  local preset = q.preset

  -- Initialize chord writing state
  if not q.chord_cmds then
    q.chord_cmds = {}
    if preset.patterns then
      -- Build flat list of gmem commands: {addr, val} pairs
      -- Collect pattern indices in sorted order for determinism
      local pat_indices = {}
      for pi in pairs(preset.patterns) do pat_indices[#pat_indices + 1] = pi end
      table.sort(pat_indices)

      for _, pat_idx in ipairs(pat_indices) do
        local pat_data = preset.patterns[pat_idx]
        -- Switch pattern
        table.insert(q.chord_cmds, {960095, pat_idx + 1})
        -- Set steps
        table.insert(q.chord_cmds, {960093, pat_data.steps})
        -- Set each chord (root then quality, need target step set before each)
        for i, ch in ipairs(pat_data.chords) do
          local root = (ch[1] + q.key) % 12
          -- Root: write step target, then root+1
          table.insert(q.chord_cmds, {960091, i - 1, 960090, root + 1})
          -- Quality: write step target, then quality+1
          table.insert(q.chord_cmds, {960091, i - 1, 960092, ch[2] + 1})
        end
      end
      -- Switch back to pattern 0
      table.insert(q.chord_cmds, {960095, 1})
    end
    q.cmd_idx = 1
    q.settle = 0
    return
  end

  -- Send one command per frame (gmem commands are consumed in one @block)
  if q.settle > 0 then
    q.settle = q.settle - 1
    return
  end

  if q.cmd_idx <= #q.chord_cmds then
    local cmd = q.chord_cmds[q.cmd_idx]
    r.gmem_write(cmd[1], cmd[2])
    if cmd[3] then r.gmem_write(cmd[3], cmd[4]) end
    q.cmd_idx = q.cmd_idx + 1
    -- Pattern switch needs a frame to settle
    if cmd[1] == 960095 then q.settle = 2 end
  else
    hm_markers_dirty = true
    hm_builder_queue = nil
  end
end

local function hm_set_param(slider_num, value)
  local inst = find_hm_instance()
  if inst then
    r.TrackFX_SetParam(inst.track, inst.fx_idx, slider_num - 1, value)
  end
end

local function hm_get_param(slider_num)
  local inst = find_hm_instance()
  if inst then
    return r.TrackFX_GetParam(inst.track, inst.fx_idx, slider_num - 1)
  end
  return 0
end

local function sync_song_markers()
  if not hm_markers_dirty then return end
  hm_markers_dirty = false

  local song_num_parts = math.max(1, hm_state.song_num_parts or 1)
  local song_seq_len = math.max(0, hm_state.song_seq_len or 0)
  if song_seq_len == 0 then return end

  -- Get tempo info for bar calculation
  local bpm, bpi = r.GetProjectTimeSignature2(0)
  local beats_per_bar = bpi > 0 and bpi or 4

  -- Delete existing LMS markers (identified by name prefix)
  local num_markers = r.CountProjectMarkers(0)
  local to_delete = {}
  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, idx = r.EnumProjectMarkers(i)
    if isrgn and name and name:sub(1, 4) == "LMS:" then
      to_delete[#to_delete + 1] = idx
    end
  end
  for i = #to_delete, 1, -1 do
    r.DeleteProjectMarker(0, to_delete[i], true)
  end

  -- Build markers from sequence
  local beat_pos = 0
  for si = 0, song_seq_len - 1 do
    local part_idx = hm_state.seq[si] or 0
    local p = hm_state.parts[part_idx]
    if not p then break end

    local cat = math.max(0, math.min(4, p.cat))
    local num = math.max(1, p.num)
    local pat = p.pat
    local rep = math.max(1, p.rep)

    -- Get pattern steps from broadcast
    local pat_steps = math.floor(r.gmem_read(960400 + pat * 80))
    if pat_steps < 1 then pat_steps = 4 end

    -- Duration in beats: steps × bars_per_step × beats_per_bar × repeats
    -- Each step = 1 bar by default (bar duration from pattern)
    local total_beats = pat_steps * beats_per_bar * rep

    local start_time = r.TimeMap2_beatsToTime(0, beat_pos)
    local end_time = r.TimeMap2_beatsToTime(0, beat_pos + total_beats)

    local marker_name = string.format("LMS: %s %d", PART_NAMES[cat + 1], num)
    local color = ({
      r.ColorToNative(51, 88, 170) | 0x1000000,   -- Verse: blue
      r.ColorToNative(170, 68, 51) | 0x1000000,   -- Chorus: red
      r.ColorToNative(119, 68, 170) | 0x1000000,  -- Bridge: purple
      r.ColorToNative(51, 170, 68) | 0x1000000,   -- Intro: green
      r.ColorToNative(170, 136, 34) | 0x1000000,  -- Outro: gold
    })[cat + 1]

    r.AddProjectMarker2(0, true, start_time, end_time, marker_name, -1, color)
    beat_pos = beat_pos + total_beats
  end

  r.UpdateArrange()
end

local function draw_harmony(ctx)
  local hm_inst = find_hm_instance()
  local alive = hm_inst ~= nil and (hm_state.heartbeat or 0) ~= 0
  draw_status_dot(ctx, alive)
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, alive and "Harmony Map ONLINE" or "Harmony Map OFFLINE")
  if alive then
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "Open##hm_open") then
      r.TrackFX_SetOpen(hm_inst.track, hm_inst.fx_idx, true)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "Reset##hm_reset") then
      r.gmem_write(960330, 9)
    end
  end

  if hm_inst == nil then
    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "No Harmony Map instance found.")
    r.ImGui_Spacing(ctx)
    if r.ImGui_Button(ctx, "Create HARMONY MAP Track") then
      local idx = r.CountTracks(0)
      r.InsertTrackAtIndex(idx, true)
      local track = r.GetTrack(0, idx)
      r.GetSetMediaTrackInfo_String(track, "P_NAME", "HARMONY MAP", true)
      r.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", r.ColorToNative(100, 180, 230) | 0x1000000)
      add_lms_fx(track, "lms_harmony_map.jsfx")
      scan_tracks()
    end
    return
  end

  if not alive then
    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "Waiting for Harmony Map heartbeat...")
    return
  end

  r.ImGui_Separator(ctx)

  -- === KEY / MODE / TRANSPORT ===
  local key_root = math.floor(hm_state.key_root or 0)
  local key_mode = math.floor(hm_state.key_mode or 0)
  local cur_step = math.floor(hm_state.step or 0)
  local num_steps = math.floor(hm_state.pattern_steps or 4)
  if num_steps < 1 then num_steps = 4 end
  local transport = math.floor(hm_state.transport or 0)
  local current_pat = math.floor(hm_state.current_pat or 0)

  -- Transport
  if transport == 1 then
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF)
  end
  if r.ImGui_Button(ctx, transport == 1 and "STOP##hm_transport" or "PLAY##hm_transport") then
    r.gmem_write(960098, 1)
  end
  if transport == 1 then r.ImGui_PopStyleColor(ctx) end
  r.ImGui_SameLine(ctx)

  -- Key selector
  r.ImGui_SetNextItemWidth(ctx, 50)
  local k_chg, k_new = r.ImGui_Combo(ctx, "Key##hm_key",
    key_root, "C\0C#\0D\0D#\0E\0F\0F#\0G\0G#\0A\0A#\0B\0")
  if k_chg then r.gmem_write(960094, k_new + 1) end
  r.ImGui_SameLine(ctx)

  -- Mode selector
  r.ImGui_SetNextItemWidth(ctx, 70)
  local m_chg, m_new = r.ImGui_Combo(ctx, "Mode##hm_mode", key_mode, "Major\0Minor\0")
  if m_chg then r.gmem_write(960099, m_new + 1) end
  r.ImGui_SameLine(ctx)

  -- Steps
  r.ImGui_SetNextItemWidth(ctx, 60)
  local ns_chg, ns_new = r.ImGui_SliderInt(ctx, "Steps##hm_steps", num_steps, 1, 32)
  if ns_chg then r.gmem_write(960093, math.floor(ns_new)) end

  -- === PATTERN SELECT ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Pattern:")
  r.ImGui_SameLine(ctx)
  for pat = 0, 15 do
    if pat > 0 then r.ImGui_SameLine(ctx) end
    local is_cur = (pat == current_pat)
    if is_cur then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF) end
    if r.ImGui_SmallButton(ctx, tostring(pat + 1) .. "##hmpat") then
      r.gmem_write(960095, pat + 1)
    end
    if is_cur then r.ImGui_PopStyleColor(ctx) end
  end

  -- === CHORD GRID ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, string.format("Chords — Pattern %d  (%d steps):", current_pat + 1, num_steps))

  local cell_w = 52
  local cell_h = 32
  local gap = 2
  local cols = math.min(num_steps, 8)

  local gx, gy = r.ImGui_GetCursorScreenPos(ctx)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)

  for i = 0, num_steps - 1 do
    local col = i % cols
    local row = math.floor(i / cols)
    local x = gx + col * (cell_w + gap)
    local y = gy + row * (cell_h + gap)

    local chord = hm_state.chords[i]
    local is_playing = (i == cur_step and transport == 1)
    local is_filled = chord and chord.root >= 0 and chord.root < 12
    local is_selected = (i == hm_edit_step)

    -- Cell background
    local bg
    if is_playing then
      bg = 0x44AA44CC
    elseif is_selected then
      bg = 0x6666AACC
    elseif is_filled then
      bg = 0x444466CC
    else
      bg = 0x333333CC
    end
    r.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + cell_w, y + cell_h, bg, 3)
    r.ImGui_DrawList_AddRect(draw_list, x, y, x + cell_w, y + cell_h,
      is_selected and 0xFFFF44FF or 0x666666FF, 3)

    -- Chord label
    local label
    if is_filled then
      label = root_name(chord.root) .. quality_name(chord.qual)
    else
      label = "---"
    end
    r.ImGui_DrawList_AddText(draw_list, x + 4, y + 4, 0xFFFFFFFF, label)

    -- Step number
    r.ImGui_DrawList_AddText(draw_list, x + 4, y + cell_h - 13, 0x888888FF, tostring(i + 1))

    -- Click detection
    r.ImGui_SetCursorScreenPos(ctx, x, y)
    if r.ImGui_InvisibleButton(ctx, "##hmcell_" .. i, cell_w, cell_h) then
      hm_edit_step = i
    end
    if r.ImGui_IsItemClicked(ctx, 1) and is_filled then
      r.gmem_write(960097, i + 1)
    end
  end

  -- Reserve space
  local total_rows = math.ceil(num_steps / cols)
  r.ImGui_SetCursorScreenPos(ctx, gx, gy + total_rows * (cell_h + gap) + 4)

  -- === CHORD EDITOR (for selected step) ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, string.format("Step %d:", hm_edit_step + 1))
  r.ImGui_SameLine(ctx)

  -- Root + Quality combined editor
  -- Clicking a root sets the chord immediately (defaults to maj if step was empty)
  -- Clicking a quality changes quality of the existing chord
  local cur_chord = hm_state.chords[hm_edit_step]
  local cur_root = cur_chord and cur_chord.root or -1
  local cur_qual = cur_chord and cur_chord.qual or 0
  local is_filled_step = cur_root >= 0 and cur_root < 12

  for n = 0, 11 do
    if n > 0 then r.ImGui_SameLine(ctx) end
    local is_active = (cur_root == n)
    if is_active then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF) end
    if r.ImGui_SmallButton(ctx, NOTE_NAMES[n + 1] .. "##hmroot" .. n) then
      -- Set root
      r.gmem_write(960091, hm_edit_step)
      r.gmem_write(960090, n + 1)
      -- If step was empty, also set quality to maj
      if not is_filled_step then
        r.gmem_write(960091, hm_edit_step)
        r.gmem_write(960092, 1)  -- maj = 0+1
      end
    end
    if is_active then r.ImGui_PopStyleColor(ctx) end
  end

  -- Quality buttons
  local qual_labels = {"maj", "min", "7", "maj7", "min7", "dim", "aug", "sus4", "sus2"}
  r.ImGui_Text(ctx, "Quality:")
  r.ImGui_SameLine(ctx)
  for q = 0, #qual_labels - 1 do
    if q > 0 then r.ImGui_SameLine(ctx) end
    local is_active = is_filled_step and cur_qual == q
    if is_active then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x44AA44FF) end
    if r.ImGui_SmallButton(ctx, qual_labels[q + 1] .. "##hmqual" .. q) then
      r.gmem_write(960091, hm_edit_step)
      r.gmem_write(960092, q + 1)
      -- If step had no root yet, default to the current key root
      if not is_filled_step then
        local kr = math.floor(hm_state.key_root or 0)
        r.gmem_write(960091, hm_edit_step)
        r.gmem_write(960090, kr + 1)
      end
    end
    if is_active then r.ImGui_PopStyleColor(ctx) end
  end

  -- Clear step button
  local cur_chord = hm_state.chords[hm_edit_step]
  if cur_chord and cur_chord.root >= 0 and cur_chord.root < 12 then
    if r.ImGui_SmallButton(ctx, "Clear Step##hmclr") then
      r.gmem_write(960097, hm_edit_step + 1)
    end
  end

  -- === SONG STRUCTURE ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)

  local song_num_parts = math.max(1, hm_state.song_num_parts or 1)
  local song_seq_len = math.max(0, hm_state.song_seq_len or 0)
  local song_sel_part = hm_state.song_sel_part or 0
  local song_playing_src = hm_state.song_cur_src or -1

  -- Song mode is not a switch: the plugin runs the song whenever one exists
  -- (_song_mode_eff = song_seq_len > 0 && song_num_parts > 0). So this states
  -- the condition rather than offering a toggle for it. The button that used
  -- to be here wrote gmem[960096], which flips song_mode -- a variable that
  -- only shows/hides the song panel inside the plugin's OWN window and gates
  -- no behaviour at all.
  local sm_active = (song_seq_len > 0 and song_num_parts > 0)
  if sm_active then
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xBB99EEFF)
    r.ImGui_Text(ctx, "SONG ON")
    r.ImGui_PopStyleColor(ctx)
  else
    r.ImGui_TextDisabled(ctx, "No song -- build one to run it")
  end
  r.ImGui_SameLine(ctx)

  if r.ImGui_Button(ctx, "Song Builder##hm_builder") then
    r.ImGui_OpenPopup(ctx, "song_builder_popup")
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Sync Markers##hm_markers") then
    hm_markers_dirty = true
  end

  -- Song builder popup
  if r.ImGui_BeginPopup(ctx, "song_builder_popup") then
    r.ImGui_Text(ctx, "Build a song structure:")
    r.ImGui_Separator(ctx)
    for i, preset in ipairs(SONG_PRESETS) do
      if r.ImGui_Selectable(ctx, preset.name .. "##sbp" .. i) then
        apply_song_preset(preset)
      end
    end
    r.ImGui_EndPopup(ctx)
  end

  -- Parts table (read-only — edit in Harmony Map plugin)
  if r.ImGui_BeginTable(ctx, "hm_parts", 7, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_SizingFixedFit()) then
    r.ImGui_TableSetupColumn(ctx, "#", 0, 20)
    r.ImGui_TableSetupColumn(ctx, "Type", 0, 65)
    r.ImGui_TableSetupColumn(ctx, "N", 0, 25)
    r.ImGui_TableSetupColumn(ctx, "Pat", 0, 35)
    r.ImGui_TableSetupColumn(ctx, "Rep", 0, 35)
    r.ImGui_TableSetupColumn(ctx, "Drum", 0, 35)
    r.ImGui_TableSetupColumn(ctx, "Oct", 0, 35)
    r.ImGui_TableHeadersRow(ctx)

    for i = 0, song_num_parts - 1 do
      local p = hm_state.parts[i]
      if not p then break end
      r.ImGui_TableNextRow(ctx)

      if i == song_sel_part then
        r.ImGui_TableSetBgColor(ctx, r.ImGui_TableBgTarget_RowBg1(), 0x4444AA44)
      end

      r.ImGui_TableNextColumn(ctx)
      r.ImGui_Text(ctx, tostring(i + 1))

      r.ImGui_TableNextColumn(ctx)
      local cat = math.max(0, math.min(4, p.cat))
      r.ImGui_TextColored(ctx, PART_COLORS[cat + 1], PART_NAMES[cat + 1])

      r.ImGui_TableNextColumn(ctx)
      r.ImGui_Text(ctx, tostring(math.max(1, p.num)))

      r.ImGui_TableNextColumn(ctx)
      r.ImGui_Text(ctx, "P" .. (p.pat + 1))

      r.ImGui_TableNextColumn(ctx)
      r.ImGui_Text(ctx, "x" .. math.max(1, p.rep))

      r.ImGui_TableNextColumn(ctx)
      local part_drum = 0
      for si = 0, song_seq_len - 1 do
        if (hm_state.seq[si] or -1) == i then
          part_drum = hm_state.seq_drum[si] or 0
          break
        end
      end
      r.ImGui_Text(ctx, part_drum > 0 and ("D" .. part_drum) or "--")

      r.ImGui_TableNextColumn(ctx)
      local oct = (hm_state.oct[i] or 3) - 3
      r.ImGui_Text(ctx, oct == 0 and "--" or (oct > 0 and "+" .. oct or tostring(oct)))
    end
    r.ImGui_EndTable(ctx)
  end
  r.ImGui_TextDisabled(ctx, "Open Harmony Map plugin to edit parts & sequence")

  -- Song sequence strip (read-only)
  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Sequence:")
  if song_seq_len == 0 then
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "(empty)")
  else
    local seq_w = 52
    local seq_h = 24
    local gx2, gy2 = r.ImGui_GetCursorScreenPos(ctx)
    local dl = r.ImGui_GetWindowDrawList(ctx)
    local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    local cols2 = math.max(1, math.floor(avail_w / (seq_w + 4)))

    for si = 0, song_seq_len - 1 do
      local part_idx = hm_state.seq[si] or 0
      local p = hm_state.parts[part_idx]
      if not p then break end
      local col2 = si % cols2
      local row2 = math.floor(si / cols2)
      local sx = gx2 + col2 * (seq_w + 4)
      local sy = gy2 + row2 * (seq_h + 3)

      local cat2 = math.max(0, math.min(4, p.cat))
      local is_playing_seq = (si == song_playing_src and transport == 1)

      local bg2 = is_playing_seq and 0x33BB55FF or PART_COLORS_DIM[cat2 + 1]
      r.ImGui_DrawList_AddRectFilled(dl, sx, sy, sx + seq_w, sy + seq_h, bg2, 3)
      if is_playing_seq then
        r.ImGui_DrawList_AddRect(dl, sx, sy, sx + seq_w, sy + seq_h, 0x44FF66FF, 3, 0, 2)
      end

      local slabel = string.format("%s %d", PART_NAMES[cat2 + 1]:sub(1, 3), math.max(1, p.num))
      r.ImGui_DrawList_AddText(dl, sx + 4, sy + 4, 0xFFFFFFFF, slabel)
    end

    local total_rows2 = math.ceil(song_seq_len / cols2)
    r.ImGui_SetCursorScreenPos(ctx, gx2, gy2 + total_rows2 * (seq_h + 3) + 4)
  end

  -- === CONSUMERS ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, "Listeners:")
  r.ImGui_SameLine(ctx)

  local has_listener = false
  for _, inst in ipairs(instances) do
    if inst.type_id == 23 then
      local follow = r.TrackFX_GetParam(inst.track, inst.fx_idx, 9)
      local is_following = follow > 0.5
      has_listener = has_listener or is_following
      local label = string.format("%s [%s]##hml_%d_%d",
        inst.track_name, is_following and "ON" or "off",
        inst.track_idx, inst.fx_idx)
      if is_following then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x44DD44FF)
      end
      if r.ImGui_SmallButton(ctx, label) then
        r.TrackFX_SetParam(inst.track, inst.fx_idx, 9, is_following and 0 or 1)
      end
      if is_following then r.ImGui_PopStyleColor(ctx) end
      r.ImGui_SameLine(ctx)
    end
  end
  if not has_listener then
    r.ImGui_TextDisabled(ctx, "No plugins following Harmony Map")
  else
    r.ImGui_NewLine(ctx)
  end

  -- Current chord display
  r.ImGui_Spacing(ctx)
  if transport == 1 then
    local cr = math.floor(hm_state.chord_root or 0)
    local cq = math.floor(hm_state.chord_qual or 0)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x44FF44FF)
    r.ImGui_Text(ctx, string.format("NOW PLAYING: %s%s  (step %d)",
      root_name(cr), quality_name(cq), cur_step + 1))
    r.ImGui_PopStyleColor(ctx)
  end

  -- === DRONES ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, "Drones:")

  local DRONE_ROLES = {"Bass", "Chords", "Arp", "Harm Arp", "Power"}
  local DRONE_ARP_RATES = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/4T", "1/8T", "1/16T"}
  local DRONE_ARP_DIRS = {"Up", "Down", "UpDown", "Rand", "Voiced"}
  local drone_count = 0

  for _, inst in ipairs(instances) do
    if inst.type_id == 34 then
      drone_count = drone_count + 1

      local ds_key = inst.track_idx
      local ds = drone_states[ds_key]
      if not ds then goto drone_next end

      r.ImGui_PushID(ctx, "drone_" .. inst.track_idx)

      -- Track name
      r.ImGui_Text(ctx, inst.track_name .. ":")
      r.ImGui_SameLine(ctx)

      -- Role combo
      r.ImGui_SetNextItemWidth(ctx, 80)
      if r.ImGui_BeginCombo(ctx, "##role", DRONE_ROLES[ds.role + 1] or "?") then
        for ri = 0, #DRONE_ROLES - 1 do
          if r.ImGui_Selectable(ctx, DRONE_ROLES[ri + 1], ri == ds.role) then
            ds.role = ri
          end
        end
        r.ImGui_EndCombo(ctx)
      end
      r.ImGui_SameLine(ctx)

      -- Octave
      r.ImGui_SetNextItemWidth(ctx, 50)
      local oct_changed, oct_new = r.ImGui_SliderInt(ctx, "##oct", ds.oct, -2, 3, "Oct:%d")
      if oct_changed then ds.oct = oct_new end
      r.ImGui_SameLine(ctx)

      -- Velocity
      r.ImGui_SetNextItemWidth(ctx, 50)
      local vel_changed, vel_new = r.ImGui_SliderInt(ctx, "##vel", ds.vel, 1, 127, "V:%d")
      if vel_changed then ds.vel = vel_new end

      -- Arp controls
      if ds.role == 2 or ds.role == 3 then
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 55)
        if r.ImGui_BeginCombo(ctx, "##rate", DRONE_ARP_RATES[ds.arp_rate + 1] or "?") then
          for ri = 0, #DRONE_ARP_RATES - 1 do
            if r.ImGui_Selectable(ctx, DRONE_ARP_RATES[ri + 1], ri == ds.arp_rate) then
              ds.arp_rate = ri
            end
          end
          r.ImGui_EndCombo(ctx)
        end
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 60)
        if r.ImGui_BeginCombo(ctx, "##dir", DRONE_ARP_DIRS[ds.arp_dir + 1] or "?") then
          for di = 0, #DRONE_ARP_DIRS - 1 do
            if r.ImGui_Selectable(ctx, DRONE_ARP_DIRS[di + 1], di == ds.arp_dir) then
              ds.arp_dir = di
            end
          end
          r.ImGui_EndCombo(ctx)
        end
      end

      -- Harmony offset, in chord tones rather than semitones. A fixed
      -- chromatic interval above every degree leaves the key on most of
      -- them, which is what made this sound wrong; stepping through the
      -- chord can only land on notes already in it.
      if ds.role == 3 then
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 78)
        local ho_changed, ho_new = r.ImGui_SliderInt(ctx, "##harm", ds.harm_off, 1, 8, "+%d tones")
        if ho_changed then ds.harm_off = ho_new end
        if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_SetTooltip(ctx, "Harmony voice sits this many chord tones above the arp note. "
            .. "2 is a third, 3 a fifth. Past the top of the chord it wraps up an octave.")
        end
      end

      -- Open synth button (next FX in chain after drone voice)
      r.ImGui_SameLine(ctx)
      if r.ImGui_SmallButton(ctx, "Open##dv") then
        local synth_idx = inst.fx_idx + 1
        if synth_idx < r.TrackFX_GetCount(inst.track) then
          r.TrackFX_SetOpen(inst.track, synth_idx, true)
        end
      end


      r.ImGui_PopID(ctx)
      ::drone_next::
    end
  end

  if drone_count == 0 then
    r.ImGui_TextDisabled(ctx, "No drones active — spawn a synth below")
  end

  -- === SPAWN SYNTH TRACKS ===
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, "Spawn MIDI Synth:")

  local synth_options = {
    {name = "Lil Stinker", jsfx = "lms_lil_stinker.jsfx", color = {180, 100, 220}},
    {name = "Nuug420",     jsfx = "lms_nuug420.jsfx",     color = {100, 200, 130}},
  }

  local midi_sources = {}
  if hm_inst then
    midi_sources[#midi_sources + 1] = {name = "HM", track = hm_inst.track}
  end
  local db_inst = find_db_instance()
  if db_inst then
    midi_sources[#midi_sources + 1] = {name = "DB", track = db_inst.track}
  end

  for _, synth in ipairs(synth_options) do
    for _, src in ipairs(midi_sources) do
      local btn_label = string.format("%s < %s", synth.name, src.name)
      if r.ImGui_Button(ctx, btn_label .. "##spawn") then
        r.Undo_BeginBlock()
        local src_idx = r.CSurf_TrackToID(src.track, false) - 1
        local insert_at = src_idx + 1
        r.InsertTrackAtIndex(insert_at, false)
        local new_track = r.GetTrack(0, insert_at)
        r.GetSetMediaTrackInfo_String(new_track, "P_NAME",
          synth.name .. " (" .. src.name .. ")", true)
        r.SetMediaTrackInfo_Value(new_track, "I_CUSTOMCOLOR",
          r.ColorToNative(synth.color[1], synth.color[2], synth.color[3]) | 0x1000000)

        add_lms_fx(new_track, "lms_drone_voice.jsfx")
        add_lms_fx(new_track, synth.jsfx)
        add_lms_fx(new_track, "lms_rtw.jsfx")

        -- Keep FX chain awake: monitoring without arm
        r.SetMediaTrackInfo_Value(new_track, "I_RECMON", 1)

        r.Undo_EndBlock("Spawn " .. synth.name .. " from " .. src.name, -1)
        r.TrackList_AdjustWindows(false)
        r.UpdateArrange()
        scan_tracks()
      end
      r.ImGui_SameLine(ctx)
    end
    r.ImGui_NewLine(ctx)
  end
end

-- ---- Metering Tab ----

-- Ink. Values, labels and axes wear text colors, never a series color -- the
-- colored mark beside them is what carries identity.
local INK        = 0xE6E6E6FF
local INK_DIM    = 0x9A9A9AFF
local INK_FAINT  = 0x5A5A5AFF
local GRID       = 0x2E2E2EFF
local SURFACE    = 0x14141AFF
local STATUS_BAD = 0xD03B3BFF   -- reserved: only ever means over-ceiling

-- Frequency is an ORDERED dimension, so the spectrum gets one hue stepped
-- light to dark, not the rainbow a spectrum analyzer usually reaches for --
-- a multi-hue ramp for magnitude is the classic misread, and bar height
-- already carries the magnitude. The hue is the suite's "comp" green, which
-- is the category MEGA lives in.
local function band_hue(i, n)
  local t = (n > 1) and ((i - 1) / (n - 1)) or 0
  local r8 = math.floor(0x30 + t * 0x60)
  local g8 = math.floor(0x88 + t * 0x60)
  local b8 = math.floor(0x50 + t * 0x50)
  return (r8 << 24) | (g8 << 16) | (b8 << 8) | 0xFF
end

-- Peak-hold state lives here, not in the plugin: it is a property of the
-- display, and the plugin should not care how fast someone's eyes are.
local spec_hold = {}
local spec_align = true

-- Density matrix, the same display the amps carry in their DENSITY AWARENESS
-- panel: 16x8 cells, a row pair per band, animated from the band envelopes.
-- Band colours are the amps' own -- LO blue, MID orange, HI red, AIR purple --
-- so density reads identically wherever you meet it in the suite, and so this
-- page is not four more shades of the spectrum's green.
local DM_COLS, DM_ROWS = 16, 8
local DM_BANDS = {
  {name = "LO",  r = 0.12, g = 0.31, b = 0.86, scale = 8.0},
  {name = "MID", r = 0.86, g = 0.63, b = 0.12, scale = 10.0},
  {name = "HI",  r = 0.86, g = 0.24, b = 0.12, scale = 12.0},
  {name = "AIR", r = 0.71, g = 0.16, b = 0.86, scale = 16.0},
}
local dm_cells = {}
local dm_frame = 0

local function db_to_frac(db, floor_db)
  if db <= floor_db then return 0 end
  return math.min(1, (db - floor_db) / -floor_db)
end

-- A labelled horizontal bar: the same mark for loudness, GR and density, so
-- three different quantities stay comparable at a glance.
local function meter_bar(ctx, label, frac, text, color, w, h)
  local dl = r.ImGui_GetWindowDrawList(ctx)
  local x, y = r.ImGui_GetCursorScreenPos(ctx)
  r.ImGui_DrawList_AddText(dl, x, y + 1, INK_DIM, label)

  -- The bar has to end short of w by the width of the readout, or the readout
  -- lands outside the content region and ImGui clips it -- which showed up as
  -- a lone dash on the right, that being the minus sign of a negative number
  -- with every other glyph cut off.
  --
  -- The gutter is measured from a fixed template rather than from the current
  -- text, so the bar keeps its length as the digits change instead of
  -- twitching a few pixels every frame. It is reserved whether or not this
  -- particular bar has a readout, so all the bars line up.
  local lab_w = 74 * ui_scale
  local val_w = r.ImGui_CalcTextSize(ctx, "-000.0 dBFS") + 10 * ui_scale
  local bx = x + lab_w
  local bw = math.max(8, w - lab_w - val_w)

  r.ImGui_DrawList_AddRectFilled(dl, bx, y, bx + bw, y + h, SURFACE, 2)
  local fw = math.max(0, math.min(1, frac)) * bw
  if fw > 1 then
    r.ImGui_DrawList_AddRectFilled(dl, bx, y, bx + fw, y + h, color, 2)
  end
  if text then
    -- Right-aligned against w, so the decimal points stack down the column.
    local tw = r.ImGui_CalcTextSize(ctx, text)
    r.ImGui_DrawList_AddText(dl, x + w - tw, y + 1, INK, text)
  end
  r.ImGui_Dummy(ctx, w, h + 3 * ui_scale)
end

local function draw_metering(ctx)
  -- The master bus is where this one earns its keep, and it is the only place
  -- the analyser describes the whole mix, so the tab leads with getting it there.
  local mega_master = find_instance(19, -1)
  if not mega_master then
    r.ImGui_TextWrapped(ctx, "MEGA INCREASINATOR is not on the master bus. It measures loudness, spectrum and density of whatever leaves it, so on the master that is the whole mix.")
    r.ImGui_Spacing(ctx)
    if r.ImGui_Button(ctx, "Add Mega Increasinator to Master") then
      local master = r.GetMasterTrack(0)
      if master and add_lms_fx(master, TYPE_REGISTRY[19].jsfx) >= 0 then
        scan_tracks()
      end
    end
    r.ImGui_Spacing(ctx)
    r.ImGui_Separator(ctx)
  end

  local live = (mega_state.heartbeat or 0) > 0
  if not live then
    r.ImGui_Spacing(ctx)
    r.ImGui_TextDisabled(ctx, mega_master
      and "Waiting for audio -- start playback to read the analyser."
      or  "No analyser data.")
  else
    local avail = r.ImGui_GetContentRegionAvail(ctx)
    local w = math.max(320, avail - 8)

    -- ---- Loudness ----------------------------------------------------
    -- One measure at three time constants, not three series. Integrated is
    -- the headline: it is the number a release is judged by, so it gets the
    -- hero treatment and the other two support it.
    r.ImGui_Text(ctx, "LOUDNESS")
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), INK)
    r.ImGui_PushFont(ctx, nil, math.floor(26 * ui_scale))
    r.ImGui_Text(ctx, string.format("%.1f LUFS", mega_state.lufs_i or -70))
    r.ImGui_PopFont(ctx)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "integrated (gated)")

    local LUFS_FLOOR = -40
    local function lufs_frac(v) return db_to_frac(v or -70, LUFS_FLOOR) end
    meter_bar(ctx, "Momentary", lufs_frac(mega_state.lufs_m),
      string.format("%.1f", mega_state.lufs_m or -70), 0x44AA66FF, w, 12 * ui_scale)
    meter_bar(ctx, "Short-term", lufs_frac(mega_state.lufs_s),
      string.format("%.1f", mega_state.lufs_s or -70), 0x338855FF, w, 12 * ui_scale)

    if r.ImGui_SmallButton(ctx, "Reset integrated") then
      r.gmem_write(MEGA_BUS + 63, 1)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, string.format("target %+.1f dB  |  ceiling %.1f dBFS",
      mega_state.target or 0, mega_state.ceiling or 0))

    -- Output peak against the limiter ceiling. Status color is reserved for
    -- state, and never carries the meaning alone -- the word CLIP does that.
    local peak_db = 20 * math.log(math.max(mega_state.out_peak or 0, 1e-7)) / math.log(10)
    local over = peak_db > (mega_state.ceiling or 0) + 0.05
    meter_bar(ctx, "Out peak", db_to_frac(peak_db, -60),
      string.format("%.1f dBFS", peak_db), over and STATUS_BAD or 0x4488CCFF,
      w, 12 * ui_scale)
    if over then
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), STATUS_BAD)
      r.ImGui_Text(ctx, "CLIP -- output is above the ceiling")
      r.ImGui_PopStyleColor(ctx)
    end
    meter_bar(ctx, "Reduction", math.min(1, math.abs(mega_state.gr_db or 0) / 24),
      string.format("%.1f dB", mega_state.gr_db or 0), 0xCC8844FF, w, 12 * ui_scale)

    r.ImGui_Spacing(ctx)
    r.ImGui_Separator(ctx)

    -- ---- Spectrum ----------------------------------------------------
    r.ImGui_Text(ctx, "SPECTRUM")
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "12 bands, 40 Hz - 16 kHz")

    -- Two series, so a legend is mandatory: identity can never rest on colour
    -- alone. Input is the reference, not a peer, so it reads as a recessive
    -- outline rather than a second filled colour competing with the output.
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, " |  filled = output   outline = input   tick = output peak")

    -- The reactive EQ is a spectral move, and a move needs a before. Aligning
    -- levels subtracts the broadband difference so only the SHAPE change shows
    -- -- without it, target loudness lifts the whole output curve and the
    -- vertical gap you are reading is mostly makeup gain, not the EQ.
    local _, new_align = r.ImGui_Checkbox(ctx, "Align levels##spec_align", spec_align)
    spec_align = new_align
    r.ImGui_SameLine(ctx)
    if (mega_state.eq_active or 0) > 0 then
      r.ImGui_TextDisabled(ctx, string.format(
        "Reactive EQ live  |  lo %+.1f  mid %+.1f  hi %+.1f  air %+.1f dB",
        mega_state.eq_lo or 0, mega_state.eq_mid or 0,
        mega_state.eq_hi or 0, mega_state.eq_air or 0))
    elseif (mega_state.eq_profile or 0) > 0 then
      r.ImGui_TextDisabled(ctx, "Reactive EQ idle -- it needs Opto Pre-Limit above 0")
    else
      r.ImGui_TextDisabled(ctx, "Reactive EQ off -- pick an EQ Profile")
    end

    local n = MEGA_BANDS
    local plot_h = math.floor(120 * ui_scale)
    local dl = r.ImGui_GetWindowDrawList(ctx)
    local px, py = r.ImGui_GetCursorScreenPos(ctx)
    local pw = w
    local FLOOR_DB = -72

    r.ImGui_DrawList_AddRectFilled(dl, px, py, px + pw, py + plot_h, SURFACE, 3)

    -- Recessive gridlines every 12 dB, labelled at the left.
    for gdb = -12, FLOOR_DB, -12 do
      local gy = py + plot_h * (1 - db_to_frac(gdb, FLOOR_DB))
      r.ImGui_DrawList_AddLine(dl, px, gy, px + pw, gy, GRID, 1)
      r.ImGui_DrawList_AddText(dl, px + 2, gy - 5 * ui_scale, INK_FAINT, string.format("%d", gdb))
    end

    local slot = pw / n
    local gap = math.max(2, slot * 0.18)
    local bw = slot - gap

    -- Offset applied to the input curve when levels are aligned: the mean
    -- output-minus-input difference over the bands carrying real signal.
    -- Bands near the floor are excluded, or a silent top end would drag the
    -- average toward a number that describes nothing.
    local align_off = 0
    if spec_align then
      local sum, cnt = 0, 0
      for i = 1, n do
        local o, s = mega_state.bands[i] or -140, mega_state.in_bands[i] or -140
        if o > FLOOR_DB + 6 and s > FLOOR_DB + 6 then
          sum = sum + (o - s); cnt = cnt + 1
        end
      end
      if cnt > 0 then align_off = sum / cnt end
    end

    for i = 1, n do
      local db = mega_state.bands[i] or -140
      local frac = db_to_frac(db, FLOOR_DB)

      -- Peak hold: decays slowly, drawn as a thin recessive line rather than
      -- a second colored series.
      local hold = spec_hold[i] or 0
      if frac >= hold then hold = frac else hold = math.max(frac, hold - 0.004) end
      spec_hold[i] = hold

      local bx = px + (i - 1) * slot + gap * 0.5
      local bh = frac * (plot_h - 2)
      if bh > 1 then
        r.ImGui_DrawList_AddRectFilled(dl, bx, py + plot_h - bh, bx + bw, py + plot_h,
          band_hue(i, n), 3)
      end
      if hold > 0.01 then
        local hy = py + plot_h - hold * (plot_h - 2)
        r.ImGui_DrawList_AddLine(dl, bx, hy, bx + bw, hy, INK_DIM, 2)
      end

      -- Input, drawn last so it sits over the fill: an open outline, same
      -- geometry as the bar it is being compared against.
      local in_db = (mega_state.in_bands[i] or -140) + align_off
      local in_frac = db_to_frac(in_db, FLOOR_DB)
      if in_frac > 0.005 then
        local iy = py + plot_h - in_frac * (plot_h - 2)
        r.ImGui_DrawList_AddRect(dl, bx, iy, bx + bw, py + plot_h, 0xBFBFBFAA, 3, 0, 2)
      end
    end
    r.ImGui_Dummy(ctx, pw, plot_h)

    -- Label only the decade-ish landmarks. A number under all twelve is noise.
    local lx, ly = r.ImGui_GetCursorScreenPos(ctx)
    for i = 1, n do
      local fc = mega_state.centers[i] or 0
      local show = (i == 1) or (i == 4) or (i == 7) or (i == 10) or (i == n)
      if show and fc > 0 then
        local label = fc >= 1000 and string.format("%.1fk", fc / 1000) or string.format("%d", fc)
        local tw = r.ImGui_CalcTextSize(ctx, label)
        r.ImGui_DrawList_AddText(dl, lx + (i - 0.5) * slot - tw * 0.5, ly, INK_FAINT, label)
      end
    end
    r.ImGui_Dummy(ctx, pw, 14 * ui_scale)

    r.ImGui_Separator(ctx)

    -- ---- Density -----------------------------------------------------
    -- Total density is one number, so it reads as a number. The three band
    -- ratios are an ordered set and share the spectrum's ramp direction.
    r.ImGui_Text(ctx, "DENSITY")
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "of the output, post-limiter")

    local dens = mega_state.density or 1.0
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), INK)
    r.ImGui_PushFont(ctx, nil, math.floor(22 * ui_scale))
    r.ImGui_Text(ctx, string.format("%.2f", dens))
    r.ImGui_PopFont(ctx)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, "total  (1.00 sparse -> 2.50 dense)")

    -- Same box as the spectrum above it, so the two plots stack as one column.
    local mx, my = r.ImGui_GetCursorScreenPos(ctx)
    local mw, mh = pw, plot_h
    r.ImGui_DrawList_AddRectFilled(dl, mx, my, mx + mw, my + mh, SURFACE, 3)

    -- Square cells, like the amps'. Taking the smaller of the two fits and
    -- centring keeps them square at any window width -- deriving cell width
    -- from the panel instead would stretch them into flat bars, which reads
    -- as a bar chart rather than the matrix this is meant to match.
    local lbl_w = 34 * ui_scale
    local cell_gap = math.max(1, 1.5 * ui_scale)
    local cell = math.min(
      (mw - lbl_w - 12 * ui_scale - (DM_COLS - 1) * cell_gap) / DM_COLS,
      (mh - 8 * ui_scale - (DM_ROWS - 1) * cell_gap) / DM_ROWS)
    cell = math.max(2, cell)
    local cw, ch = cell, cell
    local grid_w = DM_COLS * cw + (DM_COLS - 1) * cell_gap
    local grid_h = DM_ROWS * ch + (DM_ROWS - 1) * cell_gap
    local gx0 = mx + math.max(4 * ui_scale, (mw - grid_w - lbl_w) * 0.5)
    local gy0 = my + math.max(4 * ui_scale, (mh - grid_h) * 0.5)

    local envs = {mega_state.env_lo or 0, mega_state.env_mid or 0,
                  mega_state.env_hi or 0, mega_state.env_air or 0}

    dm_frame = dm_frame + 1
    local dm_t = dm_frame * 0.025

    for row = 0, DM_ROWS - 1 do
      local bi = math.floor(row / 2) + 1          -- rows 0-1 LO, 2-3 MID, ...
      local band = DM_BANDS[bi]
      local bval = math.min(1.0, envs[bi] * band.scale)
      for col = 0, DM_COLS - 1 do
        local ci = row * DM_COLS + col
        local phase = math.sin(dm_t * ((ci * 0.37 + row * 1.1) * 0.1) + col * 0.5 + row * 0.8)
        local target = math.max(0, math.min(1, phase * bval * 1.3))
        local cur = dm_cells[ci] or 0
        cur = cur + (target - cur) * 0.15
        dm_cells[ci] = cur

        -- The amps draw on black and scale the colour by cell brightness,
        -- which is what makes the grid glow rather than blink. Same here.
        local a = math.max(0.03, cur * 0.9)
        local col_rgba = (math.floor(band.r * a * 255) << 24)
                       | (math.floor(band.g * a * 255) << 16)
                       | (math.floor(band.b * a * 255) << 8) | 0xFF
        local cx = gx0 + col * (cw + cell_gap)
        local cy = gy0 + row * (ch + cell_gap)
        r.ImGui_DrawList_AddRectFilled(dl, cx, cy, cx + cw, cy + ch, col_rgba, 1)
      end
    end

    -- Direct band labels in their own colour: four series, so identity never
    -- rests on the grid alone.
    for bi = 1, 4 do
      local band = DM_BANDS[bi]
      local ly = gy0 + (bi - 1) * 2 * (ch + cell_gap) + ch * 0.5
      local col_rgba = (math.floor(band.r * 255) << 24) | (math.floor(band.g * 255) << 16)
                     | (math.floor(band.b * 255) << 8) | 0xFF
      r.ImGui_DrawList_AddText(dl, gx0 + grid_w + 6 * ui_scale, ly, col_rgba, band.name)
    end
    r.ImGui_Dummy(ctx, mw, mh)

    r.ImGui_TextDisabled(ctx, string.format(
      "mid %.2f   high %.2f   air %.2f      (band share of total energy)",
      mega_state.mid_density or 0, mega_state.hi_density or 0, mega_state.air_density or 0))
  end

  if mega_master then
    r.ImGui_Spacing(ctx)
    if r.ImGui_SmallButton(ctx, "Open MEGA##mega_master") then
      toggle_fx(mega_master)
    end
  end

  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)

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

-- ---- Track Setup Tab ----

local setup_selected = {}
local setup_track_name = ""
local setup_track_count = 1


local CAT_ORDER_SETUP = {"amp", "mix", "comp", "gate", "fx", "reverb", "pitch", "drum", "synth", "seq"}

local function draw_track_setup(ctx)
  r.ImGui_Text(ctx, "Select plugins, then add to existing track or create new.")
  r.ImGui_Separator(ctx)

  -- Plugin checklist by category
  for _, cat in ipairs(CAT_ORDER_SETUP) do
    local cat_items = {}
    for type_id, info in pairs(TYPE_REGISTRY) do
      if info.cat == cat and info.jsfx then
        cat_items[#cat_items + 1] = {type_id = type_id, info = info}
      end
    end
    if #cat_items > 0 then
      table.sort(cat_items, function(a, b) return a.info.name < b.info.name end)
      local color = CAT_COLORS[cat] or 0xAAAAAAFF
      r.ImGui_PushStyleColor(ctx, ColHeader, color)
      if r.ImGui_CollapsingHeader(ctx, cat:upper() .. " (" .. #cat_items .. ")##setup_" .. cat, r.ImGui_TreeNodeFlags_DefaultOpen()) then
        for _, item in ipairs(cat_items) do
          local checked = setup_selected[item.type_id] or false
          local changed, new_val = r.ImGui_Checkbox(ctx, item.info.name .. "##setup_" .. item.type_id, checked)
          if changed then setup_selected[item.type_id] = new_val end
        end
      end
      r.ImGui_PopStyleColor(ctx)
    end
  end

  -- Count selected
  local sel_count = 0
  for _, v in pairs(setup_selected) do if v then sel_count = sel_count + 1 end end

  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, string.format("%d plugin(s) selected", sel_count))
  r.ImGui_Spacing(ctx)

  -- Clear / Select All
  if r.ImGui_SmallButton(ctx, "Clear All##setup_clear") then
    setup_selected = {}
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_SmallButton(ctx, "Select All##setup_selall") then
    for type_id, info in pairs(TYPE_REGISTRY) do
      if info.jsfx then setup_selected[type_id] = true end
    end
  end

  r.ImGui_Spacing(ctx)

  -- === CREATE NEW TRACK(S) ===
  r.ImGui_Text(ctx, "Create new track(s):")
  r.ImGui_SetNextItemWidth(ctx, 200)
  local _, new_name = r.ImGui_InputText(ctx, "Track name##setup_name", setup_track_name)
  setup_track_name = new_name
  r.ImGui_SameLine(ctx)
  r.ImGui_SetNextItemWidth(ctx, 60)
  local _, new_count = r.ImGui_InputInt(ctx, "##setup_count", setup_track_count)
  setup_track_count = math.max(1, math.min(32, new_count))
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, "track(s)")

  if sel_count > 0 and r.ImGui_Button(ctx, "Create##setup_create") then
    for ti = 1, setup_track_count do
      local idx = r.CountTracks(0)
      r.InsertTrackAtIndex(idx, true)
      local track = r.GetTrack(0, idx)
      local tname = setup_track_name
      if setup_track_count > 1 then tname = tname .. " " .. ti end
      if tname ~= "" then
        r.GetSetMediaTrackInfo_String(track, "P_NAME", tname, true)
      end
      local c = TRACK_COLORS[(color_idx % #TRACK_COLORS) + 1]
      color_idx = color_idx + 1
      r.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", r.ColorToNative(c[1], c[2], c[3]) | 0x1000000)
      for type_id, info in pairs(TYPE_REGISTRY) do
        if setup_selected[type_id] and info.jsfx then
          add_lms_fx(track, info.jsfx)
        end
      end
    end
    scan_tracks()
  end

  r.ImGui_Spacing(ctx)

  -- === ADD TO EXISTING TRACK ===
  r.ImGui_Text(ctx, "Add to existing track:")
  if sel_count > 0 then
    local num_tracks = r.CountTracks(0)
    for ti = 0, num_tracks - 1 do
      local track = r.GetTrack(0, ti)
      local _, tname = r.GetTrackName(track)
      if r.ImGui_SmallButton(ctx, string.format("T%d: %s##setup_add_%d", ti + 1, tname, ti)) then
        for type_id, info in pairs(TYPE_REGISTRY) do
          if setup_selected[type_id] and info.jsfx then
            add_lms_fx(track, info.jsfx)
          end
        end
        scan_tracks()
      end
    end
  else
    r.ImGui_TextDisabled(ctx, "Select plugins above first.")
  end
end

-- ---- Room Verb Tab (Black In Bluhm) ----
--
-- The room is a send/return, not a master insert. That is the whole shape of
-- this tab, and it is what the first attempt got wrong: with the room on the
-- master every source reached it twice -- summed into the master mix on the
-- dry path, and again individually through its ring on the wet path. Eight
-- delayed copies against the original is comb filtering, and through an FDN
-- with a long tail it rings.
--
-- So enabling builds the whole topology instead:
--   - a bus of its own, ROOM VERB, with nothing routed into it
--   - Black In Bluhm on that bus at 100% wet, in Band mode
--   - a Bluhm Send at the end of every source track's chain, one slot each
--
-- The direct sound is the source tracks going to the master as they always
-- did. The room sound is the rings the sends publish into. Nothing arrives
-- twice, and the bus carries only reverb because its dry path has no input.
--
-- Each source also gets a real REAPER send to the bus, at -inf. It carries no
-- audio and is not meant to: the room hears the ring, not the send. What it
-- buys is ORDER. REAPER's anticipative FX processing renders tracks ahead on
-- separate threads by different amounts, and two tracks drifting hundreds of
-- milliseconds apart is what made the first working version wobble -- sources
-- timing out of the ring handshake and dropping their reflections, one at a
-- time. A receive makes the bus depend on its sources, so the graph keeps them
-- together. The volume stays at -inf so the dry path can never double the
-- direct sound, even if the wet mix comes down off 100%.

local ROOM_BUS_NAME = "ROOM VERB"
local BLUHM_SEND_SLOTS = 8

-- Find Black In Bluhm wherever it lives: its own bus, some other track, or the
-- master in a project built before this tab moved it off there.
local function find_room()
  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    local has, fi = track_has_fx_type(track, 36)
    if has then return track, fi end
  end
  local master = r.GetMasterTrack(0)
  if master then
    local has, fi = track_has_fx_type(master, 36)
    if has then return master, fi end
  end
  return nil, nil
end

local function find_room_bus()
  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    local _, name = r.GetTrackName(track)
    if name:upper() == ROOM_BUS_NAME then return track end
  end
  return nil
end

-- The silent send that pins the bus behind its sources in the routing graph.
-- Returns true if it made one, false if the track already had it.
local function ensure_order_send(track, bus)
  for si = 0, r.GetTrackNumSends(track, 0) - 1 do
    local dest = r.GetTrackSendInfo_Value(track, 0, si, "P_DESTTRACK")
    -- P_DESTTRACK comes back as a track pointer; compare it both ways rather
    -- than assuming which representation this REAPER hands us.
    if dest == bus or tostring(dest) == tostring(bus) then return false end
  end
  local si = r.CreateTrackSend(track, bus)
  if si and si >= 0 then
    r.SetTrackSendInfo_Value(track, 0, si, "D_VOL", 0)  -- -inf: ordering only
    return true
  end
  return false
end

local function remove_order_sends(bus)
  local removed = 0
  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    for si = r.GetTrackNumSends(track, 0) - 1, 0, -1 do
      local dest = r.GetTrackSendInfo_Value(track, 0, si, "P_DESTTRACK")
      if dest == bus or tostring(dest) == tostring(bus) then
        r.RemoveTrackSend(track, 0, si)
        removed = removed + 1
      end
    end
  end
  return removed
end

-- Put a Bluhm Send on every source track and hand each one its own slot.
-- Returns placed, skipped_children, over.
--
-- Folder children are skipped. A folder is already a submix, so its parent
-- carries the whole group's audio; sending the children as well would put the
-- same signal in the room several times over, once per member and again for
-- the bus. Only tracks with no parent get a send -- a folder parent stands for
-- its group, a plain top-level track for itself.
local function room_place_sends(bus)
  local placed, skipped_children, over = 0, 0, 0

  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    if track ~= bus then
      if r.GetParentTrack(track) then
        skipped_children = skipped_children + 1
      elseif placed >= BLUHM_SEND_SLOTS then
        over = over + 1
      else
        local has, fx = track_has_fx_type(track, "room_send")
        if not has then fx = add_lms_fx(track, "lms_room_send.jsfx") end
        if fx and fx >= 0 then
          -- The tap belongs dead last: the room should hear the track the way
          -- the master hears it, after the amp and the strip.
          local last = r.TrackFX_GetCount(track) - 1
          if fx < last then
            r.TrackFX_CopyToTrack(track, fx, track, last, true)
            fx = last
          end
          -- slider1 is Slot, 1-based in the UI, and JSFX params take raw
          -- values -- a normalised one rounds to the same slot for everybody.
          r.TrackFX_SetParam(track, fx, 0, placed + 1)
          ensure_order_send(track, bus)
          placed = placed + 1
        end
      end
    end
  end

  return placed, skipped_children, over
end

local function room_verb_enable()
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local master = r.GetMasterTrack(0)
  local room_track, room_fi = find_room()

  -- 1. The return bus. Adopt one that already exists, or a track someone has
  --    already parked the room on; otherwise make one at the end of the list.
  local bus = find_room_bus()
  local fresh_bus = false
  if not bus then
    if room_track and room_track ~= master then
      bus = room_track
      r.GetSetMediaTrackInfo_String(bus, "P_NAME", ROOM_BUS_NAME, true)
    else
      local idx = r.CountTracks(0)
      r.InsertTrackAtIndex(idx, true)
      bus = r.GetTrack(0, idx)
      fresh_bus = true
      r.GetSetMediaTrackInfo_String(bus, "P_NAME", ROOM_BUS_NAME, true)
      r.SetMediaTrackInfo_Value(bus, "I_FOLDERDEPTH", 0)
      r.SetMediaTrackInfo_Value(bus, "I_CUSTOMCOLOR",
        r.ColorToNative(90, 110, 150) | 0x1000000)
    end
  end

  -- 2. The room, on that bus and nowhere else.
  local fi
  local fresh_room = false
  if room_track == bus then
    fi = room_fi
  elseif room_track then
    -- Moving it keeps the room the user already tuned, rather than replacing
    -- it with a default one and losing the shape.
    r.TrackFX_CopyToTrack(room_track, room_fi, bus, r.TrackFX_GetCount(bus), true)
    local _, moved_fi = track_has_fx_type(bus, 36)
    fi = moved_fi
  else
    fi = add_lms_fx(bus, "lms_room.jsfx")
    fresh_room = true
  end

  if fi and fi >= 0 then
    if fresh_room then
      r.TrackFX_SetParam(bus, fi, 0, 4)    -- walls
      r.TrackFX_SetParam(bus, fi, 4, 1)    -- wall material
      r.TrackFX_SetParam(bus, fi, 5, 1)    -- floor material
      r.TrackFX_SetParam(bus, fi, 6, 2)    -- ceiling material
      r.TrackFX_SetParam(bus, fi, 14, 50)  -- reverb tail
    end
    -- 100% wet, always: on a return the dry path is the direct sound arriving
    -- a second time. Band mode, so the room reads the rings the sends publish
    -- into instead of this track's own (silent) input.
    r.TrackFX_SetParam(bus, fi, 15, 100)
    r.TrackFX_SetParam(bus, fi, 21, 1)
  end

  -- 3. The sends.
  local placed, skipped_children, over = room_place_sends(bus)

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("Room Verb: build room bus, sends and 100% wet return", -1)
  room_verb_enabled = true
  scan_tracks()

  r.ShowConsoleMsg(string.format(
    "LMS Room Verb: %s at 100%% wet on '%s'%s, %d source(s) sending, "
    .. "%d folder child(ren) skipped (their parent carries them)%s\n",
    fresh_room and "Black In Bluhm added" or "Black In Bluhm moved",
    ROOM_BUS_NAME,
    fresh_bus and " (new bus)" or "",
    placed, skipped_children,
    over > 0 and string.format(", %d track(s) left out -- only %d slots exist",
      over, BLUHM_SEND_SLOTS) or ""))
end

-- Remove everything enable built: the room, every Bluhm Send, and the bus
-- itself if it is now the empty track we made. A bus the user put anything
-- else on -- another plugin, an item -- is left alone and just emptied.
local function room_verb_disable()
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local function strip(track)
    local removed_room, removed_send = 0, 0
    for fi = r.TrackFX_GetCount(track) - 1, 0, -1 do
      local _, fx_name = r.TrackFX_GetFXName(track, fi)
      local lms_name, override = extract_lms_name(fx_name)
      local tid = override or (lms_name and JSFX_TO_TYPE[lms_name])
      if tid == 36 then
        r.TrackFX_Delete(track, fi)
        removed_room = removed_room + 1
      elseif tid == "room_send" then
        r.TrackFX_Delete(track, fi)
        removed_send = removed_send + 1
      end
    end
    return removed_room, removed_send
  end

  local rooms, sends = 0, 0
  for ti = r.CountTracks(0) - 1, 0, -1 do
    local a, b = strip(r.GetTrack(0, ti))
    rooms, sends = rooms + a, sends + b
  end
  local master = r.GetMasterTrack(0)
  if master then
    local a = strip(master)
    rooms = rooms + a
  end

  local bus_removed = false
  local bus = find_room_bus()
  if bus then
    remove_order_sends(bus)
    if r.TrackFX_GetCount(bus) == 0 and r.CountTrackMediaItems(bus) == 0 then
      r.DeleteTrack(bus)
      bus_removed = true
    end
  end

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("Room Verb: remove the room, its sends and its bus", -1)
  room_verb_enabled = false
  scan_tracks()

  r.ShowConsoleMsg(string.format(
    "LMS Room Verb: removed %d room, %d send(s)%s\n",
    rooms, sends, bus_removed and (", and the empty " .. ROOM_BUS_NAME .. " bus") or ""))
end

-- Deletes every Bluhm Send anywhere, including the ones on folder children
-- that setup skips on purpose and therefore never renumbers -- those keep
-- publishing into a slot that has since been handed to someone else, and
-- nothing in the normal flow clears them.
local function room_strip_all_sends()
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local removed = 0
  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    for fi = r.TrackFX_GetCount(track) - 1, 0, -1 do
      local _, fx_name = r.TrackFX_GetFXName(track, fi)
      local lms_name, override = extract_lms_name(fx_name)
      local tid = override or (lms_name and JSFX_TO_TYPE[lms_name])
      if tid == "room_send" then
        r.TrackFX_Delete(track, fi)
        removed = removed + 1
      end
    end
  end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("Room Verb: strip every Bluhm Send", -1)
  scan_tracks()
  r.ShowConsoleMsg(string.format("LMS Room Verb: removed %d Bluhm Send(s) everywhere
", removed))
end

local function draw_room_verb(ctx)
  local room, fi = find_room()
  local alive = room ~= nil and fi ~= nil
  local room_name = ""
  if alive then
    local _, n = r.GetTrackName(room)
    room_name = n
  end

  r.ImGui_Text(ctx, alive
    and ("Black In Bluhm ONLINE — " .. room_name)
    or "Black In Bluhm OFFLINE")
  r.ImGui_Spacing(ctx)

  if not alive then
    r.ImGui_TextWrapped(ctx,
      "Builds the whole room in one click: a " .. ROOM_BUS_NAME .. " bus with Black In "
      .. "Bluhm on it at 100% wet in Band mode, and a Bluhm Send at the end of every "
      .. "source track's chain, each with its own slot.")
    r.ImGui_Spacing(ctx)
    r.ImGui_TextWrapped(ctx,
      "Your tracks keep going to the master, which is the direct sound. The sends "
      .. "publish them into the room, which is the only thing the bus carries. Folder "
      .. "children are skipped — the folder parent already carries them.")
    r.ImGui_Spacing(ctx)
    if r.ImGui_Button(ctx, "Enable Room Verb") then
      room_verb_enable()
    end
    return
  end

  room_verb_enabled = true

  if r.ImGui_Button(ctx, "Disable / Remove") then
    room_verb_disable()
    return
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Open Plugin Window") then
    r.TrackFX_SetOpen(room, fi, true)
  end
  r.ImGui_SameLine(ctx)
  -- Tracks added after the room was built have no send yet, and this is
  -- cheaper than tearing the whole thing down to get one.
  if r.ImGui_Button(ctx, "Send New Tracks") then
    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)
    local placed, skipped, over = room_place_sends(room)
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("Room Verb: send new tracks to the room", -1)
    scan_tracks()
    r.ShowConsoleMsg(string.format(
      "LMS Room Verb: %d source(s) sending, %d folder child(ren) skipped%s\n",
      placed, skipped,
      over > 0 and string.format(", %d left out -- only %d slots exist",
        over, BLUHM_SEND_SLOTS) or ""))
  end
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_SetTooltip(ctx,
      "Re-walks the track list and gives any top-level track without a Bluhm Send one,\n"
      .. "re-numbering the slots. Run it after adding tracks.")
  end

  -- How many sends exist, not how many the room can hear: the room's own
  -- display counts live ring slots, and a send that is bypassed or sharing a
  -- slot will show up here and not there.
  local send_count = 0
  for ti = 0, r.CountTracks(0) - 1 do
    local track = r.GetTrack(0, ti)
    if track ~= room and track_has_fx_type(track, "room_send") then
      send_count = send_count + 1
    end
  end
  r.ImGui_Spacing(ctx)
  r.ImGui_TextDisabled(ctx, string.format(
    "%d Bluhm Send(s) placed of %d slots", send_count, BLUHM_SEND_SLOTS))

  r.ImGui_SameLine(ctx)
  if r.ImGui_SmallButton(ctx, "Strip All Sends") then
    room_strip_all_sends()
  end
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_SetTooltip(ctx,
      "Deletes every Bluhm Send in the project, including ones on folder children\n"
      .. "that setup skips. Follow with Enable Room Verb for a clean numbering.")
  end

  -- A room that is not a return is the exact fault that made the first band
  -- setup ring: on the master, or with a live dry path, every source reaches
  -- it twice. Say so, and offer the one button that fixes it.
  local wet_now = r.TrackFX_GetParam(room, fi, 15)
  local band_now = math.floor(r.TrackFX_GetParam(room, fi, 21) + 0.5)
  local off_bus = room ~= find_room_bus()
  if off_bus or band_now ~= 1 or wet_now < 99.5 then
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xE6CC88FF)
    r.ImGui_TextWrapped(ctx, off_bus
      and ("This room is an insert on '" .. room_name .. "', not a return. Every source "
           .. "reaches it twice that way — once dry through the mix and once through its "
           .. "ring — which combs and rings.")
      or "This room is not set up as a return: it wants Band mode at 100% wet, or the "
         .. "dry path puts the sources in it a second time.")
    r.ImGui_PopStyleColor(ctx)
    if r.ImGui_Button(ctx, "Rebuild as send/return") then
      room_verb_enable()
      return
    end
  end

  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_Spacing(ctx)

  -- Room shape
  if r.ImGui_CollapsingHeader(ctx, "Room Shape", r.ImGui_TreeNodeFlags_DefaultOpen()) then
    r.ImGui_SetNextItemWidth(ctx, 150)
    local walls_val = math.floor(r.TrackFX_GetParam(room, fi, 0) + 0.5)
    local wc, wn = r.ImGui_SliderInt(ctx, "Walls", walls_val, 3, 12)
    if wc then r.TrackFX_SetParam(room, fi, 0, wn) end

    -- JSFX params come back as the slider's own value, not 0..1 -- the same
    -- thing the Bloody Glue slot collision turned on. These four read and
    -- wrote them as if they were normalised, so Width showed 67 for a 5 m room
    -- and dragging it set 0.23 m.
    r.ImGui_SetNextItemWidth(ctx, 150)
    local width_val = r.TrackFX_GetParam(room, fi, 1)
    local rwc, rwn = r.ImGui_SliderDouble(ctx, "Width (m)", width_val, 2, 15, "%.1f")
    if rwc then r.TrackFX_SetParam(room, fi, 1, rwn) end

    r.ImGui_SameLine(ctx)
    r.ImGui_SetNextItemWidth(ctx, 150)
    local depth_val = r.TrackFX_GetParam(room, fi, 2)
    local rdc, rdn = r.ImGui_SliderDouble(ctx, "Depth (m)", depth_val, 2, 15, "%.1f")
    if rdc then r.TrackFX_SetParam(room, fi, 2, rdn) end

    r.ImGui_SetNextItemWidth(ctx, 150)
    local height_val = r.TrackFX_GetParam(room, fi, 3)
    local rhc, rhn = r.ImGui_SliderDouble(ctx, "Height (m)", height_val, 2, 6, "%.1f")
    if rhc then r.TrackFX_SetParam(room, fi, 3, rhn) end
  end

  -- Materials
  if r.ImGui_CollapsingHeader(ctx, "Materials", r.ImGui_TreeNodeFlags_DefaultOpen()) then
    local wall_mat = math.floor(r.TrackFX_GetParam(room, fi, 4) + 0.5)
    local floor_mat = math.floor(r.TrackFX_GetParam(room, fi, 5) + 0.5)
    local ceil_mat = math.floor(r.TrackFX_GetParam(room, fi, 6) + 0.5)

    r.ImGui_SetNextItemWidth(ctx, 150)
    if r.ImGui_BeginCombo(ctx, "Walls##mat_walls", MAT_NAMES[wall_mat + 1] or "?") then
      for mi = 0, 7 do
        if r.ImGui_Selectable(ctx, MAT_NAMES[mi + 1], mi == wall_mat) then
          r.TrackFX_SetParam(room, fi, 4, mi)
        end
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_SetNextItemWidth(ctx, 150)
    if r.ImGui_BeginCombo(ctx, "Floor##mat_floor", MAT_NAMES[floor_mat + 1] or "?") then
      for mi = 0, 7 do
        if r.ImGui_Selectable(ctx, MAT_NAMES[mi + 1], mi == floor_mat) then
          r.TrackFX_SetParam(room, fi, 5, mi)
        end
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_SetNextItemWidth(ctx, 150)
    if r.ImGui_BeginCombo(ctx, "Ceiling##mat_ceil", MAT_NAMES[ceil_mat + 1] or "?") then
      for mi = 0, 7 do
        if r.ImGui_Selectable(ctx, MAT_NAMES[mi + 1], mi == ceil_mat) then
          r.TrackFX_SetParam(room, fi, 6, mi)
        end
      end
      r.ImGui_EndCombo(ctx)
    end
  end

  -- Output
  if r.ImGui_CollapsingHeader(ctx, "Output", r.ImGui_TreeNodeFlags_DefaultOpen()) then
    r.ImGui_SetNextItemWidth(ctx, 200)
    local tail_val = math.floor(r.TrackFX_GetParam(room, fi, 14) + 0.5)
    local tc, tn = r.ImGui_SliderInt(ctx, "Reverb Tail %%", tail_val, 0, 100)
    if tc then r.TrackFX_SetParam(room, fi, 14, tn) end

    r.ImGui_SetNextItemWidth(ctx, 200)
    local mix_val = math.floor(r.TrackFX_GetParam(room, fi, 15) + 0.5)
    local mc, mn = r.ImGui_SliderInt(ctx, "Wet Mix %%", mix_val, 0, 100)
    if mc then r.TrackFX_SetParam(room, fi, 15, mn) end

    r.ImGui_SetNextItemWidth(ctx, 200)
    local gain_val = r.TrackFX_GetParam(room, fi, 16)
    local gc, gn = r.ImGui_SliderDouble(ctx, "Output Gain (dB)", gain_val, -12, 12, "%.1f")
    if gc then r.TrackFX_SetParam(room, fi, 16, gn) end
  end

  -- Compressor
  if r.ImGui_CollapsingHeader(ctx, "Compressor") then
    local comp_val = math.floor(r.TrackFX_GetParam(room, fi, 17) + 0.5)
    local COMP_NAMES = {"Off", "LA2A", "1176", "Distressor"}
    r.ImGui_SetNextItemWidth(ctx, 150)
    if r.ImGui_BeginCombo(ctx, "Type##comp", COMP_NAMES[comp_val + 1] or "?") then
      for ci = 0, 3 do
        if r.ImGui_Selectable(ctx, COMP_NAMES[ci + 1], ci == comp_val) then
          r.TrackFX_SetParam(room, fi, 17, ci)
        end
      end
      r.ImGui_EndCombo(ctx)
    end

    if comp_val > 0 then
      r.ImGui_SetNextItemWidth(ctx, 200)
      local amt_val = math.floor(r.TrackFX_GetParam(room, fi, 18) + 0.5)
      local ac, an = r.ImGui_SliderInt(ctx, "Amount", amt_val, 0, 100)
      if ac then r.TrackFX_SetParam(room, fi, 18, an) end

      r.ImGui_SetNextItemWidth(ctx, 200)
      local inp_val = r.TrackFX_GetParam(room, fi, 19)
      local ic, inv = r.ImGui_SliderDouble(ctx, "Input (dB)", inp_val, -12, 24, "%.1f")
      if ic then r.TrackFX_SetParam(room, fi, 19, inv) end

      local ratio_val = math.floor(r.TrackFX_GetParam(room, fi, 20) + 0.5)
      local RATIO_NAMES = {"2:1", "4:1", "8:1", "20:1"}
      r.ImGui_SetNextItemWidth(ctx, 150)
      if r.ImGui_BeginCombo(ctx, "Ratio", RATIO_NAMES[ratio_val + 1] or "?") then
        for ri = 0, 3 do
          if r.ImGui_Selectable(ctx, RATIO_NAMES[ri + 1], ri == ratio_val) then
            r.TrackFX_SetParam(room, fi, 20, ri)
          end
        end
        r.ImGui_EndCombo(ctx)
      end
    end
  end

end

-- ---- Main Window ----

local function draw_main(ctx)
  r.ImGui_PushFont(ctx, nil, math.floor(13 * ui_scale))
  local visible, open = r.ImGui_Begin(ctx, "LMS Plugin Manager", true, FlagsNone)
  if visible then
    local win_w = r.ImGui_GetWindowWidth(ctx)
    ui_scale = math.max(0.6, math.min(2.0, win_w / 600))

    -- Space runs the transport, the way it does everywhere else in REAPER.
    -- While this window has focus ImGui swallows the key, so hand it back.
    -- Skipped whenever a widget is active, or space could never reach the
    -- rename box or any other text field.
    if r.ImGui_IsWindowFocused(ctx, r.ImGui_FocusedFlags_RootAndChildWindows())
      and not r.ImGui_IsAnyItemActive(ctx)
      and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Space(), false) then
      r.Main_OnCommand(40044, 0)  -- Transport: Play/stop
    end
    if logo and r.ImGui_ValidatePtr(logo, "ImGui_Image*") then
      local lh = math.floor(28 * ui_scale)
      local lw = math.floor(lh * (200 / 112))
      r.ImGui_Image(ctx, logo, lw, lh)
      r.ImGui_SameLine(ctx)
    end
    if r.ImGui_Button(ctx, "Rescan Tracks") then
      scan_tracks()
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Close All Plugin Windows") then
      for _, inst in ipairs(instances) do
        if r.ValidatePtr(inst.track, "MediaTrack*") then
          r.TrackFX_SetOpen(inst.track, inst.fx_idx, false)
        end
      end
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, string.format("(%d instances)", #instances))
    r.ImGui_SameLine(ctx)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x332B1AFF)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x44382288)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xE6CC88FF)
    if r.ImGui_Button(ctx, "NOTICE") then
      notice_open = not notice_open
    end
    r.ImGui_PopStyleColor(ctx, 3)
    r.ImGui_SameLine(ctx, r.ImGui_GetWindowWidth(ctx) - 80)
    r.ImGui_TextDisabled(ctx, string.format("%.0f%%", ui_scale * 100))

    if notice_open then
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xE6CC88FF)
      r.ImGui_TextWrapped(ctx, "NOTICE: THEY ARE TRYING TO STEAL YOUR COMPUTER")
      r.ImGui_PopStyleColor(ctx)
      r.ImGui_TextWrapped(ctx, "The algorithms in our favorite software are decades old. A mathematical model is a truth about the world, not a copyrightable product. You do not have to stay a slave to subscription software. Install Linux. Build your own tools. Believe in yourself.")
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x80B3FFFF)
      r.ImGui_Text(ctx, "github.com/LMSBAND  |  instagram.com/LMSSKABAND")
      r.ImGui_PopStyleColor(ctx)
    end

    r.ImGui_Spacing(ctx)

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
      if r.ImGui_BeginTabItem(ctx, "Track Setup") then
        draw_track_setup(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Room Verb") then
        draw_room_verb(ctx)
        r.ImGui_EndTabItem(ctx)
      end
      r.ImGui_EndTabBar(ctx)
    end

    r.ImGui_End(ctx)
  end
  r.ImGui_PopFont(ctx)

  return open
end

-- ============================================================================
-- Main Loop
-- ============================================================================

scan_tracks()

local last_time = r.time_precise()

local function loop()
  local now = r.time_precise()
  if now - last_time > SCAN_INTERVAL then
    scan_tracks()
    last_time = now
  end

  -- Apply follow relationships every frame
  apply_follows()

  -- Read gmem for non-broadcast plugins
  read_drumbanger_state()
  read_harmony_state()
  update_drones()
  read_pitch_state()
  read_mega_state()

  -- Sync DrumBanger per-pad routing flags every frame
  sync_drumbanger_routing()

  -- Process queued commands (one per frame each)
  flush_hm_cmd_queue()
  flush_db_step_queue()
  process_builder_queue()
  sync_song_markers()

  local open = draw_main(ctx)

  if open then
    r.defer(loop)
  end
end

r.defer(loop)
