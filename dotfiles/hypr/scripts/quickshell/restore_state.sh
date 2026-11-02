#!/usr/bin/env bash
# QuickShell System-Wide State Restoration Script
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_DIR="$DESKTOP_STATE_DIR/quickshell"
STATE_FILE="$STATE_DIR/state.json"
MODES_DIR="$DESKTOP_STATE_DIR/modes"
POWER_DIR="$DESKTOP_STATE_DIR/power"
REC_DIR="$DESKTOP_STATE_DIR/recording"
SHADER_FILE="$HOME/.cache/screen_shader.frag"

mkdir -p "$STATE_DIR" "$MODES_DIR" "$POWER_DIR" "$REC_DIR"

# NOTE: the old `hyprctl monitors -j > monitors.json` snapshot write was retired —
# its only consumer (Main.qml monitorPhys* via FileView) now reads live per-screen
# geometry (masterWindow.screen → Quickshell.screens), and the monitor popup polls
# Hyprland directly. Nothing reads monitors.json anymore.

# Initialize default state JSON if missing or empty
if [ ! -s "$STATE_FILE" ]; then
    cat <<'EOF' > "$STATE_FILE"
{
  "version": 1,
  "sunset": {
    "temp": 6500,
    "gamma": 100,
    "sat": 100,
    "grain": 0,
    "crt": 0,
    "active": false
  },
  "modes": {
    "gaming": false,
    "wallpaperKilled": false,
    "coffee": false
  },
  "power": {
    "profile": "balanced"
  },
  "ui": {
    "wallpaperFilter": "All",
    "networkMode": "wifi"
  }
}
EOF
fi

# Parse state JSON via jq
TEMP=6500; GAMMA=100; SAT=100; GRAIN=0; CRT=0
GAMING=false; WP_KILLED=false; COFFEE=false; POWER_PROF="balanced"; SUNSET_ACTIVE=false

