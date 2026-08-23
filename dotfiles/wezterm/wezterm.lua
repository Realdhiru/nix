local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

config.window_background_opacity = 0.0

-- Render via WebGpu (Vulkan/ANV): the iris-GL path on mesa 26.2 + i915 hangs
-- (ecode 12:1:859ffffb) on this Alder Lake Iris Xe; the Vulkan path is clean.
config.front_end = "WebGpu"

-- Default font size (1.5x WezTerm's 12pt baseline). The `af` fetch UI may
-- temporarily override this via ~/.cache/af_font_size (removed on exit).
config.font_size = 18

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