-- ==========================================================================
-- LMS Hardware Bridge - Lua FX Parameter Controller
-- ==========================================================================
-- Run this as a background ReaScript in REAPER.
-- It reads the state file from the Python serial daemon (or fake ESP32)
-- and calls TrackFX_SetParamNormalized() to move actual plugin sliders.
--
-- No JSFX modifications needed. Works with any plugin. Sliders move,
-- automation records, what you see is what you get.
--
-- CONTROLS:
--   6 pots, 4 buttons (all momentary toggle)
--   Button 0: Effects On/Off (slider7 FX Bypass)
--   Button 1: Cab A/B select (pot 5 controls Cabinet A or B)
--   Button 2: REAPER bypass (TrackFX_SetEnabled)
--   Button 3: Bank toggle (bank 1 = amp, bank 2 = effects+cab)
--
-- BANK 1 (Amp):
--   Pot 0: Input Level   (s1)    Pot 3: Input Stage  (s4)
--   Pot 1: Gain          (s2)    Pot 4: PSU Sag      (s5)
--   Pot 2: Tone          (s3)    Pot 5: Output Level  (s6)
--
-- BANK 2 (Effects + Cab):
--   Pot 0: Spring Reverb (s8)    Pot 3: Echo Mix     (s18)
--   Pot 1: Trem Depth    (s10)   Pot 4: Echo Time    (s19)
--   Pot 2: Trem Speed    (s11)   Pot 5: Cab Select   (s12 or s15)
--
-- ==========================================================================

local HOME = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
local STATE_FILE = HOME .. "/.config/REAPER/Scripts/lms_hw_state.json"

local last_timestamp = 0
local current_bank = 0    -- 0 = amp, 1 = effects+cab
local cab_ab = 0          -- 0 = cab A (s12), 1 = cab B (s15)
local last_bank_sw = 0    -- for edge detection on bank toggle
local last_cab_sw = 0     -- for edge detection on cab A/B

-- =========================================================================
-- DEVICE PROFILES
-- =========================================================================

local PROFILES = {
  [1] = {
    fx_pattern = "LMS",
    -- Bank 0: Amp controls (param index = slider - 1)
    bank = {
      [0] = {
        [0] = 0,   -- pot 0 → param 0  (Input Level, s1)
        [1] = 1,   -- pot 1 → param 1  (Gain, s2)
        [2] = 2,   -- pot 2 → param 2  (Tone, s3)
        [3] = 3,   -- pot 3 → param 3  (Input Stage, s4)
        [4] = 4,   -- pot 4 → param 4  (PSU Sag, s5)
        [5] = 5,   -- pot 5 → param 5  (Output Level, s6)
      },
      -- Bank 1: Effects + Cab
      [1] = {
        [0] = 7,   -- pot 0 → param 7  (Spring Reverb, s8)
        [1] = 9,   -- pot 1 → param 9  (Trem Depth, s10)
        [2] = 10,  -- pot 2 → param 10 (Trem Speed, s11)
        [3] = 17,  -- pot 3 → param 17 (Echo Mix, s18)
        [4] = 18,  -- pot 4 → param 18 (Echo Time, s19)
        -- pot 5 handled specially (cab A or B based on cab_ab toggle)
      },
    },
    -- Cab select param indices (slider - 1)
    cab_a_param = 11,  -- Cabinet A (s12, param 11)
    cab_b_param = 14,  -- Cabinet B (s15, param 14)
    -- FX bypass param
    fx_bypass_param = 6,  -- s7, param 6
  },
}

-- =========================================================================
-- Tiny JSON parser
-- =========================================================================

local function parse_json_value(str, pos)
  pos = str:find("[^ \t\n\r]", pos) or pos
  local c = str:sub(pos, pos)

  if c == '"' then
    local close = str:find('"', pos + 1)
    return str:sub(pos + 1, close - 1), close + 1
  elseif c == '{' then
    local obj = {}
    pos = pos + 1
    while true do
      pos = str:find("[^ \t\n\r]", pos) or pos
      if str:sub(pos, pos) == '}' then return obj, pos + 1 end
      if str:sub(pos, pos) == ',' then pos = pos + 1 end
      pos = str:find("[^ \t\n\r]", pos) or pos
      if str:sub(pos, pos) == '}' then return obj, pos + 1 end
      local key, val
      key, pos = parse_json_value(str, pos)
      pos = str:find(":", pos)
      pos = pos + 1
      val, pos = parse_json_value(str, pos)
      obj[key] = val
    end
  elseif c == 't' then
    return true, pos + 4
  elseif c == 'f' then
    return false, pos + 5
  elseif c == 'n' then
    return nil, pos + 4
  else
    local s, e = str:find("[%d%.eE%+%-]+", pos)
    return tonumber(str:sub(s, e)), e + 1
  end
