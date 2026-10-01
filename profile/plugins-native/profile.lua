-- Loaded after hyprbars; native GTK/libadwaita titlebars keep their own controls.
-- Only terminal clients without a titlebar receive a compositor frame.
local input = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme.name", "r")
local theme = input and input:read("*l") or ""
if input then input:close() end
if theme ~= "cupertino-light" and theme ~= "cupertino-dark" then return end
if not hl.plugin.hyprbars then return end
local dark = theme == "cupertino-dark"
local command = os.getenv("HOME") .. "/.local/share/cupertino-glass/bin/cupertino-window "
hl.config({ plugin = { hyprbars = {
  enabled = true,
  bar_height = 30,
  bar_color = dark and "rgb(24273a)" or "rgba(f4f4f6ed)",
  bar_blur = true,
  ["col.text"] = dark and "rgba(f5f5f7ec)" or "rgba(252527ed)",
  bar_text_size = 12,
  bar_text_font = "Inter Variable",
  bar_text_weight = "medium",
  bar_text_align = "center",
  bar_buttons_alignment = "left",
  bar_part_of_window = true,
  bar_precedence_over_border = true,
  bar_padding = 14,
  bar_button_padding = 8,
  inactive_button_color = "rgba(00000000)",
  icon_on_hover = true,
  on_double_click = command .. "maximize",
} } })
hl.window_rule({ match = { class = ".*" }, ["hyprbars:no_bar"] = true })
-- Only clients without their own titlebar use compositor controls.
hl.window_rule({ match = { class = "^(foot|footclient|org\\.omarchy\\.terminal|Alacritty|kitty|cupertino-terminal)$" }, ["hyprbars:no_bar"] = false })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(ff5f57)", fg_color = "rgb(67231e)", size = 12, icon = "", action = command .. "close" })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(febc2e)", fg_color = "rgb(6a480b)", size = 12, icon = "", action = command .. "minimize" })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(28c840)", fg_color = "rgb(0c5318)", size = 12, icon = "", action = command .. "maximize" })
