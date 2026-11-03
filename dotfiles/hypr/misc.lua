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

-- Responsive dynamic column sizing for scrolling layout:
-- 1. Single window on workspace expands to cover the entire usable screen (100% width).
-- 2. Two windows dynamically share the screen side-by-side (50% each), filling available space without ribbon overflow.
-- 3. Three windows fit on one screen side-by-side (33.3% each), sized safely without component or text clipping.
-- 4. Four or more windows scroll smoothly along the continuous tape at 33.3% width.
-- 5. Windows dynamically expand when other windows close.
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
    return list
end

local function sync_dynamic_column_width(ws_id)
    if not ws_id then
        local ws = hl.get_active_workspace()
        ws_id = ws and ws.id
    end
    if not ws_id then return end

    local wins = get_tiled_windows_on_workspace(ws_id)
    local count = #wins
    local full_w, half_w, third_w, full_h = get_screen_dimensions()

    if count <= 1 then
        hl.config({ scrolling = { column_width = 1.0 } })
        if count == 1 and wins[1] and wins[1].address and (wins[1].fullscreen == 0 or not wins[1].fullscreen) then
            local h = (wins[1].size and wins[1].size[2]) or full_h
            hl.dispatch(hl.dsp.window.resize({ window = "address:" .. wins[1].address, x = full_w, y = h, exact = true }))
        end
    elseif count == 2 then
        hl.config({ scrolling = { column_width = 0.5 } })
        for _, w in ipairs(wins) do
            if w.address and (w.fullscreen == 0 or not w.fullscreen) then
                local h = (w.size and w.size[2]) or full_h
                hl.dispatch(hl.dsp.window.resize({ window = "address:" .. w.address, x = half_w, y = h, exact = true }))
            end
        end
    elseif count == 3 then
        hl.config({ scrolling = { column_width = 0.333333 } })
        for _, w in ipairs(wins) do
            if w.address and (w.fullscreen == 0 or not w.fullscreen) then
                local h = (w.size and w.size[2]) or full_h
                hl.dispatch(hl.dsp.window.resize({ window = "address:" .. w.address, x = third_w, y = h, exact = true }))
            end
        end
    else
        -- 4 or more windows retain 33.3% columns along the continuous tape without crushing components
        hl.config({ scrolling = { column_width = 0.333333 } })
    end
end

hl.on("window.fullscreen", function(win)
    sync_fullscreen_scroll_inhibit(win)
    sync_dynamic_column_width()
end)

hl.on("window.active", function(win)
    sync_fullscreen_scroll_inhibit(win)
end)

hl.on("workspace.active", function()
    sync_fullscreen_scroll_inhibit()
    sync_dynamic_column_width()
end)

hl.on("window.open", function(w)
    local ws_id = (w and w.workspace and w.workspace.id) or (hl.get_active_workspace() and hl.get_active_workspace().id)
    sync_dynamic_column_width(ws_id)
end)

hl.on("window.close", function(w)
    local ws_id = (w and w.workspace and w.workspace.id) or (hl.get_active_workspace() and hl.get_active_workspace().id)
    sync_dynamic_column_width(ws_id)
end)

sync_dynamic_column_width()