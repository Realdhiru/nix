local mainMod = "SUPER"
local home = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
local scripts = home .. "/.config/hypr/scripts/"

-- Default applications resolved from environment
local default_terminal = os.getenv("TERMINAL") or "alacritty"
local default_browser = os.getenv("BROWSER") or "brave"
local default_editor = os.getenv("EDITOR") or "gram"
local default_filemanager = os.getenv("FILEMANAGER") or "pcmanfm-qt"

-- ======================================================
-- Helpers
-- ======================================================

local function launch_brave_app(opts)
    local cmd = "brave"
    if opts.incognito then
        cmd = cmd .. " --incognito"
    end
    local profile = opts.profile or "Default"
    cmd = cmd .. ' --profile-directory="' .. profile .. '"'
    if opts.class then
        cmd = cmd .. " --class=" .. opts.class
    end
    if opts.name then
        cmd = cmd .. " --name=" .. opts.name
    end
    cmd = cmd .. " --app=" .. opts.url
    if opts.extra_flags then
        cmd = cmd .. " " .. opts.extra_flags
    end
    return hl.dsp.exec_cmd(cmd)
end

-- ======================================================
-- 1. Daily Core (Close, Launchers, Terminal, Browser, Utilities)
-- ======================================================

-- Close (graceful) of the FOCUSED window only. Legacy "killactive" mapped to
-- Actions::closeWindow() (sendClose) — NOT SIGKILL. hl.dsp.window.kill()
-- SIGKILLs the client process and takes down every window of the app.
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "close focused window" })

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(scripts .. "fuzzel_menu.sh app"), { description = "application launcher" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(scripts .. "fuzzel_menu.sh file"), { description = "file finder" })
hl.bind(mainMod .. " + PERIOD", hl.dsp.exec_cmd(scripts .. "fuzzel_menu.sh emoji"), { description = "emoji picker" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(default_terminal), { description = "launch default terminal" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(default_terminal .. " -o font.size=7 -e zsh -c 'fastfetch; exec zsh'"),
    { description = "launch terminal with fastfetch" })

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(default_browser), { description = "launch default web browser" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME=qt6ct " .. default_filemanager),
    { description = "launch default file manager" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(default_editor), { description = "launch default editor" })

hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("blueman-manager"), { description = "launch bluetooth manager" })
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("pwvucontrol"), { description = "launch audio control" })

-- ======================================================
-- 2. Daily Audio, Brightness & Media
-- ======================================================

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "osd.sh vol-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "osd.sh vol-down"), { locked = true, repeating = true })

-- The keyboard knob reports XF86Audio volume keys. With Super held, turn
-- those events into pointer-wheel input through ydotool's uinput device.
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y 1"), { locked = true })
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y -1"), { locked = true })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scripts .. "osd.sh vol-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "osd.sh mic-mute"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "osd.sh bright-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "osd.sh bright-down"), { locked = true, repeating = true })

hl.bind("SHIFT + F3", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "pause media" })
hl.bind("SHIFT + F4", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "previous media" })
hl.bind("SHIFT + F5", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "next media" })

-- ======================================================
-- 3. Workspaces (macOS Spaces model)
-- ======================================================

local function get_focused_monitor_workspace_base()
    local mons = hl.get_monitors()
    local active_mons = {}
    for _, m in ipairs(mons) do
        local is_mirror = (m.mirrorOf and m.mirrorOf ~= "none" and m.mirrorOf ~= "")
        if not m.disabled and not is_mirror then
            table.insert(active_mons, m)
        end
    end

    if #active_mons <= 1 then
        return 0
    end

    table.sort(active_mons, function(a, b)
        if (a.x or 0) ~= (b.x or 0) then
            return (a.x or 0) < (b.x or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    local focused_index = 1
    for idx, m in ipairs(active_mons) do
        if m.focused then
            focused_index = idx
            break
        end
    end

    return (focused_index - 1) * 10
end

local function focus_monitor_workspace(i)
    return function()
        local base = get_focused_monitor_workspace_base()
        hl.dispatch(hl.dsp.focus({ workspace = base + i }))
    end
end

local function move_to_monitor_workspace(i)
    return function()
        local base = get_focused_monitor_workspace_base()
        hl.dispatch(hl.dsp.window.move({ workspace = base + i }))
    end
end

hl.bind(mainMod .. " + CTRL + Right", hl.dsp.focus({ workspace = "m+1" }), { description = "workspace next on monitor" })
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.focus({ workspace = "m-1" }), { description = "workspace previous on monitor" })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.focus({ workspace = "empty" }), { description = "nearest empty workspace" })

