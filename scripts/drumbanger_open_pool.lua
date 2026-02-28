-- DRUMBANGER: Open Pool Folder
-- -----------------------------
-- Opens the pool folder in your system file manager.
-- Drop .wav files or folders of .wav files in there, then run Rescan.
--
-- Subfolders in pool/ become kits. First 16 .wav files per folder = pads 1-16.
-- Kit folder names = kit names in DrumBanger's GUI.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

-- Find pool/ by locating the JSFX (works regardless of ReaPack index name)
local function find_pool()
  local fx = reaper.GetResourcePath() .. "/Effects"
  local function search(dir, depth)
    if depth > 4 then return nil end
    local i = 0
    while true do
      local f = reaper.EnumerateFiles(dir, i)
      if not f then break end
      if f == "lms_drumbanger.jsfx" then return dir .. "/pool" end
      i = i + 1
    end
    local j = 0
    while true do
      local d = reaper.EnumerateSubdirectories(dir, j)
      if not d then break end
      local r = search(dir .. "/" .. d, depth + 1)
      if r then return r end
      j = j + 1
    end
  end
  return search(fx, 0) or (fx .. "/DRUMBANGER/pool")
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
