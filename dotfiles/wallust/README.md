# Standalone Wallust Theme Engine

Self-contained system theming engine using [Wallust](https://codeberg.org/explosion-mental/wallust).
Extracts vivid 16-color ANSI palettes, calculates perceptual luminance metrics, and generates configuration files for desktop applications.

## Portability Contract
This entire folder (`dotfiles/wallust/`) can be copied to ANY Linux machine running any desktop environment or window manager.

### Prerequisites
- `wallust` (Rust-based color generator)
- `python3` with `Pillow` (for luminance calculation)
- `jq` (JSON manipulation)

### Usage
```bash
# Generate dark theme from image:
./generate.sh /path/to/wallpaper.png dark

# Generate light theme:
./generate.sh /path/to/wallpaper.png light

# Generate neutral fallback theme:
./generate.sh --neutral
```

### Outputs Generated in `~/.cache/theme/`:
- `colors.json`: Catppuccin-mapped JSON palette for shell/widgets.
- `wezterm-colors.lua`: 16-color ANSI palette for WezTerm.
- `cava`: 8-stop gradient audio visualizer configuration.
- `gtk.css`: GTK3 & GTK4 color variable overrides.
- `qtct.conf` & `qt-style.qss`: Qt5 and Qt6 color palette and stylesheets.
- `hyprland-colors.conf`: Window manager active and inactive border gradients.
