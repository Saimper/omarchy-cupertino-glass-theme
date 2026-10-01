-- Apply after native app rules so dialogs retain their own dimensions. Each
-- window's original tiling state is recorded before conversion and restored
-- when leaving the profile. Config reloads never reposition a managed window.
local signature = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "session"):gsub("[^%w_-]", "_")
local directory = os.getenv("HOME") .. "/.local/state/cupertino-glass/windows/" .. signature .. "/"
-- A new compositor session gets a new signature even when the profile is already
-- active. Create its recovery directory synchronously before the first window.
os.execute("/usr/bin/mkdir -p -m 700 -- '" .. directory:gsub("'", "'\\''") .. "'")
local function free_window(window)
  if not window or not window.mapped or not window.accepts_input or not window.workspace then return end
  if window.workspace.name:sub(1, 8) == "special:" then return end
  local path = directory .. tostring(window.stable_id) .. ".json"
  local exists = io.open(path, "r")
  if exists then exists:close(); return end
  local file = io.open(path .. ".tmp", "w")
  if not file then return end -- Never change a window without a recovery record.
  file:write(string.format('{"address":"%s","stableId":%d,"pid":%d,"floating":%s,"at":[%d,%d],"size":[%d,%d],"fullscreen":%d,"fullscreenClient":%d}\n',
    window.address, window.stable_id, window.pid, tostring(window.floating), window.at.x, window.at.y,
    window.size.x, window.size.y, window.fullscreen, window.fullscreen_client))
  file:close()
  os.rename(path .. ".tmp", path)
  if window.floating or window.fullscreen ~= 0 then return end
  hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
  local monitor = window.monitor
  if not monitor then return end
  local area = monitor.reserved
  local mw, mh = monitor.width / monitor.scale, monitor.height / monitor.scale
  if monitor.transform % 2 == 1 then mw, mh = mh, mw end
  local width = mw - area.left - area.right
  local height = mh - area.top - area.bottom
  local w = math.floor(math.min(1100, width * 0.84))
  local h = math.floor(math.min(760, height * 0.84))
  hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = window }))
  hl.dispatch(hl.dsp.window.move({ x = monitor.x + area.left + math.floor((width-w)/2), y = monitor.y + area.top + math.floor((height-h)/2), window = window }))
end
hl.on("window.open", free_window)
hl.on("config.reloaded", function()
  for _, window in ipairs(hl.get_windows()) do free_window(window) end
end)
return free_window
