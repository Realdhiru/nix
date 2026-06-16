local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

-- Add Matugen cache to the Lua runtime module path lookup
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/.cache/matugen/?.lua"

-- Safe package lookup loop
local ok, matugen = pcall(require, "wezterm-colors")
if ok and type(matugen) == "table" then
    config.colors = matugen
else
    -- Fallback to static config if matugen file isn't present
    local static_ok, static_colors = pcall(dofile, home .. "/.config/wezterm/colors.lua")
    if static_ok then
        config.colors = static_colors
    end
end

return config