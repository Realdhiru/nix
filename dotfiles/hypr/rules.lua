-- ======================================================
-- Opacity
-- ======================================================

hl.window_rule({ match = { class = "^org\\.wezfurlong\\.wezterm$" }, opacity = "0.52" })
hl.window_rule({ match = { class = "^codium$" }, opacity = "0.63" })
hl.window_rule({ match = { class = "^antigravity-ide$" }, opacity = "0.71" })
hl.window_rule({ match = { class = "^(pcmanfm-qt)$" }, opacity = "0.6" })

-- Brave Apps
hl.window_rule({ match = { class = "^brave-chat\\.openai\\.com__-Default$" }, opacity = "0.55" })                        -- ChatGPT
hl.window_rule({ match = { class = "^brave-gemini\\.google\\.com__app-Default$" }, opacity = "0.55" })                   -- Gemini
hl.window_rule({ match = { class = "^brave-claude\\.ai__new-Default$" }, opacity = "0.55" })                              -- Claude
hl.window_rule({ match = { class = "^brave-monkeytype\\.com__-Default$" }, opacity = "0.50" })                            -- Monkeytype
hl.window_rule({ match = { class = "^brave-www\\.notion\\.so__02917993852a4825ab25a38c938de4f8-Default$" }, opacity = "0.65" }) -- Notion

-- Spotify Lyrics (Chromium)
hl.window_rule({ match = { class = "^Chromium-browser$" }, opacity = "0.80" })

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

hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, center = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, size = { 700, 500 } })
-- hl.window_rule({ match = { class = "^(blueman-manager)$" }, pin = true })

-- ======================================================
-- PipeWire Volume Control
-- ======================================================

hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, float = true })
hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, center = true })
hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, size = { 900, 600 } })
-- hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, pin = true })

-- ======================================================
-- PCManFM Search Files (dialog only, main window unaffected)
-- ======================================================

hl.window_rule({ match = { class = "^(pcmanfm-qt)$", title = "^(Search Files)$" }, float = true })
hl.window_rule({ match = { class = "^(pcmanfm-qt)$", title = "^(Search Files)$" }, center = true })

-- ======================================================
-- Easy Effects
-- ======================================================

hl.window_rule({ match = { class = "^(com\\.github\\.wwmm\\.easyeffects)$" }, float = true })
hl.window_rule({ match = { class = "^(com\\.github\\.wwmm\\.easyeffects)$" }, center = true })

-- ======================================================
-- Picture-in-Picture
-- ======================================================

hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, pin = true })
hl.window_rule({ match = { title = "^(.*[Pp][Ii][Cc][Tt][Uu][Rr][Ee].*)$" }, size = { "10%", "10%" } })

-- More generic PiP matcher
-- hl.window_rule({ match = { float = true, title = "^(.*[Pp]icture.*[Pp]icture.*)$" } })
-- hl.window_rule({ match = { pin = true, title = "^(.*[Pp]icture.*[Pp]icture.*)$" } })
-- hl.window_rule({ match = { title = "^(.*[Pp]icture.*[Pp]icture.*)$" }, size = { "25%", "25%" } })
-- hl.window_rule({ match = { title = "^(.*[Pp]icture.*[Pp]icture.*)$" }, move = { "73%", "72%" } })

-- ======================================================
-- Quickshell
-- ======================================================

hl.window_rule({ match = { title = "^app-launcher$" }, float = true })
hl.window_rule({ match = { title = "^app-launcher$" }, center = true })
hl.window_rule({ match = { title = "^app-launcher$" }, size = { 1200, 600 } })

-- ======================================================
-- Layer Rules
-- ======================================================

-- Rofi
hl.layer_rule({ match = { namespace = "^rofi$" }, blur = true })
hl.layer_rule({ match = { namespace = "^rofi$" }, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "^rofi$" }, animation = "slide left" })

-- Quickshell (Glassmorphism)
hl.layer_rule({ match = { namespace = "quickshell" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell" }, ignore_alpha = 0.0 })

-- hl.layer_rule({ match = { namespace = "quickshell-notifications" }, blur = true })
-- hl.layer_rule({ match = { namespace = "quickshell-notifications" }, ignore_alpha = 0 })

-- hl.layer_rule({ match = { namespace = "quickshell-control-center" }, blur = true })
-- hl.layer_rule({ match = { namespace = "quickshell-control-center" }, ignore_alpha = 0 })

-- ======================================================
-- Counter-Strike 2
-- ======================================================

-- hl.window_rule({ match = { class = "^cs2$" }, immediate = true })
-- hl.window_rule({ match = { class = "^cs2$" }, keep_aspect_ratio = true })