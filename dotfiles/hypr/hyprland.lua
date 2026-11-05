-- Entry point. Mirrors the modular split of the old hyprlang config.
require("env")
require("startup")
require("keybinds")
require("rules")
require("input")
require("appearance")
require("misc")
require("scrolling")

-- 1. Universal catch-all rule: any unknown monitor works with zero config
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- 2. Declarative per-host monitor overrides (deployed by Nix if present)
pcall(function()
    local cfg_dir = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    dofile(cfg_dir .. "/hypr-local/monitors.lua")
end)

-- 3. Dynamic layout intent manager (persisted in $DESKTOP_STATE_DIR/monitors/intent.json)
local connected_monitors = {}
local known_internal_name = "eDP-1"

function is_internal_monitor(name)
    if not name then return false end
    local prefixes = {"eDP", "LVDS", "DSI", "MIPI"}
    for _, prefix in ipairs(prefixes) do
        if name:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function is_real_external(name)
    if not name or #name == 0 then return false end
    if is_internal_monitor(name) then return false end
    if name == "FALLBACK" or name == "NOOP" or name:find("^HEADLESS%-") or name:find("^WAYLAND%-") then return false end
    return true
end

local function sync_connected_monitors(intent_data)
    local mons = hl.get_monitors()
    for _, m in ipairs(mons) do
        connected_monitors[m.name] = {
            name = m.name,
            description = m.description or "",
            width = m.width,
            height = m.height,
            scale = m.scale
        }
        if is_internal_monitor(m.name) then
            known_internal_name = m.name
        end
        if m.mirrors then
            for _, mirr in ipairs(m.mirrors) do
                connected_monitors[mirr.name] = {
                    name = mirr.name,
                    description = mirr.description or "",
                    width = mirr.width,
                    height = mirr.height,
                    scale = mirr.scale
                }
            end
        end
    end

    if intent_data and intent_data.raw then
        for name in intent_data.raw:gmatch('"name"%s*:%s*"([^"]+)"') do
            if not connected_monitors[name] then
                connected_monitors[name] = {
                    name = name,
                    description = "",
                    width = 1920,
                    height = 1080,
                    scale = 1
                }
            end
        end
    end
end

local function get_display_intent(raw, desc, name)
    if not raw then return nil end
    local block = nil
    if desc and #desc > 0 then
        local safe_desc = desc:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        block = raw:match('"desc:' .. safe_desc .. '"%s*:%s*{([^}]+)}')
             or raw:match('"' .. safe_desc .. '"%s*:%s*{([^}]+)}')
    end
    if not block and name and #name > 0 then
        local safe_name = name:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        block = raw:match('"' .. safe_name .. '"%s*:%s*{([^}]+)}')
    end
    if not block then return nil end

    local scale = block:match('"scale"%s*:%s*([0-9.]+)')
    local mode = block:match('"mode"%s*:%s*"([^"]+)"')
    local transform = block:match('"transform"%s*:%s*([0-9]+)')
    local placement = block:match('"placement"%s*:%s*"([^"]+)"')
    return {
        scale = scale and tonumber(scale) or nil,
        mode = mode,
        transform = transform and tonumber(transform) or nil,
        placement = placement
    }
end

