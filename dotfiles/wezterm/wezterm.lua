local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

-- 1. Establish path strings
local home = os.getenv("HOME")
local static_colors_path = home .. "/.config/wezterm/colors.lua"
local matugen_path = home .. "/.cache/matugen/wezterm-colors.lua"

-- 2. Define a function to load the colors dynamically
local function load_colors()
    -- Try Matugen first
    local f = io.open(matugen_path, "r")
    if f then
        f:close()
        return dofile(matugen_path)
    end

    -- Fallback to static config if Matugen isn't generated yet
    local ok, static_colors = pcall(dofile, static_colors_path)
    if ok then
        return static_colors
    end

    return nil
end

-- Load colors on startup
config.colors = load_colors()

-- 3. FIXED RELOAD WATCHER: Push the file track hook explicitly into the reload array
wezterm.add_to_config_reload_watch_list(matugen_path)

return config