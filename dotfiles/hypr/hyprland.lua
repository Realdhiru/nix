-- Entry point. Mirrors the modular split of the old hyprlang config.
require("env")
require("startup")
require("keybinds")
require("rules")
require("input")
require("appearance")
require("misc")

-- 1. Dynamically generated internal monitor power state (bypasses DRM modeset)
-- Parse the hyprlang-format cache line:
--   monitor=<OUTPUT>,<MODE>,<POS>,<SCALE>,bitdepth,<B>,transform,<T>
-- Kept in sync with the writers (rotate_display.sh, BatteryPopup.qml).
local function apply_power_monitor()
    local f = io.open(os.getenv("HOME") .. "/.cache/hypr_power_monitor.conf", "r")
    if not f then
        return
    end
    local line = f:read("*l")
    f:close()
    if not line then
        return
    end
    -- Strip the 'monitor=' prefix if it exists
    if line:sub(1, 8) == "monitor=" then
        line = line:sub(9)
    end
    -- Split on commas; unknown trailing key/value pairs are ignored.
    local fields = {}
    for field in line:gmatch("[^,]+") do
        fields[#fields + 1] = field
    end
    if #fields < 4 then
        return
    end
    local mon = {
        output   = fields[1],
        mode     = fields[2],
        position = fields[3],
        scale    = tonumber(fields[4]) or fields[4],
    }
    local i = 5
    while i < #fields do
        if fields[i] == "bitdepth" then
            mon.bitdepth = tonumber(fields[i + 1])
        elseif fields[i] == "transform" then
            mon.transform = tonumber(fields[i + 1])
        elseif fields[i] == "cm" then
            mon.cm = fields[i + 1]
        end
        i = i + 2
    end
    if mon.transform == nil then
        local sf = io.open(os.getenv("HOME") .. "/.config/hypr/settings.json", "r")
        if sf then
            local content = sf:read("*a")
            sf:close()
            if content then
                local tf = content:match('"transform"%s*:%s*(%d+)')
                if tf and tonumber(tf) ~= 0 then
                    mon.transform = tonumber(tf)
                end
            end
        end
    end
    mon.transform = mon.transform or 0
    hl.monitor(mon)
end
apply_power_monitor()


-- 2. Universal fallback for ALL external monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, bitdepth = 10 })
hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})