for i = 1, 10 do
    local key = (i == 10) and "0" or tostring(i)
    hl.bind(mainMod .. " + " .. key, focus_monitor_workspace(i),
        { description = "focus workspace " .. i .. " on active monitor" })
    hl.bind(mainMod .. " + SHIFT + " .. key, move_to_monitor_workspace(i),
        { description = "move window to workspace " .. i .. " on active monitor" })
end

-- ======================================================
-- 4. Focus Navigation
-- ======================================================

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "l" }), { description = "focus window left" })
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "r" }), { description = "focus window right" })
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "u" }), { description = "focus window up" })
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "d" }), { description = "focus window down" })

-- ======================================================
-- 5. Screenshots & Recording
-- ======================================================

hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(scripts .. "screenshot.sh area"), { description = "capture region screenshot" })
hl.bind(mainMod .. " + CTRL + SHIFT + Z", hl.dsp.exec_cmd(scripts .. "screenshot.sh freeze"),
    { description = "capture frozen region screenshot" })
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(scripts .. "screenshot.sh ocr"), { description = "ocr region screenshot to clipboard" })
hl.bind("Print", hl.dsp.exec_cmd(scripts .. "screenshot.sh screen"), { description = "capture full screen screenshot" })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(scripts .. "record.sh"), { description = "toggle screen recording" })

-- ======================================================
-- 6. Modes & System Session
-- ======================================================

-- Lock all keybinds (except unlock)
hl.bind("CTRL + ALT + SHIFT + Delete", function()
    hl.exec_cmd('notify-send -a "System" -u critical "ON"')
    hl.dispatch(hl.dsp.submap("locked"))
end)

hl.define_submap("locked", function()
    hl.bind("CTRL + ALT + SHIFT + Delete", function()
        hl.exec_cmd('notify-send -a "System" "OFF"')
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

-- Desktop Modes & Hardware Services (SUPER + F1..F10)
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(scripts .. "wallpaper.sh kill"),
    { description = "toggle solid mode (kill wallpaper)" })
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd(scripts .. "power.sh inhibit"),
    { description = "toggle coffee mode idle inhibit" })
hl.bind(mainMod .. " + F3", hl.dsp.exec_cmd(scripts .. "toggle_gaming_mode.sh"),
    { description = "toggle gaming mode" })
hl.bind(mainMod .. " + F4", hl.dsp.exec_cmd(scripts .. "kdeconnect_toggle.sh"),
    { description = "toggle kde connect daemon & tray" })
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd(scripts .. "mode_ctl.sh toggle power-saver"),
    { description = "toggle power-saver mode" })
hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd(scripts .. "toggle_multi_sink.sh"),
    { description = "toggle multi-sink audio broadcast" })
hl.bind(mainMod .. " + F7", hl.dsp.exec_cmd(scripts .. "fix_audio.sh"),
    { description = "recover audio subsystem" })
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle quickshell"),
    { description = "toggle/kill quickshell processes" })
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd(scripts .. "toggle_layout.sh"),
    { description = "toggle dwindle and scrolling layout" })

hl.bind("SHIFT + escape", hl.dsp.exec_cmd(scripts .. "power.sh suspend"), { description = "suspend system" })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd(scripts .. "power.sh display toggle"), { locked = true, description = "toggle display power" })
hl.bind("CTRL + escape", hl.dsp.exec_cmd(scripts .. "rotate_display.sh"), { description = "rotate display orientation" })
hl.bind("SHIFT + F1", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }), { description = "toggle fullscreen" })
hl.bind("SHIFT + F2", hl.dsp.exec_cmd(scripts .. "power.sh lock"), { description = "lock session" })

-- Fault-isolated Lid Switch Events
pcall(function()
    hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(scripts .. "power.sh lid close"), { locked = true })
    hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(scripts .. "power.sh lid open"), { locked = true })
end)

-- Reload Compositor, Quickshell, and System
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(scripts .. "reload.sh"), { description = "reload compositor and quickshell" })

