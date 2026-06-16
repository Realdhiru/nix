local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

local home = os.getenv("HOME")
local matugen_file = home .. "/.cache/matugen/wezterm-colors.lua"

-- 1. Force WezTerm to watch the specific generated file for changes
wezterm.add_to_config_reload_watch_list(matugen_file)

-- 2. Use dofile() instead of require() so it reads fresh from disk every single time
local f = io.open(matugen_file, "r")
if f then
    f:close()
    local ok, matugen_colors = pcall(dofile, matugen_file)
    if ok and type(matugen_colors) == "table" then
        config.colors = matugen_colors
    end
else
    -- Fallback
    local ok, static_colors = pcall(dofile, home .. "/.config/wezterm/colors.lua")
    if ok and type(static_colors) == "table" then
        config.colors = static_colors
    end
end

return config