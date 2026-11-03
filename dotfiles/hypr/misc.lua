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
        follow_focus = true,
        fullscreen_on_one_column = false,
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

-- Inhibit ribbon scrolling whenever a fullscreen window is active to prevent forced scrolling blinking,
-- while automatically re-enabling normal scrolling as soon as focus leaves the fullscreen window.
local function sync_fullscreen_scroll_inhibit(win)
    local w = win or hl.get_active_window()
    local is_fs = w and w.fullscreen and w.fullscreen ~= 0
    if is_fs then
        hl.dispatch(hl.dsp.layout("inhibit_scroll true"))
    else
        hl.dispatch(hl.dsp.layout("inhibit_scroll false"))
    end
end

hl.on("window.fullscreen", function(win)
    sync_fullscreen_scroll_inhibit(win)
end)

hl.on("window.active", function(win)
    sync_fullscreen_scroll_inhibit(win)
end)

hl.on("workspace.active", function()
    sync_fullscreen_scroll_inhibit()
end)