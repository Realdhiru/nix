# Standalone Wallpaper Subsystem

Self-contained desktop wallpaper manager supporting static images, animated GIFs, and video wallpapers (via `awww` and `mpvpaper`).
Includes thumbnail generation, background directory synchronization via inotify, and online DuckDuckGo wallpaper searching.

## Portability Contract
This entire folder (`dotfiles/wallpaper/`) can be copied to ANY Linux system.
It has zero hardcoded dependencies on QuickShell or window managers.

### Subcommands
```bash
# Set desktop wallpaper (image, gif, video):
./wallpaper.sh set /path/to/wallpaper.jpg

# Restore last wallpaper on login:
./wallpaper.sh boot

# Kill wallpaper daemons and reset theme:
./wallpaper.sh kill

# Manage awww-daemon lifecycle:
./wallpaper.sh ensure [--restart|--stop]

# Generate thumbnails and color markers:
./wallpaper.sh thumb

# Start background directory watcher for ~/Pictures/Wallpapers:
./wallpaper.sh watch

# Clean broken symlinks and orphaned cache entries:
./wallpaper.sh clean

# Search and download online wallpapers:
./wallpaper.sh search "cyberpunk 4k"
```

### Clean Event Handshake
When a wallpaper is set or killed, this subsystem notifies the theme engine if present (`~/.config/wallust/generate.sh` or `$THEME_ENGINE`), completely decoupling wallpaper rendering from color generation.
