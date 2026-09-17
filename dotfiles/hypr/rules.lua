-- ======================================================
-- Opacity
-- ======================================================

hl.window_rule({ match = { class = "^codium$" }, opacity = "0.65" })
hl.window_rule({ match = { class = "^spotify$" }, opacity = "0.92" })
hl.window_rule({ match = { class = "^antigravity-ide$" }, opacity = "0.7" })
hl.window_rule({ match = { class = "^(pcmanfm-qt)$" }, opacity = "0.67" })

-- Brave Apps
hl.window_rule({ match = { class = "^brave-chat\\.openai\\.com__-Default$" }, opacity = "0.57" })                        -- ChatGPT
hl.window_rule({ match = { class = "^brave-gemini\\.google\\.com__app-Default$" }, opacity = "0.57" })                   -- Gemini
hl.window_rule({ match = { class = "^brave-claude\\.ai__new-Default$" }, opacity = "0.57" })                              -- Claude
hl.window_rule({ match = { class = "^brave-monkeytype\\.com__-Default$" }, opacity = "0.57" })                            -- Monkeytype
hl.window_rule({ match = { class = "^brave-www\\.notion\\.so__02917993852a4825ab25a38c938de4f8-Default$" }, opacity = "0.57" }) -- Notion

-- Spotify Lyrics (Chromium)
hl.window_rule({ match = { class = "^Chromium-browser$" }, opacity = "0.57" })

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

hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, float = true, pin = true, size = { "10%", "10%" } })

-- More generic PiP matcher
-- hl.window_rule({ match = { float = true, title = "^(.*[Pp]icture.*[Pp]icture.*)$" } })
-- hl.window_rule({ match = { pin = true, title = "^(.*[Pp]icture.*[Pp]icture.*)$" } })
-- hl.window_rule({ match = { title = "^(.*[Pp]icture.*[Pp]icture.*)$" }, size = { "25%", "25%" } })
-- hl.window_rule({ match = { title = "^(.*[Pp]icture.*[Pp]icture.*)$" }, move = { "73%", "72%" } })

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
-- hl.layer_rule({ match = { namespace = "quickshell" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell" }, ignore_alpha = 0.0 })
hl.layer_rule({ match = { namespace = "quickshell" }, animation = "none" })

-- hl.layer_rule({ match = { namespace = "quickshell-notifications" }, blur = true })
-- hl.layer_rule({ match = { namespace = "quickshell-notifications" }, ignore_alpha = 0 })

-- hl.layer_rule({ match = { namespace = "quickshell-control-center" }, blur = true })
-- hl.layer_rule({ match = { namespace = "quickshell-control-center" }, ignore_alpha = 0 })

-- ======================================================
-- Counter-Strike 2
-- ======================================================

-- hl.window_rule({ match = { class = "^cs2$" }, immediate = true })
-- hl.window_rule({ match = { class = "^cs2$" }, keep_aspect_ratio = true })