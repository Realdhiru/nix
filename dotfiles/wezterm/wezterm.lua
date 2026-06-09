local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.scrollback_lines = 100000

config.window_close_confirmation = "NeverPrompt"

config.hide_tab_bar_if_only_one_tab = true

config.adjust_window_size_when_changing_font_size = false

config.default_prog = {
  "zsh",
  "-c",
  [[
count=$(pgrep -u "$USER" wezterm-gui | wc -l)

if [ "$count" -eq 1 ] && command -v fastfetch >/dev/null; then
  fastfetch
fi

exec zsh
]]
}

return config