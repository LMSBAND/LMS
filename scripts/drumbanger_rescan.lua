-- DRUMBANGER: Rescan Pool
-- --------------------------------
-- Scans the pool folder (including subfolders) and rebuilds manifest.txt.
-- Run this after adding or removing .wav files from the pool.
--
-- Pool folder: <REAPER resource>/Effects/DrumBox16/pool/
-- Organize samples into subfolders for categorized browsing:
--   pool/kicks/    pool/snares/    pool/loops/    etc.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for quick rescanning.

local GMEM_NAME = "DrumBanger"

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
  local resource_path = reaper.GetResourcePath()
  local pool_dir = resource_path .. "/Effects/DrumBox16/pool"
  reaper.RecursiveCreateDirectory(pool_dir, 0)

  local results = {}
  scan_dir(pool_dir, "", results)
  table.sort(results)

  local f = io.open(pool_dir .. "/manifest.txt", "w")
  if f then
    for _, entry in ipairs(results) do
      f:write(entry .. "\n")
    end
    f:close()
  end

  -- Signal JSFX to reload manifest
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(0, 1)

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Pool rescanned — %d samples found\n", #results))

  if #results == 0 then
    reaper.ShowConsoleMsg(
      "  Pool folder: " .. pool_dir .. "\n"..
      "  Drop .wav files there (use subfolders to organize).\n"..
      "  Then run this action again.\n")
  end
end

main()
