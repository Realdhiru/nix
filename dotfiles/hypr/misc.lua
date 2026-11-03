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
        column_width = 1.0,
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

-- Unified scroll inhibition and responsive dynamic column sizing:
-- 1. When windows count <= 3 on the workspace, or when a fullscreen window is active:
--    scroll is inhibited (`inhibit_scroll true`) so the screen never scrolls or jumps off to the right.
--    The tape is pinned to the left edge (`move -99999`) ensuring all windows fit side-by-side on screen.
-- 2. Single window expands to 100% usable screen width.
-- 3. Two windows dynamically split the screen side-by-side (50% each).
-- 4. Three windows dynamically split the screen side-by-side (33.3% each) without UI/text clipping.
-- 5. Next-spawn column_width is pre-configured so new windows never overflow or force-scroll on creation.
-- 6. Four or more windows unlock smooth continuous ribbon scrolling (`inhibit_scroll false`).
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
        local ax = (a.at and a.at[1]) or 0
        local bx = (b.at and b.at[1]) or 0
        return ax < bx
    end)
    return list
end

local function resize_if_needed(win, target_w, default_h)
    if not win or not win.address then return end
    if win.fullscreen and win.fullscreen ~= 0 then return end
    local cur_w = (win.size and win.size[1]) or 0
    if math.abs(cur_w - target_w) > 2 then
        local h = (win.size and win.size[2]) or default_h
        hl.dispatch(hl.dsp.window.resize({ window = "address:" .. win.address, x = target_w, y = h, exact = true }))
    end
end

local function dispatch_scrolling_layout(cmd)
    local cur = hl.get_option("general:layout")
    local layout_name = (cur and cur.str) or ""
    if layout_name == "scrolling" then
        pcall(function()
            hl.dispatch(hl.dsp.layout(cmd))
        end)
    end
end

local function sync_scrolling_state(ws_id, force_reset_tape)
    local active_ws = hl.get_active_workspace()
    local active_ws_id = active_ws and active_ws.id
    local target_ws_id = ws_id or active_ws_id
    if not target_ws_id then return end

    local is_active_ws = (active_ws_id == target_ws_id)
    local wins = get_tiled_windows_on_workspace(target_ws_id)
    local count = #wins
    local full_w, half_w, third_w, full_h = get_screen_dimensions()

    local active_win = hl.get_active_window()
    local is_fs = active_win and active_win.fullscreen and active_win.fullscreen ~= 0

    if count == 0 then
        hl.config({ scrolling = { column_width = 1.0 } })
    elseif count == 1 then
        resize_if_needed(wins[1], full_w, full_h)
        hl.config({ scrolling = { column_width = 0.5 } })
    elseif count == 2 then
        for _, w in ipairs(wins) do
            resize_if_needed(w, half_w, full_h)
        end
        hl.config({ scrolling = { column_width = 0.333333 } })
    elseif count == 3 then
        for _, w in ipairs(wins) do
            resize_if_needed(w, third_w, full_h)
        end
        hl.config({ scrolling = { column_width = 0.333333 } })
    else
        hl.config({ scrolling = { column_width = 0.333333 } })
    end

    if is_active_ws then
        if count <= 3 and force_reset_tape then
            dispatch_scrolling_layout("move -99999")
        end

        if is_fs then
            dispatch_scrolling_layout("inhibit_scroll true")
        else
            dispatch_scrolling_layout("inhibit_scroll false")
        end
    end
end

hl.on("window.fullscreen", function(win)
    sync_scrolling_state(nil, false)
end)

hl.on("window.active", function(win)
    sync_scrolling_state()
end)

hl.on("workspace.active", function()
    sync_scrolling_state(nil, false)
end)

hl.on("window.open", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    sync_scrolling_state(ws_id, true)
end)

hl.on("window.close", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    sync_scrolling_state(ws_id, true)
end)

sync_scrolling_state(nil, false)