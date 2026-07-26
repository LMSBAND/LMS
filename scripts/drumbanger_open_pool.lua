-- DRUMBANGER: Open Pool Folder
-- -----------------------------
-- Opens the pool folder in your system file manager.
-- Drop .wav files or folders of .wav files in there, then run Rescan.
--
-- Subfolders in pool/ become kits. First 16 .wav files per folder = pads 1-16.
-- Kit folder names = kit names in DrumBanger's GUI.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

-- The pool DRUMBANGER actually reads. It loads samples with
-- file_open("pool/..."), and JSFX resolves a relative path against
-- <resource>/Data -- never against the folder the .jsfx sits in. ReaPack
-- agrees: the samples ship as type="data" sources, which install to Data/.
-- A pool sitting next to the effect is invisible to the plugin no matter how
-- correct it looks, which is exactly what these scripts used to build.
local function find_pool()
  return reaper.GetResourcePath() .. "/Data/pool"
end

local function main()
  local pool_dir = find_pool()
  reaper.RecursiveCreateDirectory(pool_dir, 0)

  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    os.execute('explorer "' .. pool_dir:gsub("/", "\\") .. '"')
  elseif os_name:match("OSX") or os_name:match("macOS") then
    os.execute('open "' .. pool_dir .. '"')
  else
    os.execute('xdg-open "' .. pool_dir .. '" &')
  end

  reaper.ShowConsoleMsg("DRUMBANGER: Opened pool folder:\n  " .. pool_dir .. "\n")
end

main()
