-- Entry point. Mirrors the modular split of the old hyprlang config.
require("env")
require("startup")
require("keybinds")
require("rules")
require("input")
require("appearance")
require("misc")

-- 1. Universal catch-all rule: any unknown monitor works with zero config
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- 2. Declarative per-host monitor overrides (deployed by Nix if present)
pcall(function()
    local cfg_dir = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    dofile(cfg_dir .. "/hypr-local/monitors.lua")
end)

-- 3. Dynamic layout intent manager (persisted in $XDG_STATE_HOME/hypr/layout.lua)
function is_internal_monitor(name)
    if not name then return false end
    for _, prefix in ipairs({"eDP", "LVDS", "DSI"}) do
        if name:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function get_layout_intent()
    local state_dir = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local layout_file = state_dir .. "/hypr/layout.lua"
    local f = io.open(layout_file, "r")
    if not f then return "extend" end
    local content = f:read("*a")
    f:close()
    if not content then return "extend" end
    local intent = content:match('["\'](%w+)["\']')
    if intent == "mirror" then return "mirror" end
    return "extend"
end

function apply_layout(explicit_intent)
    local intent = explicit_intent or get_layout_intent()
    local mons = hl.get_monitors()
    if #mons <= 1 then
        return
    end

    if intent == "mirror" then
        local source = nil
        for _, m in ipairs(mons) do
            if is_internal_monitor(m.name) then
                source = m
                break
            end
        end
        if not source then
            -- Desktop system with only external displays: do nothing (remains extended)
            return
        end

        for _, m in ipairs(mons) do
            if m.name ~= source.name then
                hl.monitor({ output = m.name, mirror = source.name })
            end
        end
    else
        -- Extend mode: re-apply preferred auto positioning to clear mirroring
        for _, m in ipairs(mons) do
            if not is_internal_monitor(m.name) then
                hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = "auto", mirror = "" })
            end
        end
    end
end

-- Apply on startup
apply_layout()

-- Re-run logic synchronously on monitor hotplug events
hl.on("monitor.added", function(m)
    apply_layout()
    if m and m.name then
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
        hl.exec_cmd("awww restore")
    end
end)

hl.on("monitor.removed", function(_)
    apply_layout()
end)

hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})