-- ======================================================
-- 7. Quickshell & Widgets
-- ======================================================

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle network"), { description = "toggle network widget" })
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle focustime"),
    { description = "toggle focustime widget" })
hl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle monitors"),
    { description = "toggle monitors widget" })
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle battery"), { description = "toggle battery widget" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle wallpaper"),
    { description = "toggle wallpaper widget" })
hl.bind(mainMod .. " + SHIFT + backslash", hl.dsp.exec_cmd(scripts .. "wallpaper.sh fav"),
    { description = "toggle wallpaper favorite" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle clipboard"),
    { description = "toggle clipboard widget" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle music"),
    { description = "toggle music widget" })
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle calendar"),
    { description = "toggle calendar widget" })

hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd(scripts .. "toggle_multi_sink.sh"),
    { description = "toggle multi-sink audio broadcast" })
hl.bind(mainMod .. " + CTRL + SHIFT + V", hl.dsp.exec_cmd(scripts .. "fix_audio.sh"),
    { description = "recover audio subsystem" })
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle sunset"),
    { description = "toggle sunset screen tint" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(scripts .. "quickshell/toggle_theme_mode.sh"),
    { description = "toggle quickshell theme mode" })
hl.bind(mainMod .. " + CTRL + SHIFT + Q", hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle quickshell"),
    { description = "toggle quickshell overlay" })

-- Toggle Active Bar Only (SUPER + CTRL + ALT in any press order)
local bar_toggle_combos = {
    mainMod .. " + CTRL + Alt_L",
    mainMod .. " + CTRL + Alt_R",
    mainMod .. " + ALT + Control_L",
    mainMod .. " + ALT + Control_R",
    "CTRL + ALT + Super_L",
    "CTRL + ALT + Super_R",
}
for _, combo in ipairs(bar_toggle_combos) do
    hl.bind(combo, hl.dsp.exec_cmd(scripts .. "qs_manager.sh toggle bar"), { description = "toggle quickshell bar" })
end

-- Cycle Wallpaper Left / Right
hl.bind(mainMod .. " + ALT + Left", hl.dsp.exec_cmd(scripts .. "cycle_wallpaper.sh prev"),
    { repeating = true, description = "previous wallpaper" })
hl.bind(mainMod .. " + ALT + Right", hl.dsp.exec_cmd(scripts .. "cycle_wallpaper.sh next"),
    { repeating = true, description = "next wallpaper" })

-- TopBar Position (Top / Left)
hl.bind(mainMod .. " + ALT + Up", hl.dsp.exec_cmd(scripts .. "qs_manager.sh position topbar top"),
    { description = "position topbar top" })
hl.bind(mainMod .. " + ALT + Down", hl.dsp.exec_cmd(scripts .. "qs_manager.sh position topbar left"),
    { description = "position topbar left" })

-- ======================================================
-- 8. Web Apps (SUPER + SHIFT + Letter)
-- ======================================================

hl.bind(mainMod .. " + SHIFT + C",
    launch_brave_app({ class = "chatgpt", name = "chatgpt", url = "https://chat.openai.com" }),
    { description = "launch ChatGPT web app" })

hl.bind(mainMod .. " + SHIFT + A",
    launch_brave_app({ class = "claude", url = "https://claude.ai/new" }),
    { description = "launch Claude web app" })

hl.bind(mainMod .. " + CTRL + SHIFT + A",
    launch_brave_app({ incognito = true, class = "claude", url = "https://claude.ai/new" }),
    { description = "launch Claude (incognito) web app" })

hl.bind(mainMod .. " + SHIFT + Q",
    launch_brave_app({ class = "whatsapp", url = "https://web.whatsapp.com" }),
    { description = "launch WhatsApp web app" })

hl.bind(mainMod .. " + SHIFT + N",
    launch_brave_app({ class = "notion", url = "https://www.notion.so/02917993852a4825ab25a38c938de4f8" }),
    { description = "launch Notion web app" })

hl.bind(mainMod .. " + SHIFT + T",
    launch_brave_app({ class = "todo", name = "todo", url = "https://to-do.live.com/tasks/inbox" }),
    { description = "launch Microsoft To-Do web app" })

