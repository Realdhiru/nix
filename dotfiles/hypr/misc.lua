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
        explicit_column_widths = "0.5, 0.667, 1.0, 0.333",
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
-- 1 window:  100% full scale (usable monitor width, flush on margin).
-- 2 windows: 50% each side-by-side (fills screen cleanly).
-- 3+ windows: 50% each along the continuous scrolling ribbon.
-- Closing windows scales remaining windows back up (3+ -> 2 -> 1) via native 'fit all'.
-- Left boundary is pinned to the monitor margin (no empty void on the left).
local function get_tiled_windows_on_workspace(ws_id, exclude_addr)
    local list = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.floating and w.workspace and w.workspace.id == ws_id then
            if not exclude_addr or w.address ~= exclude_addr then
                local w_w = (w.size and w.size.x) or 0
                local w_h = (w.size and w.size.y) or 0
                -- Exclude ghost/minimized surfaces
                if w_w > 50 and w_h > 50 then
                    table.insert(list, w)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local ax = (a.at and a.at.x) or 0
        local bx = (b.at and b.at.x) or 0
        return ax < bx
    end)
    return list
end

local function sync_window_scale(ws_id, exclude_addr)
    local active_ws = hl.get_active_workspace()
    local active_ws_id = active_ws and active_ws.id
    local target_ws_id = ws_id or active_ws_id
    if not target_ws_id then return end

    if active_ws and active_ws.tiled_layout ~= "scrolling" then
        return
    end

    local wins = get_tiled_windows_on_workspace(target_ws_id, exclude_addr)
    local count = #wins
    local is_active_ws = (active_ws_id == target_ws_id)

    if count <= 1 then
        hl.config({ scrolling = { column_width = 0.5 } })
        if is_active_ws and count == 1 then
            pcall(function()
                hl.dispatch(hl.dsp.layout("fit all"))
            end)
        end
    elseif count == 2 then
        -- Only fit if the 2 windows do not already span the usable screen
        -- (e.g. freshly opened second window). If custom ratio is set, preserve it.
        local w1 = wins[1]
        local w2 = wins[2]
        local w1_w = (w1 and w1.size and w1.size.x) or 0
        local w2_w = (w2 and w2.size and w2.size.x) or 0
        local sum_w = w1_w + w2_w + 10
        if is_active_ws and math.abs(sum_w - 1376) > 40 then
            pcall(function()
                hl.dispatch(hl.dsp.layout("fit all"))
            end)
        end
    else
        -- 3+ windows: 50% columns along continuous scrolling ribbon
        hl.config({ scrolling = { column_width = 0.5 } })
    end
end

-- Strictly clamps ribbon margins on window lifecycle/workspace switch:
-- Ensures leftmost window never drifts past the screen margin (x > 12) into void,
-- while preserving free scroll framing across the ribbon during normal window interaction.
local function clamp_ribbon_margins(ws_id)
    local active_ws = hl.get_active_workspace()
    local target_ws_id = ws_id or (active_ws and active_ws.id)
    if not target_ws_id then return end
    if active_ws and active_ws.tiled_layout ~= "scrolling" then return end

    local wins = get_tiled_windows_on_workspace(target_ws_id)
    if #wins == 0 then return end

    local first = wins[1]
    local cur_x = (first.at and first.at.x)

    -- Left margin clamp: leftmost window must NEVER exceed x = 12 (gaps_out)
    if cur_x and cur_x > 12 then
        local delta = cur_x - 12
        pcall(function()
            hl.dispatch(hl.dsp.layout("move " .. tostring(-delta)))
        end)
        return
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
    clamp_ribbon_margins(ws_id)
end)

hl.on("window.close", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    local addr = (w and w.address)
    sync_window_scale(ws_id, addr)
    clamp_ribbon_margins(ws_id)
end)

hl.on("window.destroy", function()
    sync_window_scale()
    clamp_ribbon_margins()
end)

hl.on("workspace.active", function()
    sync_window_scale()
    sync_fullscreen_inhibit()
    clamp_ribbon_margins()
end)

hl.on("window.fullscreen", function()
    sync_fullscreen_inhibit()
end)

hl.on("window.active", function()
    sync_fullscreen_inhibit()
    -- NOTE: Never call clamp_ribbon_margins() on window.active!
    -- Doing so interrupts free scroll framing and forcibly jerks the ribbon away
    -- from the user's preferred scroll location whenever any window receives focus.
end)

sync_window_scale()
sync_fullscreen_inhibit()
clamp_ribbon_margins()