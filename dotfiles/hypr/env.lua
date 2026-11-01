hl.env("NIXOS_OZONE_WL", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "")

-- Default Applications
hl.env("TERMINAL", "alacritty")
hl.env("BROWSER", "brave")
hl.env("EDITOR", "gram")
hl.env("FILEMANAGER", "pcmanfm-qt")

-- HiDPI Toolkit Coordinate Synchronization (2.0x integer display scale)
hl.env("GDK_SCALE", "2")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_ENABLE_HIGHDPI_SCALING", "1")

-- Global Cursor Environment Variables
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "32")