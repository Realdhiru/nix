local home = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
local scripts = home .. "/.config/hypr/scripts/"

hl.on("hyprland.start", function()
    -- 1. Critical: Sync Wayland environment to D-Bus and start Hyprland session target
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- 2. Quickshell: Launch immediately so TopBar & master window render concurrently
    hl.exec_cmd("quickshell -p " .. scripts .. "quickshell/Shell.qml")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 32")

    -- 3. Wallpaper initialization in background
    hl.exec_cmd(scripts .. "boot_wallpaper.sh")

    -- 4. Idle & Utilities
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(scripts .. "quickshell/music/equalizer.sh --init")
end)