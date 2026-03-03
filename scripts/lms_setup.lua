-- LMS Suite Setup
-- Run this ONCE. It registers the DrumBanger service as an action,
-- starts it, and adds it to REAPER's startup actions so it auto-runs
-- every time you open REAPER.

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

-- Add to REAPER startup actions
-- REAPER stores these in reaper-kb.ini as SCR lines.
-- Flag 4 = Lua, flag 256 = run on startup. We need flags = 260.
local kb_path = reaper.GetResourcePath() .. "/reaper-kb.ini"
local kb = io.open(kb_path, "r")
if kb then
  local content = kb:read("*a")
  kb:close()

  -- Find our SCR line (AddRemoveReaScript wrote it with flags=4)
  -- and change flags to 260 (4 + 256 = Lua + startup)
  local search = "SCR 4 0 " .. cmd_string
  local replace = "SCR 260 0 " .. cmd_string

  if content:find(search, 1, true) then
    content = content:gsub(search, replace, 1)
    kb = io.open(kb_path, "w")
    if kb then
      kb:write(content)
      kb:close()
    end
  end
end

-- Save the command ID so other scripts can find it
reaper.SetExtState("LMS", "service_cmd", cmd_string or "", true)

reaper.ShowMessageBox(
  "LMS Suite setup complete!\n\n" ..
  "DrumBanger service is now running.\n" ..
  "Handles: SAMPLE button + MIDI PRINT button.\n\n" ..
  "Auto-start on REAPER launch: restart REAPER once\n" ..
  "to activate. After that it runs automatically.",
  "LMS Setup", 0)
