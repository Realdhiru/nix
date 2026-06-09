local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.scrollback_lines = 100000

return config