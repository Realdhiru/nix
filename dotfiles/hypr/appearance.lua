local home = os.getenv("HOME") or ""
local desktop_state = os.getenv("DESKTOP_STATE_DIR") or ((os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/desktop")
local layout_file = desktop_state .. "/layout/current_layout.txt"

local current_layout = "dwindle"
local lf = io.open(layout_file, "r")
if lf then
    local val = lf:read("*l")
    lf:close()
    if val and (val == "scrolling" or val == "dwindle") then
        current_layout = val
    end
end

local blur_enabled = true
local shadow_enabled = true
local anim_enabled = true
local allow_tearing = false
local direct_scanout = 0

local modes_file = desktop_state .. "/modes/modes.json"
local mf = io.open(modes_file, "r")
if mf then
    local content = mf:read("*a")
    mf:close()
    if content then
        if content:match('"blur"%s*:%s*false') then blur_enabled = false end
        if content:match('"shadow"%s*:%s*false') then shadow_enabled = false end
        if content:match('"animations"%s*:%s*false') then anim_enabled = false end
        if content:match('"tearing"%s*:%s*1') then allow_tearing = true end
        local ds = content:match('"direct_scanout"%s*:%s*([0-9]+)')
        if ds then direct_scanout = tonumber(ds) end
    end
end

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 12,

        border_size = 0,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        allow_tearing = allow_tearing,

        layout = current_layout,
    },

    render = {
        direct_scanout = direct_scanout,
    },

    decoration = {
        rounding       = 12,
        rounding_power = 3,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = shadow_enabled,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1a44)",
        },

        blur = {
            enabled  = blur_enabled,
            size     = 8,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = anim_enabled,
    },
})

-- Animation curves
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("md3_accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("crazyshot", { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })
hl.curve("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("easeOutQuart", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("softAcDecel", { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1 } } })
hl.curve("md2", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } }) -- use with .2s duration

-- Animation configs
hl.animation({ leaf = "windows", enabled = true, speed = 2.8, bezier = "menu_decel", style = "popin 80%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.8, bezier = "menu_decel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "menu_accel", style = "popin 85%" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.5, bezier = "easeOutQuart" })
-- hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.5, bezier = "menu_decel" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.8, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2.5, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "menu_decel", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "menu_decel", style = "slidefadevert 15%" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "menu_decel" })