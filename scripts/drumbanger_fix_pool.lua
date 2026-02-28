-- DRUMBANGER: Fix Pool Directory
-- --------------------------------
-- Nukes the pool directory and rebuilds it clean.
-- Finds ALL .wav files anywhere under the DRUMBANGER folder
-- (including nested pool/pool/, legacy kits/, wrong paths)
-- and puts them in the one correct place: Effects/DRUMBANGER/pool/
--
-- Safe to run any time. If your kits aren't showing up, run this.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

local GMEM_NAME = "DrumBanger"

local function copy_file(src, dst)
  local fin = io.open(src, "rb")
  if not fin then return false, 0 end
  local data = fin:read("*a")
  fin:close()
  local fout = io.open(dst, "wb")
  if not fout then return false, 0 end
  fout:write(data)
  fout:close()
  return true, #data
end

-- Recursively find all .wav files under a directory
local function find_wavs(dir, depth, results)
  if depth > 10 then return end
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(dir, i)
    if not fname then break end
    if fname:lower():match("%.wav$") then
      results[#results + 1] = {
        full_path = dir .. "/" .. fname,
        parent = dir:match("([^/\\]+)$") or "",
        filename = fname,
      }
    end
    i = i + 1
  end
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(dir, j)
    if not dirname then break end
    -- Skip scripts/ directory
    if dirname ~= "scripts" then
      find_wavs(dir .. "/" .. dirname, depth + 1, results)
    end
    j = j + 1
  end
end

