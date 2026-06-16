local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

-- 1. Use WezTerm's native home_dir (os.getenv("HOME") crashes during background reloads)
local matugen_path = wezterm.home_dir .. "/.cache/matugen/wezterm-colors.lua"

-- 2. Explicitly watch the generated file for automatic hot-reloading
wezterm.add_to_config_reload_watch_list(matugen_path)

-- 3. Wrap dofile in a pcall. If Matugen is in the middle of writing the file 
--    and it is temporarily empty, pcall prevents the terminal from crashing.
local success, theme = pcall(dofile, matugen_path)
if success and type(theme) == "table" then
    config.colors = theme
end

return config