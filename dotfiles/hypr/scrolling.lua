-- =============================================================================
-- scrolling.lua — Single Unified Engine for Continuous Scrolling Layout
-- Niri-style space-filling ribbon, zero-centering, and Dwindle resize parity.
-- Works uniformly across standard workspaces and special workspaces.
-- =============================================================================

local mainMod = "SUPER"
local is_syncing = false

-- 1. Compositor Layout & Gesture Configuration
hl.config({
    scrolling = {
        column_width = 0.5,
        focus_fit_method = 1,              -- 1 = Minimal scroll to edge; never forcibly centers focused column
        follow_focus = 0,                  -- 0 = Ribbon stays steady; does not scroll or jump on click or hover focus
        fullscreen_on_one_column = true,  -- Single window fills 100% monitor width
        direction = "right",
        wrap_focus = true,
        wrap_swapcol = true,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    },
    gestures = {
        workspace_swipe_forever = true,
        scrolling = {
            move_snap_to_grid = false,     -- Free kinetic scrolling; stops where gesture ends without forced column snap
            move_snap_cursor = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })

-- 2. Geometry & Workspace Helpers
local function get_left_margin()
    local home = os.getenv("HOME") or ""
    local f = io.open(home .. "/.config/hypr/settings.json", "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content:match('"topbarPosition"%s*:%s*"top"') then
            return 12
        end
    end
    -- Default is "left" topbar position (36px bar + 16px padding/gap = 52px)
    return 52
end

local function get_current_workspace_id()
    -- Check if any special workspace is currently active on any monitor FIRST
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.special_workspace and mon.special_workspace.id and mon.special_workspace.id ~= 0 then
            return mon.special_workspace.id
        end
    end
    local win = hl.get_active_window()
    if win and win.workspace and win.workspace.id then
        return win.workspace.id
    end
    local ws = hl.get_active_workspace()
    return ws and ws.id
end

local function get_tiled_windows_on_workspace(ws_id, exclude_addr)
    local list = {}
    if not ws_id then return list end
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.floating and w.workspace and w.workspace.id == ws_id then
            if not exclude_addr or w.address ~= exclude_addr then
                local w_w = (w.size and w.size.x) or 0
                local w_h = (w.size and w.size.y) or 0
                if w_w > 50 and w_h > 50 then
                    table.insert(list, w)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return ((a.at and a.at.x) or 0) < ((b.at and b.at.x) or 0)
    end)
    return list
end

local function is_any_window_fullscreen(ws_id)
    local target_ws = ws_id or get_current_workspace_id()
    if not target_ws then return false end
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.id == target_ws and w.fullscreen and w.fullscreen ~= 0 then
            return true
        end
    end
    return false
end

local function is_scrolling_layout(ws_id)
    local target_ws = ws_id or get_current_workspace_id()
    if target_ws then
        local ws = hl.get_workspace(target_ws)
        if ws and ws.tiled_layout and ws.tiled_layout ~= "" then
            return ws.tiled_layout == "scrolling"
        end
        for _, w in ipairs(hl.get_workspaces()) do
            if w.id == target_ws and w.tiled_layout and w.tiled_layout ~= "" then
                return w.tiled_layout == "scrolling"
            end
        end
    end
    local gen = hl.get_config("general:layout")
    return gen == "scrolling"
end

-- 3. Space-Filling Scaling & Boundary Normalization
-- Prevents windows from collapsing into slivers and prevents Hyprland from centering columns
local function sync_workspace_layout(ws_id, exclude_addr)
    if is_syncing then return end
    local target_ws_id = ws_id or get_current_workspace_id()
    if not target_ws_id or not is_scrolling_layout(target_ws_id) or is_any_window_fullscreen(target_ws_id) then return end

    local wins = get_tiled_windows_on_workspace(target_ws_id, exclude_addr)
    local count = #wins
    if count == 0 then return end

    local left_margin = get_left_margin()
    local first = wins[1]
    local cur_x = (first.at and first.at.x)

    is_syncing = true
    pcall(function()
        local active_win = hl.get_active_window()
        local active_ws = active_win and active_win.workspace and active_win.workspace.id

        if count == 1 then
            -- 1 window: spans 100% full usable screen, flush to left margin
            if active_ws == target_ws_id and active_win and active_win.address == first.address then
                hl.dispatch(hl.dsp.layout("colresize 1.0"))
            end
            if cur_x and cur_x ~= left_margin then
                hl.dispatch(hl.dsp.layout("move " .. tostring(left_margin - cur_x)))
            end
        elseif count == 2 then
            -- 2 windows: Dwindle parity, split sums to 100% of usable width ($52px to $1428px).
            -- Total width == screen width guarantees Hyprland NEVER centers columns.
            local w1 = wins[1]
            local w2 = wins[2]
            local w1_w = (w1.size and w1.size.x) or 683
            local w2_w = (w2.size and w2.size.x) or 683
            local total_usable = 1366 -- 1440 - 52 (left) - 12 (right) - 10 (gap)

            local active_addr = active_win and active_win.address
            local active_w = (active_addr == w2.address) and w2_w or w1_w
            local frac_active = active_w / total_usable
            if frac_active < 0.25 then frac_active = 0.25 end
            if frac_active > 0.75 then frac_active = 0.75 end

            local frac_w1, frac_w2
            if active_addr == w2.address then
                frac_w2 = frac_active
                frac_w1 = 1.0 - frac_w2
            else
                frac_w1 = frac_active
                frac_w2 = 1.0 - frac_w1
            end

            if active_ws == target_ws_id then
                hl.dispatch(hl.dsp.focus({ window = "address:" .. w1.address }))
                hl.dispatch(hl.dsp.layout(string.format("colresize %.02f", frac_w1)))
                hl.dispatch(hl.dsp.focus({ window = "address:" .. w2.address }))
                hl.dispatch(hl.dsp.layout(string.format("colresize %.02f", frac_w2)))
                if active_addr then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. active_addr }))
                end
            end
        else
            -- 3+ windows: enforce minimum column width (320px / 0.25) to prevent sliver collapse
            if active_ws == target_ws_id then
                for _, w in ipairs(wins) do
                    local ww = (w.size and w.size.x) or 0
                    if ww < 320 then
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
                        hl.dispatch(hl.dsp.layout("colresize 0.333"))
                    end
                end
                if active_addr then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. active_addr }))
                end
            end
        end
    end)
    is_syncing = false
