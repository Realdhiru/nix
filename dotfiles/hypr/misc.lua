-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({
    misc = {
        force_default_wallpaper = 0, -- Disable mascot wallpaper, render background_color
        disable_hyprland_logo   = true,
        background_color        = 0x000000, -- OLED pure pitch-black (0 light emitted on OLED)
        key_press_enables_dpms  = false,    -- Disallow keypresses from waking DPMS to prevent typing keys into focused windows/lockscreen
        mouse_move_enables_dpms = true,     -- Wakes display cleanly on mouse/touchpad movement
    },

    -- https://wiki.hypr.land/Configuring/Variables/#debug
    debug = {
        vfr              = true, -- POWER OPTIMIZATION: Only render when the screen changes
        damage_tracking  = 1,
    },

    -- Layout
    dwindle = {
        preserve_split = true,
    },

    scrolling = {
        column_width = 0.5,
        focus_fit_method = 1,
        follow_focus = false,
        fullscreen_on_one_column = true,
        direction = "right",
    },

    -- Binds
    binds = {
        scroll_event_delay = 0,
    },

    -- Cursor: Keeps mouse strictly centered inside the magnified viewport
    cursor = {
        zoom_rigid = true,
        zoom_detached_camera = false,
    },
})