-- DRUMBANGER: Diagnose Pool
-- --------------------------
-- Reports everything in the DRUMBANGER directory. Changes NOTHING.
-- Run this and paste the console output so we can see what's going on.

local function scan_tree(dir, prefix, depth)
  if depth > 6 then return end
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
    scan_tree(dir .. "/" .. dirname, prefix .. dirname .. "/", depth + 1)
    j = j + 1
  end
end

local function main()
  local rp = reaper.GetResourcePath()
  local db = rp .. "/Effects/DRUMBANGER"

  reaper.ShowConsoleMsg("\n========== DRUMBANGER DIAGNOSIS ==========\n")
  reaper.ShowConsoleMsg("Resource path: " .. rp .. "\n")
  reaper.ShowConsoleMsg("DRUMBANGER dir: " .. db .. "\n")
  reaper.ShowConsoleMsg("OS: " .. reaper.GetOS() .. "\n\n")

  reaper.ShowConsoleMsg("--- Everything under DRUMBANGER/ ---\n")
  scan_tree(db, "", 0)

  reaper.ShowConsoleMsg("\n--- Pool specifically ---\n")
  local pool = db .. "/pool"
  local pf = reaper.EnumerateFiles(pool, 0)
  if pf then
    reaper.ShowConsoleMsg("pool/ EXISTS, contents:\n")
    scan_tree(pool, "pool/", 0)
  else
    reaper.ShowConsoleMsg("pool/ EMPTY or MISSING\n")
  end

  -- Check for nested pool/pool
  local pp = pool .. "/pool"
  local ppf = reaper.EnumerateFiles(pp, 0)
  local ppd = reaper.EnumerateSubdirectories(pp, 0)
  if ppf or ppd then
    reaper.ShowConsoleMsg("\n*** PROBLEM: pool/pool/ EXISTS (nested!) ***\n")
    scan_tree(pp, "pool/pool/", 0)
  end

  -- Check for legacy kits/
  local kits = db .. "/kits"
  local kf = reaper.EnumerateSubdirectories(kits, 0)
  if kf then
    reaper.ShowConsoleMsg("\n*** PROBLEM: kits/ EXISTS (legacy!) ***\n")
    scan_tree(kits, "kits/", 0)
  end

  -- Check manifest
  local mf = io.open(pool .. "/manifest.txt", "r")
  if mf then
    local content = mf:read("*a")
    mf:close()
    local lines = 0
    for _ in content:gmatch("[^\n]+") do lines = lines + 1 end
    reaper.ShowConsoleMsg("\nmanifest.txt: " .. lines .. " entries\n")
    if lines > 0 then
      reaper.ShowConsoleMsg(content)
    end
  else
    reaper.ShowConsoleMsg("\nmanifest.txt: MISSING\n")
  end

  -- Test write ability
  local test_path = pool .. "/_diagnose_test.tmp"
  local tf = io.open(test_path, "w")
  if tf then
    tf:write("test")
    tf:close()
    os.remove(test_path)
    reaper.ShowConsoleMsg("\nWrite test: OK (can write to pool/)\n")
  else
    reaper.ShowConsoleMsg("\nWrite test: FAILED (cannot write to pool/!)\n")
  end

  reaper.ShowConsoleMsg("\n========== END DIAGNOSIS ==========\n")
end

main()
