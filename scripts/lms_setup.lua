-- LMS Suite Setup
-- Run this ONCE. It registers the DrumBanger service as an action,
-- starts it, and installs __startup.lua so it auto-runs
-- every time you open REAPER.

-- Check for ReaImGui (required by Plugin Manager)
if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox(
    "ReaImGui is not installed!\n\n" ..
    "The LMS Plugin Manager requires ReaImGui.\n\n" ..
    "To install it:\n" ..
    "1. Extensions > ReaPack > Browse packages\n" ..
    "2. Search for exactly: ReaImGui\n" ..
    "   (capital R, capital I, capital G)\n" ..
    "3. Install the one by cfillion\n" ..
    "4. Click Apply, then run this setup again.",
    "LMS Setup — Missing Dependency", 0)
  return
end

-- Find the service script (same directory as this setup script)
local info = debug.getinfo(1, "S")
local script_dir = info.source:match("@?(.+)[/\\]")
local service_path = script_dir .. "/drumbanger_service.lua"

-- Verify the service script exists
local f = io.open(service_path, "r")
if not f then
  reaper.ShowMessageBox(
    "Could not find drumbanger_service.lua\nExpected at: " .. service_path,
    "LMS Setup", 0)
  return
end
f:close()

-- Register the service as a REAPER action
local cmd_id = reaper.AddRemoveReaScript(true, 0, service_path, true)
if cmd_id == 0 then
  reaper.ShowMessageBox(
    "Failed to register service script.\nPath: " .. service_path,
    "LMS Setup", 0)
  return
end

-- Get the named command string (e.g. "_RSabcdef1234...")
local cmd_string = reaper.ReverseNamedCommandLookup(cmd_id)

-- Start the service right now
reaper.Main_OnCommand(cmd_id, 0)

-- Save the service path so __startup.lua can dofile() it directly
reaper.SetExtState("LMS", "service_path", service_path, true)

-- Install __startup.lua for auto-start on REAPER launch
-- REAPER natively runs Scripts/__startup.lua on every launch (no SWS needed)
local scripts_dir = reaper.GetResourcePath() .. "/Scripts"
local startup_path = scripts_dir .. "/__startup.lua"

local LMS_START = "-- [LMS AUTO-START BEGIN]"
local LMS_END   = "-- [LMS AUTO-START END]"

local lms_block = LMS_START .. "\n" ..
  "reaper.defer(function()\n" ..
  "  local base = reaper.GetResourcePath() .. \"/Scripts\"\n" ..
  "\n" ..
  "  -- DrumBanger service (sampling + MIDI print)\n" ..
  "  local svc = base .. \"/LMS/drumbanger_service.lua\"\n" ..
  "  local f = io.open(svc, \"r\")\n" ..
  "  if f then\n" ..
  "    f:close()\n" ..
  "    reaper.ShowConsoleMsg(\"LMS: Auto-starting DrumBanger service...\\n\")\n" ..
  "    dofile(svc)\n" ..
  "  else\n" ..
  "    reaper.ShowConsoleMsg(\"LMS: Service script not found — run LMS Setup again.\\n\")\n" ..
  "  end\n" ..
  "\n" ..
  "  -- LMS Plugin Manager\n" ..
  "  local mgr = base .. \"/LMS/lms_manager.lua\"\n" ..
  "  f = io.open(mgr, \"r\")\n" ..
  "  if f then\n" ..
  "    f:close()\n" ..
  "    reaper.ShowConsoleMsg(\"LMS: Plugin Manager started\\n\")\n" ..
  "    dofile(mgr)\n" ..
  "  end\n" ..
  "end)\n" ..
  LMS_END .. "\n"

-- Read existing __startup.lua (preserve other scripts' blocks)
local existing = ""
local sf = io.open(startup_path, "r")
if sf then
  existing = sf:read("*a")
  sf:close()
end

-- Remove any previous LMS block (idempotent re-runs)
local bs = existing:find(LMS_START, 1, true)
local be = existing:find(LMS_END, 1, true)
if bs and be then
  local tail = be + #LMS_END
  if existing:sub(tail, tail) == "\n" then tail = tail + 1 end
  existing = existing:sub(1, bs - 1) .. existing:sub(tail)
end

-- Append our block
sf = io.open(startup_path, "w")
if sf then
  sf:write(existing .. lms_block)
  sf:close()
end

reaper.ShowMessageBox(
  "LMS Suite setup complete!\n\n" ..
  "Plugin Manager + DrumBanger service are now running.\n\n" ..
  "Auto-start installed — both will launch\n" ..
  "automatically every time you open REAPER.",
  "LMS Setup", 0)
