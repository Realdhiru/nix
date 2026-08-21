local mainMod = "SUPER"

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

hl.bind("SHIFT + escape", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/suspend.sh suspend"))
hl.bind("CTRL + escape", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/rotate_display.sh"))
hl.bind("SHIFT + F1", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" })) -- 1 for semi fullscreen
hl.bind("SHIFT + F2", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/lock.sh"))
hl.bind(mainMod .. " + CTRL + U", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/idle_inhibit.sh"))

-- Fault-isolated Lid Switch Events
pcall(function()
    hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/lid-monitor.sh close"), { locked = true })
    hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/lid-monitor.sh open"), { locked = true })
end)

-- ======================================================
-- Quickshell
-- ======================================================

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle network"))
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle volume"))
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle focustime"))

hl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle monitors"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle battery"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle wallpaper"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle clipboard"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle music"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/qs_manager.sh toggle calendar"))

hl.bind(mainMod .. " + CTRL + SHIFT + V", hl.dsp.exec_cmd("/home/realdhiru/nix/dotfiles/hypr/scripts/fix_audio.sh"))

-- Reload Hyprland & Quickshell
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/reload.sh"))

-- Disable/Enable Quickshell
hl.bind(mainMod .. " + ALT + ALT_R", hl.dsp.exec_cmd('bash -c "if pidof quickshell >/dev/null || pidof .quickshell-wra >/dev/null; then killall -9 quickshell .quickshell-wra; else quickshell -p /home/realdhiru/.config/hypr/scripts/quickshell/Shell.qml & fi"'))

-- ======================================================
-- Applications
-- ======================================================

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("wezterm"))
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd('wezterm start -- zsh -c "fastfetch; exec zsh"'))

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("pcmanfm-qt"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("pkill rofi || rofi -show drun"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("codium"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("brave"))

hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("pwvucontrol"))

-- ======================================================
-- Web Apps
-- ======================================================

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=chatgpt --name=chatgpt --app=https://chat.openai.com'))

hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=claude --app=https://claude.ai/new'))

hl.bind(mainMod .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd('brave  --incognito --profile-directory="Default" --class=claude --app=https://claude.ai/new'))

hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=monkeytype --app=https://monkeytype.com/'))

hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=whatsapp --app=https://web.whatsapp.com'))

hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=notion --app=https://www.notion.so/02917993852a4825ab25a38c938de4f8'))

hl.bind(mainMod .. " + ALT + Y", hl.dsp.exec_cmd('brave  --profile-directory="youtube" --class=youtube --app=https://youtube.com'))

hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd('brave  --profile-directory="Default" --class=todo --name=todo --app=https://to-do.live.com/tasks/inbox'))

-- ======================================================
-- Screenshots & Recording
-- ======================================================

hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/cycle-shader.sh"))

hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("grimblast copy area"))
hl.bind(mainMod .. " + CTRL + SHIFT + Z", hl.dsp.exec_cmd("grimblast --freeze copy area"))

hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/record.sh"))

-- ======================================================
-- Window Management
-- ======================================================

hl.bind(mainMod .. " + Z", hl.dsp.window.drag(), { mouse = true, description = "hold to move window" })
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true, description = "hold to resize window" })

-- close (graceful) of the FOCUSED window only. Legacy "killactive" mapped to
-- Actions::closeWindow() (sendClose) — NOT SIGKILL. hl.dsp.window.kill()
-- SIGKILLs the client process and takes down every window of the app.
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + W", hl.dsp.window.float())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special("music"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "special:music" }))
hl.bind(mainMod .. " + F", hl.dsp.workspace.toggle_special("notes"))
-- hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.move({ workspace = "special:notes" }))
hl.bind(mainMod .. " + G", hl.dsp.workspace.toggle_special("misc"))
-- hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ workspace = "special:misc" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ======================================================
-- Media
-- ======================================================

hl.bind("SHIFT + F3", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "pause media" })
hl.bind("SHIFT + F4", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "previous media" })
hl.bind("SHIFT + F5", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "next media" })

-- hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "next media" })
-- hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "pause media" })
-- hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "play media" })
-- hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "previous media" })

-- ======================================================
-- Audio & Brightness
-- ======================================================

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh vol-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh vol-down"), { locked = true, repeating = true })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh vol-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh mic-mute"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh bright-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("/home/realdhiru/.config/hypr/scripts/osd.sh bright-down"), { locked = true, repeating = true })

-- ======================================================
-- Focus
-- ======================================================

hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.pin())

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "d" }))

-- ======================================================
-- Resize Active Window
-- ======================================================

hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true, description = "resize window right" })
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true, description = "resize window left" })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true, description = "resize window up" })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true, description = "resize window down" })

-- ======================================================
-- Workspaces
-- ======================================================

hl.bind(mainMod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "workspace next" })
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "workspace previous" })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.focus({ workspace = "empty" }), { description = "nearest empty workspace" })

-- Switch
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- ======================================================
-- Cursor Zoom
-- ======================================================

hl.bind(mainMod .. " + mouse_up", hl.dsp.exec_cmd("hyprctl eval \"hl.config({cursor={zoom_factor=$(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $NF + 0.9}')}})\""), { non_consuming = true })

hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("hyprctl eval \"hl.config({cursor={zoom_factor=1.0}})\""), { non_consuming = true })

-- hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("pkill -x rofi || $menu f"))
-- hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("pkill -x rofi || $menu w"))
-- hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("pkill -x rofi || hyde-shell emoji-picker"))
-- hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("pkill -x rofi || hyde-shell glyph-picker"))
-- hl.bind(mainMod .. " + ALT + G", hl.dsp.exec_cmd("hyde-shell gamemode"))
-- hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -an"))
-- hl.bind("Print", hl.dsp.exec_cmd("hyde-shell screenshot p"), { locked = true, repeating = true })