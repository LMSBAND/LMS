-- ==========================================================================
-- LMS Hardware Bridge - Lua gmem[] Injector
-- ==========================================================================
-- Run this as a background ReaScript in REAPER.
-- It reads the state file from the Python serial daemon
-- and writes values directly into gmem[] for your JSFX plugins.
--
-- SETUP:
--   1. Put this in <REAPER resource>/Scripts/
--   2. Actions → ReaScript: Load → select this file
--   3. Run it (stays running via defer loop)
--   4. Optional: add to SWS auto-start actions
--
-- GMEM LAYOUT (namespace "LMS"):
--   Base offset = 10000 (adjust to avoid collisions with your plugins)
--
--   [10000] connected     1.0 = hardware present, 0.0 = not
--   [10001] device_type   device ID number
--   [10002] cycle_cmd     increments each time "cycle" button is pressed
--   [10003] reserved
--
--   [10010..10049] pot values, normalized 0.0 to 1.0
--                  pot channel 0 → gmem[10010]
--                  pot channel 1 → gmem[10011]  etc.
--
--   [10050..10069] switch states, 0.0 or 1.0
--   [10070..10089] button states, 0.0 or 1.0
--
--   Your JSFX just reads these. Example in JSFX:
--     options:gmem=LMS
--     @block
--     hw_connected = gmem[10000];
--     gain_knob    = gmem[10010];  // 0.0-1.0 from hardware pot 0
--
-- ==========================================================================

-- CONFIG
local GMEM_NS       = "DrumBanger"
local BASE           = 10000
local POTS_OFF       = BASE + 10
local SWITCHES_OFF   = BASE + 50
local BUTTONS_OFF    = BASE + 70

local HOME = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
local STATE_FILE = HOME .. "/.config/REAPER/Scripts/lms_hw_state.json"

local cycle_counter = 0
local last_timestamp = 0

-- Attach to the LMS shared memory namespace
reaper.gmem_attach(GMEM_NS)

-- -------------------------------------------------------------------------
-- Tiny JSON parser — only needs to handle our flat state structure
-- -------------------------------------------------------------------------

local function parse_json_value(str, pos)
  -- skip whitespace
  pos = str:find("[^ \t\n\r]", pos) or pos
  local c = str:sub(pos, pos)

  if c == '"' then
    -- string
    local close = str:find('"', pos + 1)
    return str:sub(pos + 1, close - 1), close + 1

  elseif c == '{' then
    -- object
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
    -- number
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

-- -------------------------------------------------------------------------
-- File reader
-- -------------------------------------------------------------------------

local function read_state()
  local f = io.open(STATE_FILE, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return parse_json(content)
end

-- -------------------------------------------------------------------------
-- gmem writer
-- -------------------------------------------------------------------------

local function update_gmem(data)
  if not data then
    reaper.gmem_write(BASE, 0)  -- not connected
    return
  end

  -- Check timestamp — skip if file hasn't changed
  local t = data["t"] or 0
  if t == last_timestamp then return end
  last_timestamp = t

  -- Connection status
  local connected = data["ok"] and 1.0 or 0.0
  reaper.gmem_write(BASE, connected)

  -- Device type
  reaper.gmem_write(BASE + 1, data["type"] or 0)

  -- Pots → normalized 0.0-1.0
  local pots = data["p"]
  if pots and type(pots) == "table" then
    for ch, val in pairs(pots) do
      local idx = tonumber(ch)
      if idx then
        reaper.gmem_write(POTS_OFF + idx, val / 1023.0)
      end
    end
  end

  -- Switches
  local switches = data["s"]
  if switches and type(switches) == "table" then
    for ch, val in pairs(switches) do
      local idx = tonumber(ch)
      if idx then
        reaper.gmem_write(SWITCHES_OFF + idx, val)
      end
    end
  end

  -- Buttons
  local buttons = data["b"]
  if buttons and type(buttons) == "table" then
    for ch, val in pairs(buttons) do
      local idx = tonumber(ch)
      if idx then
        reaper.gmem_write(BUTTONS_OFF + idx, val)
      end
    end
  end

  -- Commands
  local cmd = data["cmd"]
  if cmd and cmd ~= "" then
    if cmd == "cycle" then
      cycle_counter = cycle_counter + 1
      reaper.gmem_write(BASE + 2, cycle_counter)
    end
  end
end

-- -------------------------------------------------------------------------
-- Main defer loop (~30fps, matches REAPER's internal rate)
-- -------------------------------------------------------------------------

local function main_loop()
  local data = read_state()
  update_gmem(data)
  reaper.defer(main_loop)
end

-- -------------------------------------------------------------------------
-- Startup
-- -------------------------------------------------------------------------

reaper.ShowConsoleMsg("LMS Hardware Bridge: Lua gmem injector started\n")
reaper.ShowConsoleMsg("  Namespace: " .. GMEM_NS .. "\n")
reaper.ShowConsoleMsg("  Base offset: " .. BASE .. "\n")
reaper.ShowConsoleMsg("  Watching: " .. STATE_FILE .. "\n")

-- Clear hardware slots on start
reaper.gmem_write(BASE, 0)
reaper.gmem_write(BASE + 1, 0)
reaper.gmem_write(BASE + 2, 0)

-- Clean up on exit
reaper.atexit(function()
  reaper.gmem_write(BASE, 0)
  reaper.ShowConsoleMsg("LMS Hardware Bridge: stopped\n")
end)

-- Go!
main_loop()
