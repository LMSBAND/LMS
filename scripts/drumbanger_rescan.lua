-- DRUMBANGER: Rescan Pool + Kits
-- --------------------------------
-- Scans the pool folder (including subfolders) and rebuilds pool/manifest.txt.
-- Also scans the kits folder and rebuilds kits/manifest.txt.
-- Run this after adding .wav files to pool or dropping kit folders into kits/.
--
-- Pool folder: <REAPER resource>/Effects/DrumBox16/pool/
-- Kit folder:  <REAPER resource>/Effects/DrumBox16/kits/
--   Drop ANY folder of .wav files into kits/ — no renaming needed!
--   First 16 .wav files (alphabetical) map to pads 1-16.
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

local function scan_kits(kits_dir)
  local kit_count = 0
  local manifest_lines = {}

  -- Enumerate subdirectories in kits/
  local dirs = {}
  local d = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(kits_dir, d)
    if not dirname then break end
    dirs[#dirs + 1] = dirname
    d = d + 1
  end
  table.sort(dirs)

  for _, dirname in ipairs(dirs) do
    if kit_count >= 8 then break end
    local kit_path = kits_dir .. "/" .. dirname

    -- Find wav files in this kit folder (non-recursive, first 16)
    local wavs = {}
    local i = 0
    while true do
      local fname = reaper.EnumerateFiles(kit_path, i)
      if not fname then break end
      if fname:lower():match("%.wav$") then
        wavs[#wavs + 1] = fname
      end
      i = i + 1
    end

    if #wavs > 0 then
      table.sort(wavs)
      manifest_lines[#manifest_lines + 1] = "---"
      manifest_lines[#manifest_lines + 1] = dirname
      for j = 1, math.min(16, #wavs) do
        manifest_lines[#manifest_lines + 1] = dirname .. "/" .. wavs[j]
      end
      kit_count = kit_count + 1
    end
  end

  local f = io.open(kits_dir .. "/manifest.txt", "w")
  if f then
    for _, line in ipairs(manifest_lines) do
      f:write(line .. "\n")
    end
    f:close()
  end

  return kit_count
end

local function main()
  local resource_path = reaper.GetResourcePath()
  local pool_dir = resource_path .. "/Effects/DrumBox16/pool"
  local kits_dir = resource_path .. "/Effects/DrumBox16/kits"
  reaper.RecursiveCreateDirectory(pool_dir, 0)
  reaper.RecursiveCreateDirectory(kits_dir, 0)

  -- Pool scan
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

  -- Kit scan
  local kit_count = scan_kits(kits_dir)

  -- Signal JSFX to reload pool + kits
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(0, 1)  -- pool rescan signal
  reaper.gmem_write(7, 1)  -- kit rescan signal

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Pool rescanned — %d samples found\n", #results))
  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Kits rescanned — %d kits found\n", kit_count))

  if #results == 0 then
    reaper.ShowConsoleMsg(
      "  Pool folder: " .. pool_dir .. "\n"..
      "  Drop .wav files there (use subfolders to organize).\n"..
      "  Then run this action again.\n")
  end
  if kit_count == 0 then
    reaper.ShowConsoleMsg(
      "  Kits folder: " .. kits_dir .. "\n"..
      "  Drop a folder of .wav files there — any name, any filenames!\n"..
      "  Then run this action again.\n")
  end
end

main()
