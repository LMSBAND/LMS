-- LMS Suite Setup
-- Run this ONCE. It registers services, starts the Plugin Manager,
-- and installs __startup.lua so everything auto-runs on REAPER launch.

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

-- Find scripts (same directory as this setup script)
local info = debug.getinfo(1, "S")
local script_dir = info.source:match("@?(.+)[/\\]")

local service_path = script_dir .. "/drumbanger_service.lua"
local manager_path = script_dir .. "/lms_manager.lua"

-- Verify both scripts exist
local f = io.open(service_path, "r")
if not f then
  reaper.ShowMessageBox(
    "Could not find drumbanger_service.lua\nExpected at: " .. service_path,
    "LMS Setup", 0)
  return
end
f:close()

f = io.open(manager_path, "r")
if not f then
  reaper.ShowMessageBox(
    "Could not find lms_manager.lua\nExpected at: " .. manager_path,
    "LMS Setup", 0)
  return
end
f:close()

-- Save verified paths so __startup.lua can find them on restart
reaper.SetExtState("LMS", "service_path", service_path, true)
reaper.SetExtState("LMS", "manager_path", manager_path, true)

-- Clean up stale AddRemoveReaScript registration from older setup versions
-- (REAPER saves the absolute path and shows an error dialog on restart if it moves)
local old_svc = reaper.GetExtState("LMS", "registered_cmd")
if old_svc ~= "" then
  local old_id = reaper.NamedCommandLookup(old_svc)
  if old_id ~= 0 then
    reaper.AddRemoveReaScript(false, 0, service_path, true)
  end
  reaper.DeleteExtState("LMS", "registered_cmd", true)
end

-- Start both right now (ReaPack already registers them as actions via main="main")
dofile(service_path)
dofile(manager_path)

-- Install __startup.lua for auto-start on REAPER launch
-- REAPER natively runs Scripts/__startup.lua on every launch (no SWS needed)
local scripts_dir = reaper.GetResourcePath() .. "/Scripts"
local startup_path = scripts_dir .. "/__startup.lua"

local LMS_START = "-- [LMS AUTO-START BEGIN]"
local LMS_END   = "-- [LMS AUTO-START END]"

local lms_block = LMS_START .. "\n" ..
  "reaper.defer(function()\n" ..
  "  -- Read verified paths saved by LMS Setup\n" ..
  "  local svc = reaper.GetExtState(\"LMS\", \"service_path\")\n" ..
  "  local mgr = reaper.GetExtState(\"LMS\", \"manager_path\")\n" ..
  "\n" ..
  "  -- DrumBanger service\n" ..
  "  if svc ~= \"\" then\n" ..
  "    local f = io.open(svc, \"r\")\n" ..
  "    if f then\n" ..
  "      f:close()\n" ..
  "      reaper.ShowConsoleMsg(\"LMS: Auto-starting DrumBanger service...\\n\")\n" ..
  "      dofile(svc)\n" ..
  "    else\n" ..
  "      reaper.ShowConsoleMsg(\"LMS: Service script not found at: \" .. svc .. \" — run LMS Setup again.\\n\")\n" ..
  "    end\n" ..
  "  end\n" ..
  "\n" ..
  "  -- LMS Plugin Manager\n" ..
  "  if mgr ~= \"\" then\n" ..
  "    local f = io.open(mgr, \"r\")\n" ..
  "    if f then\n" ..
  "      f:close()\n" ..
  "      reaper.ShowConsoleMsg(\"LMS: Plugin Manager started\\n\")\n" ..
  "      dofile(mgr)\n" ..
  "    else\n" ..
  "      reaper.ShowConsoleMsg(\"LMS: Manager not found at: \" .. mgr .. \" — run LMS Setup again.\\n\")\n" ..
  "    end\n" ..
  "  else\n" ..
  "    reaper.ShowConsoleMsg(\"LMS: No manager path saved — run LMS Setup again.\\n\")\n" ..
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

-- Write __startup.lua
sf = io.open(startup_path, "w")
if not sf then
  reaper.ShowMessageBox(
    "Could not write __startup.lua!\n\n" ..
    "Expected at: " .. startup_path .. "\n\n" ..
    "Check folder permissions for your REAPER Scripts directory.",
    "LMS Setup — Write Failed", 0)
  return
end
sf:write(existing .. lms_block)
sf:close()

reaper.ShowMessageBox(
  "LMS Suite setup complete!\n\n" ..
  "Plugin Manager + DrumBanger service are now running.\n\n" ..
  "Auto-start installed — both will launch\n" ..
  "automatically every time you open REAPER.",
  "LMS Setup", 0)