function get_monitor_intent()
    local desktop_state = os.getenv("DESKTOP_STATE_DIR") or ((os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/desktop")
    local intent_file = desktop_state .. "/monitors/intent.json"
    local f = io.open(intent_file, "r")
    if not f then return { layout = "extend", raw = "" } end
    local content = f:read("*a")
    f:close()
    if not content or #content == 0 then return { layout = "extend", raw = "" } end
    local layout = content:match('"layout"%s*:%s*"([^"]+)"') or "extend"
    return { layout = layout, raw = content }
end

function apply_layout(explicit_intent)
    local intent_data = get_monitor_intent()
    sync_connected_monitors(intent_data)
    local intent = explicit_intent or intent_data.layout

    local external_count = 0
    for name, _ in pairs(connected_monitors) do
        if is_real_external(name) then
            external_count = external_count + 1
        end
    end

    -- Safety rule: if no external monitors are present, internal panel MUST be active!
    if external_count == 0 then
        hl.monitor({ output = known_internal_name, disabled = false, position = "0x0" })
        return
    end

    local internal = connected_monitors[known_internal_name]
    if not internal then
        internal = { name = known_internal_name, width = 2880, height = 1620, scale = 2 }
    end

    local internal_cfg = get_display_intent(intent_data.raw, internal.description, internal.name)
    local internal_pos = (internal_cfg and internal_cfg.placement and internal_cfg.placement ~= "auto") and internal_cfg.placement or "0x0"

    if intent == "mirror" then
        hl.monitor({ output = internal.name, disabled = false, position = internal_pos })
        for name, m in pairs(connected_monitors) do
            if is_real_external(name) then
                hl.monitor({ output = name, mirror = internal.name })
            end
        end
    elseif intent == "internal" then
        hl.monitor({ output = internal.name, disabled = false, position = internal_pos })
        for name, m in pairs(connected_monitors) do
            if is_real_external(name) then
                hl.monitor({ output = name, disabled = true })
            end
        end
    elseif intent == "external" then
        if external_count == 0 then
            hl.monitor({ output = internal.name, disabled = false, position = internal_pos })
        else
            for name, m in pairs(connected_monitors) do
                if is_real_external(name) then
                    local disp_cfg = get_display_intent(intent_data.raw, m.description, name)
                    local scale_val = disp_cfg and disp_cfg.scale or (m.scale or "auto")
                    local mode_val = disp_cfg and disp_cfg.mode or "preferred"
                    local mon_opts = { output = name, mode = mode_val, position = "0x0", scale = scale_val, mirror = "", disabled = false }
                    if disp_cfg and disp_cfg.transform then
                        mon_opts.transform = disp_cfg.transform
                    end
                    hl.monitor(mon_opts)
                end
            end
            hl.monitor({ output = internal.name, disabled = true })
        end
    else
        -- Extend mode: internal panel is placed at internal_pos. External placed beside internal panel.
        hl.monitor({ output = internal.name, disabled = false, position = internal_pos })
        local internal_logical_w = math.floor((internal.width or 2880) / (internal.scale or 2) + 0.5)
        for name, m in pairs(connected_monitors) do
            if is_real_external(name) then
                local disp_cfg = get_display_intent(intent_data.raw, m.description, name)
                local scale_val = disp_cfg and disp_cfg.scale or (m.scale or "auto")
                local mode_val = disp_cfg and disp_cfg.mode or "preferred"
                local pos_val = (disp_cfg and disp_cfg.placement and disp_cfg.placement ~= "auto") and disp_cfg.placement or string.format("%dx0", internal_logical_w)
                local mon_opts = { output = name, mode = mode_val, position = pos_val, scale = scale_val, mirror = "", disabled = false }
                if disp_cfg and disp_cfg.transform then
                    mon_opts.transform = disp_cfg.transform
                end
                hl.monitor(mon_opts)
                for ws = 11, 20 do
                    hl.workspace_rule({ workspace = tostring(ws), monitor = name })
                end
            end
        end
    end
end

-- Bind primary workspaces 1-10 to the internal panel
for ws = 1, 10 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = known_internal_name })
end

-- Apply on startup
apply_layout()

-- Re-run logic synchronously on monitor hotplug events
hl.on("monitor.added", function(m)
    if m and m.name then
        connected_monitors[m.name] = {
            name = m.name,
            description = m.description or "",
            width = m.width,
            height = m.height,
            scale = m.scale
        }
        apply_layout()
        local state_dir = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
        local video_env = state_dir .. "/mpvpaper/" .. m.name .. ".env"
        local f = io.open(video_env, "r")
        if f then
            f:close()
            hl.exec_cmd("systemctl --user restart mpvpaper@" .. m.name)
        else
            hl.exec_cmd("awww restore --outputs " .. m.name)
        end
    else
        apply_layout()
        hl.exec_cmd("awww restore")
    end
end)

hl.on("monitor.removed", function(m)
    if m and m.name then
        connected_monitors[m.name] = nil
    end
    local external_count = 0
    for name, _ in pairs(connected_monitors) do
        if is_real_external(name) then
            external_count = external_count + 1
        end
    end
    if external_count == 0 then
        hl.monitor({ output = known_internal_name, disabled = false, position = "0x0" })
        for ws = 11, 20 do
            pcall(function()
                hl.dispatch(hl.dsp.workspace.move_to_monitor({ workspace = ws, monitor = known_internal_name }))
            end)
        end
    end
    apply_layout()
end)

hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})
