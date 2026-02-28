-- DRUMBANGER: Rescan Pool
-- -----------------------
-- Scans the pool folder (including subfolders) and rebuilds pool/manifest.txt.
-- Subfolders in pool/ become kits — drop a folder of .wav files to add a kit.
-- Run this after adding .wav files or folders to pool/.
--
-- Pool folder lives next to lms_drumbanger.jsfx (follows symlinks).
--   Drop .wav files at root for loose samples.
--   Drop a FOLDER of .wav files to create a kit.
--   First 16 .wav files (alphabetical) per folder map to pads 1-16.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for quick rescanning.

local GMEM_NAME = "DrumBanger"

-- Find the pool directory that the JSFX actually reads from.
-- REAPER resolves JSFX relative paths from the real file location,
-- so we must follow symlinks to find where pool/ truly lives.
local function find_pool_dir()
  local resource_path = reaper.GetResourcePath()
  local drumbanger_dir = resource_path .. "/Effects/DRUMBANGER"
  local jsfx_path = drumbanger_dir .. "/lms_drumbanger.jsfx"

  -- Try to resolve symlink (Linux/Mac)
  local os_name = reaper.GetOS()
  if not os_name:match("Win") then
    local handle = io.popen('readlink -f "' .. jsfx_path .. '" 2>/dev/null')
    if handle then
      local resolved = handle:read("*l")
      handle:close()
      if resolved and resolved ~= "" then
        local real_dir = resolved:match("(.+)/[^/]+$")
        if real_dir and real_dir ~= drumbanger_dir then
          local pool = real_dir .. "/pool"
          reaper.RecursiveCreateDirectory(pool, 0)
          return pool
        end
      end
    end
  end

  -- Fallback: pool/ in the DRUMBANGER Effects directory
  local pool = drumbanger_dir .. "/pool"
  reaper.RecursiveCreateDirectory(pool, 0)
  return pool
end

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
  local pool_dir = find_pool_dir()

  -- Pool scan (includes subfolders = kits)
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
  reaper.ShowConsoleMsg("  Pool folder: " .. pool_dir .. "\n")

  if #results == 0 then
    reaper.ShowConsoleMsg(
      "  Drop .wav files there for loose samples.\n"..
      "  Drop a FOLDER of .wav files to create a kit.\n"..
      "  Then run this action again.\n")
  end
end

main()