hl.bind(mainMod .. " + SHIFT + Y",
    launch_brave_app({
        profile = "youtube",
        class = "youtube",
        url = "https://youtube.com",
        extra_flags = "--use-gl=angle --use-angle=gl --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder --enable-zero-copy",
    }),
    { description = "launch YouTube web app" })

-- ======================================================
-- 9. Window Management & Geometry
-- ======================================================

hl.bind(mainMod .. " + G", hl.dsp.window.pin(), { description = "pin active window" })
hl.bind(mainMod .. " + W", hl.dsp.window.float(), { description = "toggle window floating" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "toggle pseudo-tiling" })

hl.bind(mainMod .. " + Z", hl.dsp.window.drag(), { mouse = true, description = "hold to move window" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "drag window with mouse" })

-- ======================================================
-- 10. Rarely Used: Special Workspaces
-- ======================================================

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "toggle magic special workspace" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "move window to magic special workspace" })
hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special("music"), { description = "toggle music special workspace" })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "special:music" }),
    { description = "move window to music special workspace" })

-- ======================================================
-- 11. Rarely Used: Cursor Zoom & Gestures
-- ======================================================

local current_zoom = 1.0
local target_zoom = 1.0
local anim_seq = 0
local base_sensitivity = 0.5 -- Default configured sensitivity from input.lua

local function smooth_zoom_to(new_target, custom_easing)
    target_zoom = new_target
    anim_seq = anim_seq + 1
    local current_seq = anim_seq
    local easing = custom_easing or 0.16

    local function step()
        if anim_seq ~= current_seq then
            return
        end
        local delta = target_zoom - current_zoom
        if math.abs(delta) < 0.008 then
            current_zoom = target_zoom
            -- Dampen mouse sensitivity proportionally when zoomed in to eliminate hand tremors
            local target_sens = base_sensitivity
            if current_zoom > 1.05 then
                target_sens = math.max(-0.6, base_sensitivity - math.log(current_zoom) * 0.45)
            end
            hl.config({
                cursor = { zoom_factor = current_zoom },
                input = { sensitivity = target_sens },
            })
            return
        end

        current_zoom = current_zoom + delta * easing
        local cur_sens = base_sensitivity
        if current_zoom > 1.05 then
            cur_sens = math.max(-0.6, base_sensitivity - math.log(current_zoom) * 0.45)
        end
        hl.config({
            cursor = { zoom_factor = current_zoom },
            input = { sensitivity = cur_sens },
        })
        hl.timer(step, { type = "oneshot", timeout = 16 })
    end

    step()
end

-- Share the same zoom state and easing across wheel and Super + pinch gestures.
local function zoom_in()
    local next_target
    if target_zoom < 1.05 then
        next_target = 1.28
    else
        next_target = math.min(50.0, target_zoom * 1.5)
    end
    smooth_zoom_to(next_target, 0.16)
end

local function zoom_out()
    smooth_zoom_to(1.0, 0.08)
end

-- Mouse wheel zoom remains unchanged; the virtual ydotool pointer is excluded
-- because it injects wheel events for the external keyboard volume knob.
hl.bind(mainMod .. " + mouse_up", zoom_in, {
    device = { inclusive = false, list = { "ydotoold-virtual-device-1" } },
})
hl.bind(mainMod .. " + mouse_down", zoom_out, {
    device = { inclusive = false, list = { "ydotoold-virtual-device-1" } },
})

local gesture_base_zoom = 1.0
local gesture_reset_triggered = false

-- Super + two-finger pinch: continuous zoom in on spread, instant smooth reset on pinch in
hl.gesture({
    fingers = 2,
    direction = "pinch",
    mods = mainMod,
    action = {
        start = function()
            gesture_base_zoom = current_zoom
            gesture_reset_triggered = false
        end,
        update = function(event)
            local scale = (type(event) == "table" and event.scale) or tonumber(event) or 1.0
            if scale < 0.97 then
                if not gesture_reset_triggered then
                    gesture_reset_triggered = true
                    zoom_out()
                end
            elseif scale >= 1.0 then
                gesture_reset_triggered = false
                local target = math.max(1.0, math.min(50.0, gesture_base_zoom * scale))
                smooth_zoom_to(target, 0.4)
            end
        end,
        ["end"] = function()
            gesture_reset_triggered = false
        end,
    },
})
