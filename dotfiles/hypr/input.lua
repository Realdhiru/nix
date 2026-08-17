-- ==================== INPUT ====================

-- https://wiki.hypr.land/Configuring/Variables/#input
hl.config({
    input = {
        kb_layout     = "us",
        follow_mouse  = 1,
        sensitivity   = 0.5, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "adaptive",
        scroll_factor = 1,
        touchpad      = {
            natural_scroll = true,
        },
    },
})
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })