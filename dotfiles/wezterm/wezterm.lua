local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.scrollback_lines = 100000
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false

wezterm.on("gui-startup", function()
  wezterm.background_child_process({
    "zsh",
    "-ic",
    "fastfetch"
  })
end)

return config