end

-- 4. Dynamic Resizing (Keyboard & Mouse Wheel)
local function smart_resize(dx, dy)
    local ws_id = get_current_workspace_id()
    if not ws_id or is_any_window_fullscreen(ws_id) or (dy ~= 0 and dx == 0) then
        hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
        return
    end

    local active_win = hl.get_active_window()
    if not active_win or active_win.floating or (active_win.fullscreen and active_win.fullscreen ~= 0) then
        hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
        return
    end

    if not is_scrolling_layout(ws_id) then
        hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
        return
    end

    local wins = get_tiled_windows_on_workspace(ws_id)
    if #wins <= 1 then
        local delta_frac = (dx > 0) and 0.04 or -0.04
        pcall(function()
            hl.dispatch(hl.dsp.layout(string.format("colresize %+0.02f", delta_frac)))
        end)
        return
    end

    local active_idx = nil
    for i, w in ipairs(wins) do
        if w.address == active_win.address then
            active_idx = i
            break
        end
    end
    if not active_idx then return end

    local delta = (dx > 0) and 0.04 or -0.04
    local other = (active_idx == 1) and wins[2] or wins[active_idx - 1]
    if not other then return end

    local cur_self_w = (active_win.size and active_win.size.x) or 683
    local cur_other_w = (other.size and other.size.x) or 683
    if (delta < 0 and cur_self_w <= 320) or (delta > 0 and cur_other_w <= 320) then
        return
    end

    is_syncing = true
    pcall(function()
        hl.dispatch(hl.dsp.layout(string.format("colresize %+0.02f", delta)))
        hl.dispatch(hl.dsp.focus({ window = "address:" .. other.address }))
        hl.dispatch(hl.dsp.layout(string.format("colresize %+0.02f", -delta)))
        hl.dispatch(hl.dsp.focus({ window = "address:" .. active_win.address }))
    end)
    is_syncing = false

    local left_margin = get_left_margin()
    local updated_wins = get_tiled_windows_on_workspace(ws_id)
    if #updated_wins > 0 and updated_wins[1].at and updated_wins[1].at.x > (left_margin + 6) then
        pcall(function()
            hl.dispatch(hl.dsp.layout("move " .. tostring(left_margin - updated_wins[1].at.x)))
        end)
    end
end

-- 5. Bounded Ribbon Navigation (Mouse Wheel)
local function scroll_ribbon_left()
    local ws_id = get_current_workspace_id()
    if not ws_id or not is_scrolling_layout(ws_id) or is_any_window_fullscreen(ws_id) then return end
    local wins = get_tiled_windows_on_workspace(ws_id)
    if #wins <= 1 then return end

    local first_x = (wins[1].at and wins[1].at.x) or 0
    local left_margin = get_left_margin()

    -- Strict left boundary: leftmost window must NEVER exceed left_margin into void
    if first_x >= left_margin then
        if first_x > left_margin then
            pcall(function() hl.dispatch(hl.dsp.layout("move " .. tostring(left_margin - first_x))) end)
        end
        return
    end

    hl.dispatch(hl.dsp.layout("move -col"))
    pcall(function()
        local post_wins = get_tiled_windows_on_workspace(ws_id)
        if #post_wins > 0 and post_wins[1].at and post_wins[1].at.x > left_margin then
            hl.dispatch(hl.dsp.layout("move " .. tostring(left_margin - post_wins[1].at.x)))
        end
    end)
end

