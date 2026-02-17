-- DRUMBANGER: Load Sample
-- -----------------------
-- Opens a file picker. Copies the selected wav into the pool.
-- Auto-loads it onto the selected pad in DRUMBANGER.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript
-- Assign a keyboard shortcut for instant loading.

local GMEM_NAME = "DrumBanger"

local function get_pool_dir()
  return reaper.GetResourcePath() .. "/Effects/DRUMBANGER/pool"
end

local function update_manifest(pool_dir)
  local wav_files = {}
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(pool_dir, i)
    if not fname then break end
    if fname:lower():match("%.wav$") then
      wav_files[#wav_files + 1] = fname
    end
    i = i + 1
  end

  -- Also scan one level of subdirectories
  local d = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(pool_dir, d)
    if not dirname then break end
    local subpath = pool_dir .. "/" .. dirname
    local j = 0
    while true do
      local fname = reaper.EnumerateFiles(subpath, j)
      if not fname then break end
      if fname:lower():match("%.wav$") then
        wav_files[#wav_files + 1] = dirname .. "/" .. fname
      end
      j = j + 1
    end
    d = d + 1
  end

  table.sort(wav_files)

  local f = io.open(pool_dir .. "/manifest.txt", "w")
  if f then
    for _, wav in ipairs(wav_files) do
      f:write(wav .. "\n")
    end
    f:close()
  end
  return wav_files
end

local function copy_file(src, dst)
  local fin = io.open(src, "rb")
  if not fin then return false end
  local data = fin:read("*a")
  fin:close()
  local fout = io.open(dst, "wb")
  if not fout then return false end
  fout:write(data)
  fout:close()
  return true
end

local function main()
  -- Open file picker
  local retval, filename = reaper.GetUserFileNameForRead("", "Load sample into DRUMBANGER", "*.wav;*.WAV")
  if not retval or filename == "" then return end

  -- Verify it's a wav
  if not filename:lower():match("%.wav$") then
    reaper.ShowMessageBox("Please select a .wav file.", "DRUMBANGER", 0)
    return
  end

  local pool_dir = get_pool_dir()
  reaper.RecursiveCreateDirectory(pool_dir, 0)

  -- Extract just the filename from the full path
  local basename = filename:match("([^/\\]+)$")

  -- If it already exists in pool, just use it directly
  local dest = pool_dir .. "/" .. basename
  if filename ~= dest then
    if not copy_file(filename, dest) then
      reaper.ShowMessageBox("Failed to copy file to pool.", "DRUMBANGER", 0)
      return
    end
  end

  -- Rebuild manifest
  local wav_list = update_manifest(pool_dir)

  -- Find the new sample's index
  local new_idx = -1
  for i, name in ipairs(wav_list) do
    if name == basename then
      new_idx = i - 1
      break
    end
  end

  if new_idx < 0 then
    reaper.ShowMessageBox("Sample not found in manifest after copy.", "DRUMBANGER", 0)
    return
  end

  -- Signal DRUMBANGER via gmem
  reaper.gmem_attach(GMEM_NAME)
  reaper.gmem_write(1, new_idx)
  reaper.gmem_write(2, 1)         -- auto-load onto selected pad
  reaper.gmem_write(0, 1)         -- rescan signal

  reaper.ShowConsoleMsg("DRUMBANGER: Loaded '" .. basename .. "' onto selected pad\n")
end

main()