local function main()
  local resource_path = reaper.GetResourcePath()
  local db_dir = resource_path .. "/Effects/DRUMBANGER"
  local pool_dir = db_dir .. "/pool"

  reaper.ShowConsoleMsg("\n====================================\n")
  reaper.ShowConsoleMsg("DRUMBANGER FIX: Rebuilding pool...\n")
  reaper.ShowConsoleMsg("====================================\n")
  reaper.ShowConsoleMsg("  DRUMBANGER: " .. db_dir .. "\n")
  reaper.ShowConsoleMsg("  Pool target: " .. pool_dir .. "\n\n")

  -- Step 1: Find every .wav file under DRUMBANGER/
  local wavs = {}
  find_wavs(db_dir, 0, wavs)

  reaper.ShowConsoleMsg("STEP 1: Found " .. #wavs .. " wav files total\n")

  if #wavs == 0 then
    reaper.ShowConsoleMsg("  No wav files found anywhere under DRUMBANGER/!\n")
    reaper.ShowConsoleMsg("  Reinstall DRUMBANGER via ReaPack to get the stock kits.\n")
    return
  end

  -- Show where they currently are
  for _, w in ipairs(wavs) do
    reaper.ShowConsoleMsg("  " .. w.full_path .. "\n")
  end

  -- Step 2: Determine correct pool path for each wav
  -- Parent folder = kit name, UNLESS parent is "DRUMBANGER" or "pool"
  local kit_wavs = {}  -- {dest_rel_path, full_path}
  local skip_parents = {DRUMBANGER = true, pool = true}

  for _, w in ipairs(wavs) do
    if skip_parents[w.parent] then
      -- Loose file at root level — goes to pool/<filename>
      kit_wavs[#kit_wavs + 1] = {
        rel = w.filename,
        src = w.full_path,
      }
    else
      -- File in a subfolder — that folder is the kit name
      kit_wavs[#kit_wavs + 1] = {
        rel = w.parent .. "/" .. w.filename,
        src = w.full_path,
      }
    end
  end

  -- Deduplicate: if same rel path appears multiple times, keep first
  local seen = {}
  local unique = {}
  for _, kw in ipairs(kit_wavs) do
    if not seen[kw.rel] then
      seen[kw.rel] = true
      unique[#unique + 1] = kw
    end
  end
  kit_wavs = unique

  -- Step 3: Read all wav data into memory (before we delete anything)
  reaper.ShowConsoleMsg("\nSTEP 2: Reading " .. #kit_wavs .. " unique wav files into memory...\n")
  local wav_data = {}
  local total_bytes = 0
  for i, kw in ipairs(kit_wavs) do
    local fin = io.open(kw.src, "rb")
    if fin then
      wav_data[i] = fin:read("*a")
      fin:close()
      total_bytes = total_bytes + #wav_data[i]
    else
      reaper.ShowConsoleMsg("  WARNING: Could not read " .. kw.src .. "\n")
    end
  end
  reaper.ShowConsoleMsg(string.format("  Read %.1f MB into memory\n", total_bytes / 1048576))

  -- Step 4: Nuke pool/ and kits/ directories
  reaper.ShowConsoleMsg("\nSTEP 3: Nuking old directories...\n")
  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    os.execute('rmdir /s /q "' .. pool_dir:gsub("/", "\\") .. '" 2>nul')
    os.execute('rmdir /s /q "' .. (db_dir .. "\\kits") .. '" 2>nul')
  else
    os.execute('rm -rf "' .. pool_dir .. '"')
    os.execute('rm -rf "' .. db_dir .. '/kits"')
  end
  reaper.ShowConsoleMsg("  Deleted pool/ and kits/ (if they existed)\n")

  -- Step 5: Recreate pool/ and write everything back clean
  reaper.ShowConsoleMsg("\nSTEP 4: Writing clean pool structure...\n")
  reaper.RecursiveCreateDirectory(pool_dir, 0)

  local wrote_count = 0
  local kits_found = {}

  for i, kw in ipairs(kit_wavs) do
    if wav_data[i] then
      local dest = pool_dir .. "/" .. kw.rel

      -- Create kit subdirectory if needed
      local kit_name = kw.rel:match("^(.+)/")
      if kit_name then
        reaper.RecursiveCreateDirectory(pool_dir .. "/" .. kit_name, 0)
        kits_found[kit_name] = (kits_found[kit_name] or 0) + 1
      end

      local fout = io.open(dest, "wb")
      if fout then
        fout:write(wav_data[i])
        fout:close()
        wrote_count = wrote_count + 1
      else
        reaper.ShowConsoleMsg("  ERROR writing: " .. dest .. "\n")
      end
    end
  end

  -- Free memory
  wav_data = nil

  -- Step 6: Rebuild manifest.txt
  reaper.ShowConsoleMsg("\nSTEP 5: Rebuilding manifest...\n")
  local manifest = {}
  local function scan_pool(dir, prefix)
    local i = 0
    while true do
      local fname = reaper.EnumerateFiles(dir, i)
      if not fname then break end
      if fname:lower():match("%.wav$") then
        if prefix == "" then
          manifest[#manifest + 1] = fname
        else
          manifest[#manifest + 1] = prefix .. "/" .. fname
        end
      end
      i = i + 1
    end
    local j = 0
    while true do
      local dirname = reaper.EnumerateSubdirectories(dir, j)
      if not dirname then break end
      local new_prefix = prefix == "" and dirname or (prefix .. "/" .. dirname)
      scan_pool(dir .. "/" .. dirname, new_prefix)
      j = j + 1
    end
  end
  scan_pool(pool_dir, "")
  table.sort(manifest)

  local mf = io.open(pool_dir .. "/manifest.txt", "w")
  if mf then
    for _, entry in ipairs(manifest) do
      mf:write(entry .. "\n")
    end
    mf:close()
  end

  -- Step 7: Signal JSFX to reload
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(0, 1)

  -- Report
  reaper.ShowConsoleMsg("\n====================================\n")
  reaper.ShowConsoleMsg("DONE! Pool rebuilt clean.\n")
  reaper.ShowConsoleMsg("====================================\n")
  reaper.ShowConsoleMsg("  Pool: " .. pool_dir .. "\n")
  reaper.ShowConsoleMsg("  Samples: " .. wrote_count .. "\n")
  reaper.ShowConsoleMsg("  Manifest entries: " .. #manifest .. "\n")

  local kit_count = 0
  for kit_name, count in pairs(kits_found) do
    reaper.ShowConsoleMsg("  Kit: " .. kit_name .. " (" .. count .. " samples)\n")
    kit_count = kit_count + 1
  end

  if kit_count == 0 then
    reaper.ShowConsoleMsg("  No kits found (all loose samples)\n")
  end

  reaper.ShowConsoleMsg("\n  Open Pool should now show these kits.\n")
  reaper.ShowConsoleMsg("  DrumBanger should see them in the kit selector.\n")
  reaper.ShowConsoleMsg("  If not, close and reopen the DrumBanger FX window.\n")
end

main()
