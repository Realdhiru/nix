local wezterm = require "wezterm"
local config = {}

if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

local matugen_path = wezterm.home_dir .. "/.cache/matugen/wezterm-colors.lua"
wezterm.add_to_config_reload_watch_list(matugen_path)

local ok, matugen = pcall(dofile, matugen_path)
if ok and type(matugen) == "table" then
    config.colors = matugen
end

return config