if [ -f "$STATE_FILE" ]; then
    vals=$(jq -r '[
        (.sunset.temp // 6500),
        (.sunset.gamma // 100),
        (.sunset.sat // 100),
        (.sunset.grain // 0),
        (.sunset.crt // 0),
        (.modes.gaming // false),
        (.modes.wallpaperKilled // false),
        (.modes.coffee // false),
        (.power.profile // "balanced"),
        (.sunset.active // false)
    ] | @tsv' "$STATE_FILE" 2>/dev/null || true)

    if [ -n "$vals" ]; then
        read -r TEMP GAMMA SAT GRAIN CRT GAMING WP_KILLED COFFEE POWER_PROF SUNSET_ACTIVE <<< "$vals"
    fi
fi


# 1. Hardware CTM Restoration (hyprsunset)
if [ "$SUNSET_ACTIVE" = "true" ] && ([ "$TEMP" -ne 6500 ] || [ "$GAMMA" -ne 100 ]); then
    if ! pgrep -x hyprsunset >/dev/null 2>&1; then
        nohup hyprsunset -t "$TEMP" -g "$GAMMA" >/dev/null 2>&1 & disown
        sleep 0.08
    fi
    hyprctl hyprsunset temperature "$TEMP" >/dev/null 2>&1 || true
    hyprctl hyprsunset gamma "$GAMMA" >/dev/null 2>&1 || true
else
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        hyprctl hyprsunset identity >/dev/null 2>&1 || true
        pkill -x hyprsunset >/dev/null 2>&1 || true
    fi
fi

# 2. Shader Restoration (Saturation / Paper Grain / CRT Curvature)
NEEDS_SHADER=0
if [ "$SUNSET_ACTIVE" = "true" ] && ([ "$SAT" -ne 100 ] || [ "$GRAIN" -gt 0 ] || [ "$CRT" -gt 0 ]); then
    NEEDS_SHADER=1
fi

if [ "$NEEDS_SHADER" -eq 0 ]; then
    hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
    rm -f "$SHADER_FILE"
else
    SAT_FLOAT=$(awk -v s="$SAT" 'BEGIN { printf "%.3f", s/100.0 }')
    GRAIN_FLOAT=$(awk -v g="$GRAIN" 'BEGIN { printf "%.3f", (g/100.0)*1.5 }')
    CRT_FLOAT=$(awk -v c="$CRT" 'BEGIN { printf "%.3f", c/100.0 }')

    cat <<EOF > "$SHADER_FILE"
#version 300 es
#define HYPRLAND_HOOK debug:damage_tracking 1
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float paper_grain(vec2 uv){
    mediump float g = fract(sin(dot(uv * 800.0, vec2(12.9898,78.233))) * 43758.5453);
    return g * 0.12 - 0.06;
}

vec2 crtCurve(vec2 uv, float strength){
    if (strength <= 0.0) return uv;
    vec2 p = uv * 2.0 - 1.0;
    vec2 off = abs(p.yx) / 4.8;
    p += (p * off * off) * strength;
    return p * 0.5 + 0.5;
}

void main(){
    vec2 uv0 = v_texcoord;

    float crtStrength = ${CRT_FLOAT};
    vec2 uv = crtCurve(uv0, crtStrength);

    // Zoom fix for CRT corners
    float ZOOM = mix(1.0, 1.015, crtStrength);
    uv = (uv - 0.5) / ZOOM + 0.5;

    vec4 pix = texture(tex, clamp(uv, 0.0, 1.0));
    vec3 col = pix.rgb;

    // Saturation pass
    float sat = ${SAT_FLOAT};
    if (sat != 1.0) {
        float gray = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(gray), col, sat);
    }

    // Paper grain pass
    float grainVal = ${GRAIN_FLOAT};
    if (grainVal > 0.0) {
        float g = paper_grain(uv0);
        col = clamp(col + g * grainVal, 0.0, 1.0);
    }

    fragColor = vec4(col, pix.a);
}
EOF
    hyprctl eval "hl.config({ decoration = { screen_shader = '${SHADER_FILE}' } })" >/dev/null 2>&1 || true
fi

# 3. Synchronize modes via mode_ctl.sh (Single Source of Truth)
MODES_CTL="$SCRIPTS_DIR/mode_ctl.sh"
[ ! -x "$MODES_CTL" ] && MODES_CTL="$HOME/nix/dotfiles/hypr/scripts/mode_ctl.sh"
[ -x "$MODES_CTL" ] && bash "$MODES_CTL" apply >/dev/null 2>&1 || true



# 6. Power Profile Synchronization
echo "$POWER_PROF" > "$POWER_DIR/profile.tmp" && mv -f "$POWER_DIR/profile.tmp" "$POWER_DIR/profile"
rm -f "$HOME/.cache/qs_power_profile" /tmp/qs_power_profile /tmp/qs_requested_profile

# 7. Coffee Mode (Idle Inhibit) Synchronization
if [ "$COFFEE" = "true" ]; then
    if ! systemctl --user is-active --quiet coffee-mode 2>/dev/null && ! systemd-inhibit --list 2>/dev/null | grep -q "idle-inhibit-toggle"; then
        systemd-run --user --unit=coffee-mode systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity >/dev/null 2>&1
    fi
else
    if systemctl --user is-active --quiet coffee-mode 2>/dev/null || systemd-inhibit --list 2>/dev/null | grep -q "idle-inhibit-toggle"; then
        systemctl --user stop coffee-mode 2>/dev/null || true
        pkill -f "idle-inhibit-toggle" 2>/dev/null || true
    fi
fi

# 8. Remove obsolete hyprsunset_state.json if present
rm -f "$HOME/.cache/hyprsunset_state.json"

# 9. Power Key Inhibit Synchronization (routes power button to Hyprland XF86PowerOff)
if ! systemctl --user is-active --quiet inhibit-power-key 2>/dev/null && ! systemd-inhibit --list 2>/dev/null | grep -q "handle-power-key"; then
    systemd-run --user --unit=inhibit-power-key systemd-inhibit --what=handle-power-key --who=hyprland --why="Handle power key in Hyprland" --mode=block sleep infinity >/dev/null 2>&1 || true
fi

# 10. Bluetooth Power State Restoration (Strictly respect persistent state)
BT_STATE_DIR="$DESKTOP_STATE_DIR/bluetooth"
if [ -f "$BT_STATE_DIR/power" ]; then
    BT_SAVED_POWER="$(cat "$BT_STATE_DIR/power" 2>/dev/null | tr -d '\r\n')"
    if [ "$BT_SAVED_POWER" = "off" ]; then
        timeout 0.5 bluetoothctl power off >/dev/null 2>&1 || true
    elif [ "$BT_SAVED_POWER" = "on" ]; then
        rfkill unblock bluetooth 2>/dev/null || true
        timeout 0.5 bluetoothctl power on >/dev/null 2>&1 || true
    fi
else
    # Default to OFF if never explicitly turned on
    timeout 0.5 bluetoothctl power off >/dev/null 2>&1 || true
    mkdir -p "$BT_STATE_DIR"
    echo "off" > "$BT_STATE_DIR/power"
fi
