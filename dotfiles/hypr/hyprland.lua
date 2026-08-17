-- Entry point. Mirrors the modular split of the old hyprlang config.
require("env")
require("startup")
require("keybinds")
require("rules")
require("input")
require("appearance")
require("layout")
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
    hl.monitor(mon)
end
apply_power_monitor()

-- 1b. Persisted screen shader selection. Unlike a bare hyprctl keyword,
-- the value survives every reload — including reloads triggered indirectly
-- by hypr_power_monitor.conf changing. Writer: cycle-shader.sh only.
-- Format: decoration:screen_shader = /path (or empty to disable)
local function apply_shader()
    local f = io.open(os.getenv("HOME") .. "/.cache/current_shader.conf", "r")
    if not f then
        return
    end
    local content = f:read("*a")
    f:close()
    local path = content:match("decoration:screen_shader%s*=%s*([^\n\r]+)")
    if path then
        -- legacy (hyprlang) wrote [[EMPTY]] to mean "no shader"; map to empty string
        local shader = path:gsub("%s+$", ""):gsub("^%[%[EMPTY%]%]$", "")
        hl.config({ decoration = { screen_shader = shader } })
    end
end
apply_shader()

-- 2. Universal fallback for ALL external monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, bitdepth = 10 })