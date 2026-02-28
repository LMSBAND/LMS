-- DRUMBANGER: Open Pool Folder
-- -----------------------------
-- Opens the pool folder in your system file manager.
-- Drop .wav files or folders of .wav files in there, then run Rescan.
--
-- Subfolders in pool/ become kits. First 16 .wav files per folder = pads 1-16.
-- Kit folder names = kit names in DrumBanger's GUI.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

local POOL_DIR = reaper.GetResourcePath() .. "/Effects/DRUMBANGER/pool"

local function main()
  -- Make sure it exists
  reaper.RecursiveCreateDirectory(POOL_DIR, 0)

  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    os.execute('explorer "' .. POOL_DIR:gsub("/", "\\") .. '"')
  elseif os_name:match("OSX") or os_name:match("macOS") then
    os.execute('open "' .. POOL_DIR .. '"')
  else
    os.execute('xdg-open "' .. POOL_DIR .. '" &')
  end

  reaper.ShowConsoleMsg("DRUMBANGER: Opened pool folder:\n  " .. POOL_DIR .. "\n")
end

main()
