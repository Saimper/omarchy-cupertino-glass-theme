-- Loaded only by the Cupertino profile; the original appearance is restored on exit.
local current = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme.name", "r")
local theme = current and current:read("*l") or ""
if current then current:close() end
if theme ~= "cupertino-light" and theme ~= "cupertino-dark" then return end
local native = os.getenv("HOME") .. "/.local/share/cupertino-glass/plugins-native/"
-- Configuration-owned plugins automatically unload when this profile is removed.
-- Both binaries reject a Hyprland ABI different from their compiled headers.
local header = io.open("/usr/include/hyprland/src/version.h", "r")
local version = header and header:read("*a") or ""
if header then header:close() end
local function exists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end
if version:find("efb50993780079460b0cbed1363e2166a2de1d9f", 1, true)
    and exists(native .. "build/cupertino-bridge.so")
    and exists(native .. "build/hyprbars.so") then
  hl.plugin.load(native .. "build/cupertino-bridge.so")
  hl.plugin.load(native .. "build/hyprbars.so")
  dofile(native .. "profile.lua")
else
  print("Cupertino: native window controls require rebuilding for this Hyprland version; keeping standard controls.")
end
hl.config({
  general = { border_size = 0, gaps_in = 0, gaps_out = 0, resize_on_border = true, extend_border_grab_area = 8 },
  input = { follow_mouse = 0 },
  decoration = {
    rounding = 14,
    -- Light from above: a quiet upper edge and a soft contact shadow below.
    shadow = {
      enabled = true, range = 36, render_power = 4,
      color = { colors = { "rgba(00000048)", "rgba(00000090)" }, angle = 90 },
      color_inactive = { colors = { "rgba(00000018)", "rgba(00000048)" }, angle = 90 },
      offset = { 0, 4 },
    },
    blur = { enabled = true, size = 7, passes = 3, vibrancy = 0.04, noise = 0.006 },
  },
  group = { groupbar = { font_family = "Inter Variable", font_weight_active = "semibold", font_size = 12, gradient_rounding = 8 } },
})
-- Application content stays opaque; glass belongs to shell surfaces. This also
-- keeps a terminal's own background and its matching titlebar visually joined.
hl.window_rule({ match = { tag = "default-opacity" }, opacity = "1 override 1 override 1 override" })
hl.layer_rule({ match = { namespace = "^(cupertino-dock|cupertino-controls|cupertino-app-library)$" }, blur = true, ignore_alpha = 0.11, no_anim = true })
hl.layer_rule({ match = { namespace = "^(omarchy-keyboard-panel|omarchy-menu|omarchy-notification.*)$" }, blur = true, ignore_alpha = 0.15 })
hl.curve("cupertinoEase", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("cupertinoClose", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2.2, bezier = "cupertinoEase" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.6, bezier = "cupertinoEase", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "cupertinoClose", style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.2, bezier = "cupertinoEase" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.8, bezier = "cupertinoEase" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.3, bezier = "cupertinoClose" })
-- Same application-launching action as the user's existing SUPER+A binding.
hl.unbind("SUPER + A")
hl.bind("SUPER + A", hl.dsp.exec_cmd("omarchy-shell cupertino.apps toggle"), { description = "Applications — Cupertino" })

-- SUPER+O normally floats and pins. The original binding returns on profile exit.
hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximizar / restaurar — Cupertino" })
dofile(os.getenv("HOME") .. "/.local/share/cupertino-glass/floating.lua")
