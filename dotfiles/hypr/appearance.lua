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

        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 3,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1a44)",
        },

        blur = {
            enabled  = true,
            size     = 8,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

-- Animations live in motion.lua (generated from motion-tokens.nix).
})
