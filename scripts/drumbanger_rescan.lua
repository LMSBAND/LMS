-- DRUMBANGER: Rescan Pool
-- -----------------------
-- Scans the pool folder (including subfolders) and rebuilds pool/manifest.txt.
-- Subfolders in pool/ become kits — drop a folder of .wav files to add a kit.
-- Run this after adding .wav files or folders to pool/.
--
-- Pool folder: Effects/DRUMBANGER/pool/
--   Drop .wav files at root for loose samples.
--   Drop a FOLDER of .wav files to create a kit.
--   First 16 .wav files (alphabetical) per folder map to pads 1-16.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for quick rescanning.

local GMEM_NAME = "DrumBanger"
local POOL_DIR = reaper.GetResourcePath() .. "/Effects/DRUMBANGER/pool"

local function scan_dir(base_dir, rel_prefix, results)
  -- Scan .wav files in this directory
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(base_dir, i)
    if not fname then break end
    if fname:lower():match("%.wav$") then
      if rel_prefix == "" then
        results[#results + 1] = fname
      else
        results[#results + 1] = rel_prefix .. "/" .. fname
      end
    end
    i = i + 1
  end

  -- Recurse into subdirectories
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(base_dir, j)
    if not dirname then break end
    local new_prefix = rel_prefix == "" and dirname or (rel_prefix .. "/" .. dirname)
    scan_dir(base_dir .. "/" .. dirname, new_prefix, results)
    j = j + 1
  end
end

local function main()
  reaper.RecursiveCreateDirectory(POOL_DIR, 0)

  -- Pool scan (includes subfolders = kits)
  local results = {}
  scan_dir(POOL_DIR, "", results)
  table.sort(results)

  local f = io.open(POOL_DIR .. "/manifest.txt", "w")
  if f then
    for _, entry in ipairs(results) do
      f:write(entry .. "\n")
    end
    f:close()
  end

  -- Count folders (= kits)
  local folders = {}
  for _, entry in ipairs(results) do
    local folder = entry:match("^(.+)/")
    if folder and not folders[folder] then
      folders[folder] = true
    end
  end
  local kit_count = 0
  for _ in pairs(folders) do kit_count = kit_count + 1 end

  -- Signal JSFX to reload
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(0, 1)  -- pool rescan signal (also rebuilds kit list)

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Pool rescanned — %d samples, %d kits (folders)\n",
      #results, kit_count))
  reaper.ShowConsoleMsg("  Pool folder: " .. POOL_DIR .. "\n")

  if #results == 0 then
    reaper.ShowConsoleMsg(
      "  Drop .wav files there for loose samples.\n"..
      "  Drop a FOLDER of .wav files to create a kit.\n"..
      "  Then run this action again.\n")
  end
end

main()
