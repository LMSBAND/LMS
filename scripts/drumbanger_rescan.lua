-- DRUMBANGER: Rescan Pool
-- -----------------------
-- Scans the pool folder (including subfolders) and rebuilds pool/manifest.txt.
-- Subfolders in pool/ become kits — drop a folder of .wav files to add a kit.
-- Run this after adding .wav files or folders to pool/.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for quick rescanning.

local GMEM_NAME = "DrumBanger"

-- The pool DRUMBANGER actually reads. It loads samples with
-- file_open("pool/..."), and JSFX resolves a relative path against
-- <resource>/Data -- never against the folder the .jsfx sits in. ReaPack
-- agrees: the samples ship as type="data" sources, which install to Data/.
-- A pool sitting next to the effect is invisible to the plugin no matter how
-- correct it looks, which is exactly what these scripts used to build.
local function find_pool()
  return reaper.GetResourcePath() .. "/Data/pool"
end

local function scan_dir(base_dir, rel_prefix, results)
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
  local pool_dir = find_pool()
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

  local folders = {}
  for _, entry in ipairs(results) do
    local folder = entry:match("^(.+)/")
    if folder and not folders[folder] then
      folders[folder] = true
    end
  end
  local kit_count = 0
  for _ in pairs(folders) do kit_count = kit_count + 1 end

  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(0, 1)

  reaper.ShowConsoleMsg(
    string.format("DRUMBANGER: Pool rescanned — %d samples, %d kits (folders)\n",
      #results, kit_count))
  reaper.ShowConsoleMsg("  Pool folder: " .. pool_dir .. "\n")

  if #results == 0 then
    reaper.ShowConsoleMsg(
      "  Drop .wav files there for loose samples.\n"..
      "  Drop a FOLDER of .wav files to create a kit.\n"..
      "  Then run this action again.\n")
  end
end

main()
