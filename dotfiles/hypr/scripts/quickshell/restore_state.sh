#!/usr/bin/env bash
# QuickShell System-Wide State Restoration Script
# Canonical State File: ~/.cache/quickshell/state.json

STATE_DIR="$HOME/.cache/quickshell"
STATE_FILE="$STATE_DIR/state.json"
SHADER_FILE="$HOME/.cache/screen_shader.frag"

mkdir -p "$STATE_DIR"

# NOTE: the old `hyprctl monitors -j > monitors.json` snapshot write was retired —
# its only consumer (Main.qml monitorPhys* via FileView) now reads live per-screen
# geometry (masterWindow.screen → Quickshell.screens), and the monitor popup polls
# Hyprland directly. Nothing reads monitors.json anymore.

# Initialize default state JSON if missing
if [ ! -f "$STATE_FILE" ]; then
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
    "dnd": false,
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
GAMING=false; WP_KILLED=false; DND=false; COFFEE=false; POWER_PROF="balanced"

if [ -f "$STATE_FILE" ]; then
    vals=$(jq -r '[
        (.sunset.temp // 6500),
        (.sunset.gamma // 100),
        (.sunset.sat // 100),
        (.sunset.grain // 0),
        (.sunset.crt // 0),
        (.modes.gaming // false),
        (.modes.wallpaperKilled // false),
        (.modes.dnd // false),
        (.modes.coffee // false),
        (.power.profile // "balanced")
    ] | @tsv' "$STATE_FILE" 2>/dev/null || true)

    if [ -n "$vals" ]; then
        read -r TEMP GAMMA SAT GRAIN CRT GAMING WP_KILLED DND COFFEE POWER_PROF <<< "$vals"
    fi
fi


# 1. Hardware CTM Restoration (hyprsunset)
if [ "$TEMP" -ne 6500 ] || [ "$GAMMA" -ne 100 ]; then
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
if [ "$SAT" -ne 100 ] || [ "$GRAIN" -gt 0 ] || [ "$CRT" -gt 0 ]; then
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

# 3. Gaming Mode & Flag Synchronization
if [ "$GAMING" = "true" ]; then
    touch "$HOME/.cache/gaming_mode"
else
    rm -f "$HOME/.cache/gaming_mode"
fi

# 4. Wallpaper Killed Flag Synchronization
if [ "$WP_KILLED" = "true" ]; then
    touch "$HOME/.cache/wallpaper_killed"
else
    rm -f "$HOME/.cache/wallpaper_killed"
fi

# 5. DND Synchronization
mkdir -p "$STATE_DIR/dnd"
if [ "$DND" = "true" ]; then
    echo "1" > "$STATE_DIR/dnd/state"
else
    echo "0" > "$STATE_DIR/dnd/state"
fi

# 6. Power Profile Synchronization
echo "$POWER_PROF" > "$HOME/.cache/qs_power_profile"

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
