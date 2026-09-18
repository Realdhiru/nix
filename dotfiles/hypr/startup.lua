local home = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
local scripts = home .. "/.config/hypr/scripts/"

hl.on("hyprland.start", function()
    -- 1. Critical: Sync Wayland environment to D-Bus and start Hyprland session target
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- 2. Critical: Kill competing legacy notification daemons to free the D-Bus namespace for Quickshell
    hl.exec_cmd("killall -q dunst mako swaync hyprnotify || true")

    hl.exec_cmd(scripts .. "boot_wallpaper.sh")
    hl.exec_cmd(scripts .. "wallpaper_watcher.sh")

    -- Idle
    hl.exec_cmd("hypridle")
    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Quickshell
    hl.exec_cmd("quickshell -p " .. scripts .. "quickshell/Shell.qml")
    hl.exec_cmd(scripts .. "quickshell/music/equalizer.sh --init")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 32")
end)