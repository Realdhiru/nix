local home = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
local scripts = home .. "/.config/hypr/scripts/"

hl.on("hyprland.start", function()
    -- 1. Critical: Sync Wayland environment synchronously before triggering session target
    os.execute("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    os.execute("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- 2. Apply display and power policy through one serialized request.
    hl.exec_cmd(scripts .. "power.sh auto")

    -- 3. Keep startup, reload, and the toggle bind behind one singleton owner.
    hl.exec_cmd("bash " .. scripts .. "qs_manager.sh start")
    hl.exec_cmd("timeout 3 hyprctl setcursor Bibata-Modern-Ice 32")

    -- 4. Wallpaper initialization in background
    hl.exec_cmd(home .. "/.config/wallpaper/wallpaper.sh boot")
    hl.exec_cmd(home .. "/.config/wallpaper/wallpaper.sh watch")

    -- 5. Idle & Utilities
    hl.exec_cmd("hypridle")
    -- KDE Connect: autostart disabled per user request
    -- hl.exec_cmd("kdeconnect-indicator")
    hl.exec_cmd(scripts .. "quickshell/music/equalizer.sh --init")
    hl.exec_cmd(scripts .. "battery_audit.sh start")
end)
