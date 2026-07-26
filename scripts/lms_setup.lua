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

-- Find scripts. ReaPack installs each package into its own category folder, so
-- lms_setup.lua (DRUMBANGER/Scripts) and lms_manager.lua (LMS/Scripts) do NOT
-- end up side by side. Search every known layout instead of assuming siblings.
local info = debug.getinfo(1, "S")
local script_dir = info.source:match("@?(.+)[/\\]")
local scripts_root = reaper.GetResourcePath() .. "/Scripts"

local function find_script(name)
  local candidates = {
    script_dir .. "/" .. name,                              -- manual / zip install
    scripts_root .. "/LMS Plugins/LMS/Scripts/" .. name,    -- ReaPack, LMS category
    scripts_root .. "/LMS Plugins/DRUMBANGER/Scripts/" .. name, -- ReaPack, DRUMBANGER
    scripts_root .. "/LMS/" .. name,
    scripts_root .. "/" .. name,
  }
  for _, path in ipairs(candidates) do
    local f = io.open(path, "r")
    if f then
      f:close()
      return path
    end
  end
  return nil, candidates
end

local service_path, service_tried = find_script("drumbanger_service.lua")
if not service_path then
  reaper.ShowMessageBox(
    "Could not find drumbanger_service.lua\n\nLooked in:\n  " ..
    table.concat(service_tried, "\n  "),
    "LMS Setup", 0)
  return
end

local manager_path, manager_tried = find_script("lms_manager.lua")
if not manager_path then
  reaper.ShowMessageBox(
    "Could not find lms_manager.lua\n\nLooked in:\n  " ..
    table.concat(manager_tried, "\n  "),
    "LMS Setup", 0)
  return
end

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

-- Install __startup.lua for auto-start on REAPER launch
-- REAPER natively runs Scripts/__startup.lua on every launch (no SWS needed)
local startup_path = scripts_root .. "/__startup.lua"

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
  "Plugin Manager + DrumBanger service are starting now.\n\n" ..
  "Auto-start installed — both will launch\n" ..
  "automatically every time you open REAPER.",
  "LMS Setup", 0)

-- Start both LAST, after every modal dialog is out of the way.
-- ShowMessageBox is modal and blocks the defer loop while it is open. The
-- manager creates its ImGui context at load, and ReaImGui garbage-collects
-- contexts that go unused, so launching before the dialog let the context be
-- destroyed while the user read it -- the first deferred frame then failed with
-- "ImGui_PushFont: expected a valid ImGui_Context*". Nothing may block between
-- the manager loading and its first rendered frame.
dofile(service_path)
dofile(manager_path)
