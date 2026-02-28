-- DRUMBANGER: Open Pool Folder
-- -----------------------------
-- Opens the pool folder in your system file manager.
-- Drop .wav files or folders of .wav files in there, then run Rescan.
--
-- Subfolders in pool/ become kits. First 16 .wav files per folder = pads 1-16.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

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
          -- Verify it exists (or can be created)
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

local function main()
  local pool_dir = find_pool_dir()

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
