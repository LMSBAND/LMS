-- DRUMBANGER: Diagnose Pool
-- --------------------------
-- Searches the ENTIRE Effects tree to find where lms_drumbanger.jsfx
-- actually lives and where the stock kits are. Changes NOTHING.
-- Run this and paste the console output.

local function find_file(dir, target, depth, results)
  if depth > 6 then return end
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(dir, i)
    if not fname then break end
    if fname == target then
      results[#results + 1] = dir .. "/" .. fname
    end
    i = i + 1
  end
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(dir, j)
    if not dirname then break end
    find_file(dir .. "/" .. dirname, target, depth + 1, results)
    j = j + 1
  end
end

local function find_dir(dir, target, depth, results)
  if depth > 6 then return end
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(dir, j)
    if not dirname then break end
    if dirname == target then
      results[#results + 1] = dir .. "/" .. dirname
    end
    find_dir(dir .. "/" .. dirname, target, depth + 1, results)
    j = j + 1
  end
end

local function list_dir(dir, prefix)
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(dir, i)
    if not fname then break end
    reaper.ShowConsoleMsg("  " .. prefix .. fname .. "\n")
    i = i + 1
  end
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(dir, j)
    if not dirname then break end
    reaper.ShowConsoleMsg("  " .. prefix .. dirname .. "/\n")
    j = j + 1
  end
end

local function main()
  local rp = reaper.GetResourcePath()
  local fx = rp .. "/Effects"

  reaper.ShowConsoleMsg("\n============ DRUMBANGER DIAGNOSIS v2 ============\n")
  reaper.ShowConsoleMsg("Resource path: " .. rp .. "\n")
  reaper.ShowConsoleMsg("OS: " .. reaper.GetOS() .. "\n\n")

  -- 1. Find EVERY copy of lms_drumbanger.jsfx
  reaper.ShowConsoleMsg("--- SEARCH: lms_drumbanger.jsfx ---\n")
  local jsfx_locations = {}
  find_file(fx, "lms_drumbanger.jsfx", 0, jsfx_locations)
  if #jsfx_locations == 0 then
    reaper.ShowConsoleMsg("  NOT FOUND anywhere under Effects/!\n")
  else
    for _, path in ipairs(jsfx_locations) do
      reaper.ShowConsoleMsg("  FOUND: " .. path .. "\n")
    end
  end

  -- 2. Find EVERY Kit1-808 directory
  reaper.ShowConsoleMsg("\n--- SEARCH: Kit1-808 directory ---\n")
  local kit_locations = {}
  find_dir(fx, "Kit1-808", 0, kit_locations)
  if #kit_locations == 0 then
    reaper.ShowConsoleMsg("  NOT FOUND anywhere under Effects/!\n")
  else
    for _, path in ipairs(kit_locations) do
      reaper.ShowConsoleMsg("  FOUND: " .. path .. "\n")
    end
  end

  -- 3. Find EVERY pool directory
  reaper.ShowConsoleMsg("\n--- SEARCH: pool directories ---\n")
  local pool_locations = {}
  find_dir(fx, "pool", 0, pool_locations)
  if #pool_locations == 0 then
    reaper.ShowConsoleMsg("  NOT FOUND anywhere under Effects/!\n")
  else
    for _, path in ipairs(pool_locations) do
      reaper.ShowConsoleMsg("  FOUND: " .. path .. "\n")
      list_dir(path, "    ")
    end
  end

  -- 4. Show what's directly in Effects/DRUMBANGER/
  reaper.ShowConsoleMsg("\n--- Effects/DRUMBANGER/ contents ---\n")
  local db = fx .. "/DRUMBANGER"
  list_dir(db, "  ")

  -- 5. Show what's directly in Effects/ root (first 30 files)
  reaper.ShowConsoleMsg("\n--- Effects/ root (files only) ---\n")
  local i = 0
  while i < 50 do
    local fname = reaper.EnumerateFiles(fx, i)
    if not fname then break end
    if fname:match("drumbanger") or fname:match("lms_") or fname:match("%.jsfx") then
      reaper.ShowConsoleMsg("  " .. fname .. "\n")
    end
    i = i + 1
  end
  -- Also check subdirs
  reaper.ShowConsoleMsg("\n--- Effects/ subdirectories ---\n")
  local j = 0
  while true do
    local dirname = reaper.EnumerateSubdirectories(fx, j)
    if not dirname then break end
    reaper.ShowConsoleMsg("  " .. dirname .. "/\n")
    j = j + 1
  end

  reaper.ShowConsoleMsg("\n============ END DIAGNOSIS v2 ============\n")
end

main()
