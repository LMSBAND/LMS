-- DRUMBANGER: Open Pool Folder
-- -----------------------------
-- Opens the pool folder in your system file manager.
-- Drop .wav files or folders of .wav files in there, then run Rescan.
--
-- Install: Actions > Show Action List > New Action > Load ReaScript

local function main()
  local resource_path = reaper.GetResourcePath()
  local pool_dir = resource_path .. "/Effects/DRUMBANGER/pool"
  reaper.RecursiveCreateDirectory(pool_dir, 0)

  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    os.execute('explorer "' .. pool_dir:gsub("/", "\\") .. '"')
  elseif os_name:match("OSX") or os_name:match("macOS") then
    os.execute('open "' .. pool_dir .. '"')
  else
    os.execute('xdg-open "' .. pool_dir .. '" &')
  end
end

main()