local function scroll_ribbon_right()
    local ws_id = get_current_workspace_id()
    if not ws_id or not is_scrolling_layout(ws_id) or is_any_window_fullscreen(ws_id) then return end
    local wins = get_tiled_windows_on_workspace(ws_id)
    if #wins <= 1 then return end

    local first_x = (wins[1].at and wins[1].at.x) or 0
    local last = wins[#wins]
    local last_right = ((last.at and last.at.x) or 0) + ((last.size and last.size.x) or 0)
    local left_margin = get_left_margin()
    local right_margin = 1440 - 12

    if first_x >= left_margin and last_right <= right_margin then
        if first_x > left_margin then
            pcall(function() hl.dispatch(hl.dsp.layout("move " .. tostring(left_margin - first_x))) end)
        end
        return
    end

    if last_right <= right_margin then
        if last_right < right_margin and #wins > 1 then
            pcall(function() hl.dispatch(hl.dsp.layout("move " .. tostring(right_margin - last_right))) end)
        end
        return
    end

    hl.dispatch(hl.dsp.layout("move +col"))
    pcall(function()
        local post_wins = get_tiled_windows_on_workspace(ws_id)
        if #post_wins > 0 then
            local u_last = post_wins[#post_wins]
            local u_right = ((u_last.at and u_last.at.x) or 0) + ((u_last.size and u_last.size.x) or 0)
            if u_right < right_margin and #post_wins > 1 then
                hl.dispatch(hl.dsp.layout("move " .. tostring(right_margin - u_right)))
            end
        end
    end)
end

-- 6. Keybindings Registration
-- Keyboard tandem resize
hl.bind(mainMod .. " + SHIFT + Right", function() smart_resize(30, 0) end, { repeating = true, description = "resize window right" })
hl.bind(mainMod .. " + SHIFT + Left", function() smart_resize(-30, 0) end, { repeating = true, description = "resize window left" })
hl.bind(mainMod .. " + SHIFT + Up", function() smart_resize(0, -30) end, { repeating = true, description = "resize window up" })
hl.bind(mainMod .. " + SHIFT + Down", function() smart_resize(0, 30) end, { repeating = true, description = "resize window down" })

-- Mouse wheel tandem resize
hl.bind(mainMod .. " + SHIFT + mouse_down", function() smart_resize(-30, 0) end, { description = "shrink window with mouse wheel" })
hl.bind(mainMod .. " + SHIFT + mouse_up", function() smart_resize(30, 0) end, { description = "expand window with mouse wheel" })

-- Mouse drag window resize & release normalization
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true, description = "hold to resize window" })
hl.bind(mainMod .. " + X", function() sync_workspace_layout() end, { release = true, description = "normalize layout on resize release" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "resize window with mouse" })
hl.bind(mainMod .. " + mouse:273", function() sync_workspace_layout() end, { release = true, description = "normalize layout on resize release" })

-- Mouse wheel ribbon scrolling
hl.bind(mainMod .. " + ALT + mouse_down", scroll_ribbon_right, { description = "scroll ribbon right with mouse wheel" })
hl.bind(mainMod .. " + ALT + mouse_up", scroll_ribbon_left, { description = "scroll ribbon left with mouse wheel" })

-- 7. Fullscreen Inhibit & Lifecycle Events
local is_gesture_disabled = false

local function sync_fullscreen_inhibit(target_win)
    local ws_id = get_current_workspace_id()
    if not ws_id or not is_scrolling_layout(ws_id) then
        if is_gesture_disabled then
            pcall(function()
                hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
            end)
            is_gesture_disabled = false
        end
        return
    end

    local win = hl.get_active_window()
    local is_fs = (win and win.fullscreen and win.fullscreen ~= 0)

    if not is_fs and target_win and type(target_win) == "userdata" and target_win.fullscreen and target_win.fullscreen ~= 0 then
        is_fs = true
    end

    if not is_fs then
        if is_any_window_fullscreen(ws_id) then
            is_fs = true
        end
    end

    pcall(function()
        hl.dispatch(hl.dsp.layout(is_fs and "inhibit_scroll true" or "inhibit_scroll false"))
    end)

    if is_fs then
        if not is_gesture_disabled then
            pcall(function()
                hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
            end)
            is_gesture_disabled = true
        end
    else
        if is_gesture_disabled then
            pcall(function()
                hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
            end)
            is_gesture_disabled = false
        end
    end
end

hl.on("window.open", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    sync_fullscreen_inhibit(w)
    sync_workspace_layout(ws_id)
end)

hl.on("window.close", function(w)
    local ws_id = (w and w.workspace and w.workspace.id)
    local addr = (w and w.address)
    sync_fullscreen_inhibit()
    sync_workspace_layout(ws_id, addr)
end)

hl.on("window.destroy", function()
    sync_fullscreen_inhibit()
    sync_workspace_layout()
end)

hl.on("workspace.active", function()
    sync_fullscreen_inhibit()
end)

hl.on("workspace.special_active", function()
    sync_fullscreen_inhibit()
end)

hl.on("window.fullscreen", function(w)
    sync_fullscreen_inhibit(w)
    sync_workspace_layout()
end)

hl.on("window.active", function(w)
    sync_fullscreen_inhibit(w)
end)

-- Initial state sync on load (guarded to prevent no-monitor layout dispatch on cold boot)
if #hl.get_monitors() > 0 then
    pcall(sync_fullscreen_inhibit)
    pcall(sync_workspace_layout)
end
