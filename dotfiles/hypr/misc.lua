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
        fullscreen_on_one_column = true,
        direction = "right",
        wrap_focus = true,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
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

-- Dynamic natural window scaling for scrolling layout:
-- 1 window:  100% full scale (usable monitor width).
-- 2 windows: 50% each side-by-side.
-- 3 windows: 33.3% each side-by-side on single screen.
-- 4+ windows: open along the continuous scrolling ribbon at 33.3%.
-- Closing windows scales remaining windows back up (3 -> 2 -> 1).
-- Left boundary is pinned to the monitor margin (no empty void on the left).
local function get_screen_dimensions()
    local mons = hl.get_monitors()
    local m = mons and mons[1]
    local width = 1440
    local height = 810
    if m and m.width and m.scale and m.scale > 0 then
        width = math.floor(m.width / m.scale)
        height = math.floor(m.height / m.scale)
    end
    local usable_w = width - 64
    local usable_h = height - 24
    local half_w = math.floor((usable_w - 10) / 2)
    local third_w = math.floor((usable_w - 20) / 3)
    return usable_w, half_w, third_w, usable_h
end

local function get_tiled_windows_on_workspace(ws_id)
    local list = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.floating and w.workspace and w.workspace.id == ws_id then
            table.insert(list, w)
        end
    end
    table.sort(list, function(a, b)
        local ax = (a.at and a.at.x) or 0
        local bx = (b.at and b.at.x) or 0
        return ax < bx
    end)
    return list
end

local function resize_if_needed(win, target_w, default_h)
    if not win or not win.address then return end
    if win.fullscreen and win.fullscreen ~= 0 then return end
    local cur_w = (win.size and win.size.x) or 0
    if math.abs(cur_w - target_w) > 4 then
        local h = (win.size and win.size.y) or default_h
        hl.dispatch(hl.dsp.window.resize({ window = "address:" .. win.address, x = target_w, y = h, exact = true }))
    end
end

local function align_leftmost_column(wins, target_margin)
    if not wins or #wins == 0 then return end
    local first = wins[1]
    local cur_x = (first.at and first.at.x)
    if not cur_x then return end
    local delta = cur_x - target_margin
    if math.abs(delta) > 4 then
        local shift = -delta
        pcall(function()
            hl.dispatch(hl.dsp.layout("move " .. tostring(shift)))
        end)
    end
end

local function sync_window_scale(ws_id)
    local active_ws = hl.get_active_workspace()
    local active_ws_id = active_ws and active_ws.id
    local target_ws_id = ws_id or active_ws_id
    if not target_ws_id then return end

    if active_ws and active_ws.tiled_layout ~= "scrolling" then
        return
    end

    local wins = get_tiled_windows_on_workspace(target_ws_id)
    local count = #wins
    local full_w, half_w, third_w, full_h = get_screen_dimensions()
    local is_active_ws = (active_ws_id == target_ws_id)

    if count <= 1 then
        if count == 1 and wins[1] then
            resize_if_needed(wins[1], full_w, full_h)
        end
        hl.config({ scrolling = { column_width = 0.5 } })
        if is_active_ws then
            align_leftmost_column(wins, 52)
        end
    elseif count == 2 then
        for _, w in ipairs(wins) do
            resize_if_needed(w, half_w, full_h)
        end
        hl.config({ scrolling = { column_width = 0.333333 } })
        if is_active_ws then
            align_leftmost_column(wins, 52)
        end
    elseif count == 3 then
        for _, w in ipairs(wins) do
            resize_if_needed(w, third_w, full_h)
        end
        hl.config({ scrolling = { column_width = 0.333333 } })
        if is_active_ws then
            align_leftmost_column(wins, 52)
        end
    else
        -- 4+ windows: open along the continuous scrolling ribbon at 33.3%
        hl.config({ scrolling = { column_width = 0.333333 } })
        for _, w in ipairs(wins) do
            resize_if_needed(w, third_w, full_h)
        end
    end
end

-- Fullscreen scroll inhibitor: isolates fullscreen games/videos from ribbon gestures
local function sync_fullscreen_inhibit()
    local ws = hl.get_active_workspace()
    if not ws or ws.tiled_layout ~= "scrolling" then return end
    local active_win = hl.get_active_window()
    local is_fs = active_win and active_win.fullscreen and active_win.fullscreen ~= 0
    pcall(function()
        if is_fs then
            hl.dispatch(hl.dsp.layout("inhibit_scroll true"))
        else
            hl.dispatch(hl.dsp.layout("inhibit_scroll false"))
        end
    end)
end

hl.on("window.open", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    sync_window_scale(ws_id)
end)

hl.on("window.close", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    sync_window_scale(ws_id)
end)

hl.on("workspace.active", function()
    sync_window_scale()
    sync_fullscreen_inhibit()
end)

hl.on("window.fullscreen", function()
    sync_fullscreen_inhibit()
end)

hl.on("window.active", function()
    sync_fullscreen_inhibit()
end)

sync_window_scale()
sync_fullscreen_inhibit()