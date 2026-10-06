local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

-- Window background opacity: 0.0 for pure transparency
config.window_background_opacity = 0.11

-- Render via WebGpu (Vulkan/ANV): the iris-GL path on mesa + i915 hangs
-- (ecode 12:1:859ffffb) on Raptor Lake Iris Xe; the Vulkan path is clean.
config.front_end = "WebGpu"

-- Grayscale antialiasing for OLED panel (disables LCD RGB subpixel fringing)
config.freetype_load_target = "Normal"
config.freetype_render_target = "Normal"

-- Default font size (1.5x WezTerm's 12pt baseline). The `af` fetch UI may
-- temporarily override this via ~/.cache/af_font_size (removed on exit).
config.font_size = 9

-- 1. Use WezTerm's native home_dir (os.getenv("HOME") crashes during background reloads)
local theme_path = wezterm.home_dir .. "/.cache/theme/colors.json"

-- 2. Explicitly watch the generated file for automatic hot-reloading
wezterm.add_to_config_reload_watch_list(theme_path)

-- 3. Parse JSON colors directly (Single Source of Truth)
local f = io.open(theme_path, "r")
if f then
    local content = f:read("*a")
    f:close()
    local success, theme = pcall(wezterm.json_parse, content)
    if success and type(theme) == "table" then
        config.colors = {
            foreground = theme.text or theme.foreground or "#EDE6DC",
            background = theme.base or theme.background or "#000000",
            cursor_bg = theme.cursor_bg or theme.primary or "#EDE6DC",
            cursor_fg = theme.cursor_fg or theme.base or "#000000",
            cursor_border = theme.cursor_border or theme.primary or "#EDE6DC",
            selection_bg = theme.selection_bg or theme.primary or "#313131",
            selection_fg = theme.selection_fg or theme.text or "#EDE6DC",
            ansi = theme.ansi or {
                "#151515", "#484849", "#5E5E60", "#747576",
                "#7E7E7F", "#878889", "#ADADAF", "#EAEBEC"
            },
            brights = theme.brights or {
                "#404040", "#4C4D4F", "#6A6A6C", "#828284",
                "#8B8C8E", "#B4B5B7", "#E6E7E9", "#FFFFFF"
            }
        }
        if theme.opacity then
            config.window_background_opacity = theme.opacity
        end
    end
end

return config
