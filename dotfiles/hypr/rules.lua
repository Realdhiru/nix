local home = os.getenv("HOME") or ""
local is_opaque = false

local function check_file(path)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        return true, content
    end
    return false, nil
end

local killed_ok, _ = check_file(home .. "/.cache/wallpaper_killed")
local game_ok, _ = check_file(home .. "/.cache/gaming_mode")
local prof_ok, prof_val = check_file(home .. "/.cache/qs_power_profile")

if killed_ok or game_ok or (prof_ok and prof_val and prof_val:match("power%-saver")) then
    is_opaque = true
end

if not is_opaque then
    hl.window_rule({ match = { class = "^codium$" }, opacity = "0.65" })
    hl.window_rule({ match = { class = "^spotify$" }, opacity = "0.92" })
    hl.window_rule({ match = { class = "^antigravity-ide$" }, opacity = "0.67" })
    hl.window_rule({ match = { class = "^(pcmanfm-qt)$" }, opacity = "0.67" })

    -- Brave Apps
    hl.window_rule({ match = { class = "^brave-chat\\.openai\\.com__-Default$" }, opacity = "0.57" })                        -- ChatGPT
    hl.window_rule({ match = { class = "^brave-gemini\\.google\\.com__app-Default$" }, opacity = "0.57" })                   -- Gemini
    hl.window_rule({ match = { class = "^brave-claude\\.ai__new-Default$" }, opacity = "0.57" })                              -- Claude
    hl.window_rule({ match = { class = "^brave-monkeytype\\.com__-Default$" }, opacity = "0.57" })                            -- Monkeytype
    hl.window_rule({ match = { class = "^brave-www\\.notion\\.so__02917993852a4825ab25a38c938de4f8-Default$" }, opacity = "0.57" }) -- Notion

    -- Spotify Lyrics (Chromium)
    hl.window_rule({ match = { class = "^Chromium-browser$" }, opacity = "0.57" })
else
    hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override" })
end

-- ======================================================
-- Global Rules
-- ======================================================

-- Ignore maximize requests from applications
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Prevent focus issues with transient XWayland windows
hl.window_rule({ match = { class = "^$", title = "^$", xwayland = true, float = true }, no_focus = true })

-- ======================================================
-- Bluetooth Manager
-- ======================================================

hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = { 700, 500 } })

-- ======================================================
-- PipeWire Volume Control
-- ======================================================

hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, float = true, center = true, size = { 900, 600 } })

-- ======================================================
-- PCManFM Search Files (dialog only, main window unaffected)
-- ======================================================

hl.window_rule({ match = { class = "^(pcmanfm-qt)$", title = "^(Search Files)$" }, float = true, center = true })

-- ======================================================
-- Easy Effects
-- ======================================================

hl.window_rule({ match = { class = "^(com\\.github\\.wwmm\\.easyeffects)$" }, float = true, center = true })

-- ======================================================
-- Picture-in-Picture
-- ======================================================

hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, float = true, pin = true, size = { "25%", "25%" }, move = { "73%", "72%" } })
hl.window_rule({ match = { title = "^(Picture-in-Picture|Picture in picture)$" }, float = true, pin = true, size = { "25%", "25%" }, move = { "73%", "72%" } })

-- ======================================================
-- System Dialogs, Portals & Authentication
-- ======================================================

hl.window_rule({ match = { class = "^(polkit-gnome-authentication-agent-1)$" }, float = true, center = true, pin = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true, center = true, size = { 700, 500 } })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\.kde)$" }, float = true, center = true, size = { 900, 600 } })
hl.window_rule({ match = { class = "^(org\\.kde\\.kcalc|gnome-calculator)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(filelight)$" }, float = true, center = true, size = { 950, 650 } })
hl.window_rule({ match = { class = "^(lxqt-archiver)$" }, float = true, center = true, size = { 850, 550 } })

-- ======================================================
-- Steam & Gaming Dialogs
-- ======================================================

hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List|Special Offers|Music Player|Screenshot Uploader)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Steam Settings)$" }, float = true, center = true, size = { 900, 700 } })

-- ======================================================
-- Idle Inhibit (Fullscreen Video / Games)
-- ======================================================

hl.window_rule({ match = { class = "^(mpv)$" }, idle_inhibit = "focus" })

-- ======================================================
-- Quickshell
-- ======================================================

hl.window_rule({ match = { title = "^app-launcher$" }, float = true, center = true, size = { 1200, 600 } })

-- ======================================================
-- Layer Rules
-- ======================================================

-- Fuzzel (Native Wayland launcher)
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, animation = "fade" })

-- Quickshell (Glassmorphism)
hl.layer_rule({ match = { namespace = "^(qs-master)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(qs-master)$" }, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "^(qs-master)$" }, animation = "none" })
hl.layer_rule({ match = { namespace = "quickshell" }, ignore_alpha = 0.0 })
hl.layer_rule({ match = { namespace = "quickshell" }, animation = "none" })

-- ======================================================
-- Counter-Strike 2
-- ======================================================

-- hl.window_rule({ match = { class = "^cs2$" }, immediate = true })
-- hl.window_rule({ match = { class = "^cs2$" }, keep_aspect_ratio = true })