end

local function parse_json(str)
  if not str or str == "" then return nil end
  local ok, result = pcall(parse_json_value, str, 1)
  if ok then return result end
  return nil
end

-- =========================================================================
-- File reader
-- =========================================================================

local function read_state()
  local f = io.open(STATE_FILE, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return parse_json(content)
end

-- =========================================================================
-- Find target FX on the selected track
-- =========================================================================

local function find_fx(track, pattern)
  if not track then return nil end
  local count = reaper.TrackFX_GetCount(track)
  for i = 0, count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, i)
    if name and name:find(pattern) then
      return i
    end
  end
  return nil
end

-- =========================================================================
-- Apply hardware state to plugin parameters
-- =========================================================================

local function apply_state(data)
  if not data then return end
  if not data["ok"] then return end

  -- Check timestamp
  local t = data["t"] or 0
  if t == last_timestamp then return end
  last_timestamp = t

  -- Get device profile
  local dev_type = data["type"] or 0
  local profile = PROFILES[dev_type]
  if not profile then return end

  -- Get selected track
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then return end

  -- Find matching FX on the track
  local fx_idx = find_fx(track, profile.fx_pattern)
  if not fx_idx then return end

  -- Handle switches
  local switches = data["s"]
  if switches and type(switches) == "table" then

    -- Button 3: Bank toggle (edge detect in Lua to track state)
    local bank_sw = tonumber(switches["3"]) or 0
    if bank_sw ~= last_bank_sw then
      current_bank = bank_sw  -- toggle state comes from ESP32
      last_bank_sw = bank_sw
      reaper.ShowConsoleMsg("LMS HW: Bank " .. (current_bank == 0 and "1 (Amp)" or "2 (FX+Cab)") .. "\n")
    end

    -- Button 1: Cab A/B toggle
    local cab_sw = tonumber(switches["1"]) or 0
    if cab_sw ~= last_cab_sw then
      cab_ab = cab_sw
      last_cab_sw = cab_sw
      reaper.ShowConsoleMsg("LMS HW: Cab " .. (cab_ab == 0 and "A" or "B") .. "\n")
    end

    -- Button 0: Effects On/Off (FX Bypass slider inside plugin)
    local fx_sw = tonumber(switches["0"])
    if fx_sw ~= nil then
      reaper.TrackFX_SetParamNormalized(track, fx_idx, profile.fx_bypass_param, fx_sw)
    end

    -- Button 2: REAPER native bypass
    local bypass_sw = tonumber(switches["2"])
    if bypass_sw ~= nil then
      reaper.TrackFX_SetEnabled(track, fx_idx, bypass_sw == 0)
    end
  end

  -- Apply pot values based on current bank
  local pots = data["p"]
  if pots and type(pots) == "table" and profile.bank then
    local bank_map = profile.bank[current_bank]
    if bank_map then
      for ch_str, raw_val in pairs(pots) do
        local ch = tonumber(ch_str)
        if ch then
          -- Bank 1, pot 5: cab select (special handling)
          if current_bank == 1 and ch == 5 then
            local cab_param = cab_ab == 0 and profile.cab_a_param or profile.cab_b_param
            -- Cab is 0-11 (12 options), normalize from 0-1023
            local normalized = raw_val / 1023.0
            reaper.TrackFX_SetParamNormalized(track, fx_idx, cab_param, normalized)
          else
            local param_idx = bank_map[ch]
            if param_idx then
              local normalized = raw_val / 1023.0
              reaper.TrackFX_SetParamNormalized(track, fx_idx, param_idx, normalized)
            end
          end
        end
      end
    end
  end
end

-- =========================================================================
-- Main defer loop (~30fps)
-- =========================================================================

local function main_loop()
  local data = read_state()
  apply_state(data)
  reaper.defer(main_loop)
end

-- =========================================================================
-- Startup
-- =========================================================================

reaper.ShowConsoleMsg("LMS Hardware Bridge: FX parameter controller started\n")
reaper.ShowConsoleMsg("  Watching: " .. STATE_FILE .. "\n")
reaper.ShowConsoleMsg("  Bank 1: Amp | Bank 2: FX+Cab\n")
reaper.ShowConsoleMsg("  Buttons: FX On/Off | Cab A/B | Bypass | Bank\n")

reaper.atexit(function()
  reaper.ShowConsoleMsg("LMS Hardware Bridge: stopped\n")
end)

main_loop()
