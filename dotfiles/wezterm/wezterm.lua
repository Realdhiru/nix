local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

-- Securely load the Matugen generated file
local matugen_path = os.getenv("HOME") .. "/.cache/matugen/wezterm-colors.lua"

local f = io.open(matugen_path, "r")
if f then
    f:close()
    local ok, matugen_colors = pcall(dofile, matugen_path)
    if ok and type(matugen_colors) == "table" then
        config.colors = matugen_colors
    end
end

-- Must be at the very bottom
return config