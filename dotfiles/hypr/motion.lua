-- Unified motion system. GENERATED from motion-tokens.nix - edit the tokens, not this file.
hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("enter", { type = "bezier", points = { { 0.160000, 1 }, { 0.300000, 1 } } })
hl.curve("exit_curve", { type = "bezier", points = { { 0.400000, 0 }, { 1, 1 } } })
hl.curve("move", { type = "bezier", points = { { 0.220000, 1 }, { 0.360000, 1 } } })
hl.curve("fade", { type = "bezier", points = { { 0.250000, 0.100000 }, { 0.250000, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2.200000, bezier = "move" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.200000, bezier = "move" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.400000, bezier = "enter", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.600000, bezier = "exit", style = "popin 80%" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.400000, bezier = "enter" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.600000, bezier = "exit" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.400000, bezier = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.400000, bezier = "fade" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.400000, bezier = "fade" })
hl.animation({ leaf = "border", enabled = true, speed = 1.400000, bezier = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.200000, bezier = "move", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.200000, bezier = "move", style = "slidefadevert 15%" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2.200000, bezier = "move" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "shadowangle", enabled = false })
hl.animation({ leaf = "glowangle", enabled = false })
