local home = os.getenv("HOME") or ""
local desktop_state = os.getenv("DESKTOP_STATE_DIR") or ((os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/desktop")
local is_opaque = false

local function is_solid_mode()
    local f = io.open(desktop_state .. "/modes/modes.json", "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content:match('"opacity_solid"%s*:%s*true') then
            return true
        end
    end
    -- Fallback for quickshell state.json
    local f_state = io.open(desktop_state .. "/quickshell/state.json", "r")
    if f_state then
        local content = f_state:read("*a")
        f_state:close()
        if content and (content:match('"gaming"%s*:%s*true') or content:match('"wallpaperKilled"%s*:%s*true') or content:match('"profile"%s*:%s*"power%-saver"')) then
            return true
        end
    end
    return false
end

if is_solid_mode() then
    is_opaque = true
end


-- Opacity options: "0.0" (transparent) to "1.0" (opaque). Glass range: "0.50" to "0.70"
hl.window_rule({ match = { class = "^app.liten.Gram$" }, opacity = "0.76" })
hl.window_rule({ match = { class = "^antigravity$" }, opacity = "0.47" })
hl.window_rule({ match = { class = "^chatgpt$" }, opacity = "0.47" })
hl.window_rule({ match = { class = "^Chatgpt$" }, opacity = "0.5" })
hl.window_rule({ match = { class = "^(pcmanfm-qt)$" }, opacity = "0.6" })
hl.window_rule({ match = { class = "^(Alacritty)$" }, opacity = "0.70" })
hl.window_rule({ match = { class = "^(obsidian|md.obsidian.Obsidian)$" }, opacity = "0.65" })

-- Brave Apps
hl.window_rule({ match = { class = "^brave-chat\\.openai\\.com__-Default$" }, opacity = "0.57" })                               -- ChatGPT
hl.window_rule({ match = { class = "^brave-gemini\\.google\\.com__app-Default$" }, opacity = "0.57" })                          -- Gemini
hl.window_rule({ match = { class = "^brave-claude\\.ai__new-Default$" }, opacity = "0.57" })                                    -- Claude
hl.window_rule({ match = { class = "^brave-www\\.notion\\.so__02917993852a4825ab25a38c938de4f8-Default$" }, opacity = "0.57" }) -- Notion
hl.window_rule({ match = { class = "^(brave-to-do\\.live\\.com__tasks-Default|todo)$" }, opacity = "0.57" })                     -- To-Do

-- Spotify Lyrics (Chromium)
hl.window_rule({ match = { class = "^(chromium-browser)$" }, opacity = "0.85" })

-- Dynamic solid mode enforcement: apply opaque window property directly without polluting rules
if is_solid_mode() then
    for _, w in ipairs(hl.get_windows()) do
        if w.address then
            hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. w.address, prop = "opaque", value = "1" }))
        end
    end
end

hl.on("window.open", function(w)
    if is_solid_mode() and w and w.address then
        hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. w.address, prop = "opaque", value = "1" }))
    end
end)

-- ======================================================
-- Spotify Lyrics Popup (CEF / chromium-browser)
-- ======================================================
hl.window_rule({
    match = { class = "^(chromium-browser)$", title = ".*•.*" },
    float = true,
    pin = true,
    size = { 300, 95 },
    opacity = "1.0 override 1.0 override",
    no_shadow = true,
})

-- ======================================================
-- Global Rules
-- ======================================================

-- Ignore maximize requests from applications
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Automatically center all modal dialogs ("Are you sure?", file prompts, confirmation boxes)
hl.window_rule({ match = { modal = true }, float = true, center = true })

-- Automatically center all floating XWayland popups/dialogs
hl.window_rule({ match = { xwayland = true, float = true }, center = true })

-- Prevent focus issues with transient XWayland windows
hl.window_rule({ match = { class = "^$", title = "^$", xwayland = true, float = true }, no_focus = true })

-- ======================================================
-- Bluetooth Manager
-- ======================================================

hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = { 700, 500 } })

-- ======================================================
-- KDE Connect
-- ======================================================

hl.window_rule({ match = { class = "^(org\\.kde\\.kdeconnect\\.app|kdeconnect-app)$" }, float = true, center = true, size = { 750, 550 } })

-- ======================================================
-- PipeWire Volume Control
-- ======================================================

hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, float = true, center = true, size = { 900, 600 } })

-- ======================================================
-- PCManFM Search Files (dialog only, main window unaffected)
-- ======================================================

hl.window_rule({ match = { class = "^(pcmanfm-qt)$", title = "^(Search Files)$" }, float = true, center = true })


-- ======================================================
-- Picture-in-Picture
-- ======================================================

hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, float = true, pin = true, size = { "25%", "25%" }, move = { "73%", "72%" }, opacity = "1.0 override 1.0 override" })
hl.window_rule({ match = { title = "^(Picture-in-Picture|Picture in picture)$" }, float = true, pin = true, size = { "25%", "25%" }, move = { "73%", "72%" }, opacity = "1.0 override 1.0 override" })

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
-- Image Viewers (Popup modal for photo openers)
-- ======================================================

hl.window_rule({ match = { class = "^(org\\.gnome\\.Loupe)$" }, float = true, center = true, size = { 850, 550 } })

-- ======================================================
-- Steam & Gaming Dialogs
-- ======================================================

hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List|Special Offers|Music Player|Screenshot Uploader)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Steam Settings)$" }, float = true, center = true, size = { 900, 700 } })

-- ======================================================
-- Idle Inhibit & Video Rules (Fullscreen Video / Games / YouTube)
-- ======================================================

hl.window_rule({ match = { class = "^(mpv)$" }, idle_inhibit = "focus" })
hl.window_rule({ match = { class = "^(brave-youtube\\.com__-youtube|youtube)$" }, idle_inhibit = "focus", opacity = "1.0 override 1.0 override", min_size = { 426, 240 } })

-- ======================================================
-- Office Suites (Solid Opacity to prevent XWayland/CEF buffer drops)
-- ======================================================

hl.window_rule({ match = { class = "^(ONLYOFFICE)$" }, opacity = "1.0 override 1.0 override" })

-- ======================================================
-- Neo Browser (Xephyr :7 — dedicated nested X server)
-- Opens in fullscreen mode matching physical display 2880x1620
-- for 1:1 pixel-perfect HiDPI rendering with zero clipping.
-- ======================================================

hl.window_rule({
    match = { class = "^Xephyr$" },
    fullscreen = true,
})

-- ======================================================
-- Quickshell
-- ======================================================

hl.window_rule({ match = { title = "^app-launcher$" }, float = true, center = true, size = { 1200, 600 } })

-- ======================================================
-- Layer Rules
-- ======================================================

-- Fuzzel (Native Wayland launcher) - matched to Quickshell liquid glass
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "^(fuzzel|launcher)$" }, animation = "fade" })

-- Quickshell (Liquid Glassmorphism on bar, sidebar, popups, drawer, and toast)
hl.layer_rule({ match = { namespace = "^(quickshell|qs-.*)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(quickshell|qs-.*)$" }, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "^(quickshell|qs-.*)$" }, animation = "none" })

-- Wallpaper Daemons (Instant, Zero Animation Jump)
hl.layer_rule({ match = { namespace = "^(awww-daemon|mpvpaper)$" }, animation = "none" })
