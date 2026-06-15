local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

local ok, colors = pcall(dofile, os.getenv("HOME") .. "/.config/wezterm/colors.lua")

if ok then
    config.colors = colors
end

return config