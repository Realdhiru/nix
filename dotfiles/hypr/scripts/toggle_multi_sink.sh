#!/usr/bin/env bash
# Fast Multi-Output Audio Toggle (pure bash + pw-link)
# Toggles concurrent playback to all connected external sinks (Bluetooth + Wired) while bypassing internal speakers.

STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/multi_sink_active"
SPEAKER_SINK="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"

# Discover all active external playback nodes (excluding equalizer and internal speaker)
mapfile -t ext_sinks < <(pw-link -i 2>/dev/null | grep ':playback_FL' | grep -E 'bluez_output|Headphones|headset|usb' | sed 's/:playback_FL//' | sort -u)

if [ "${#ext_sinks[@]}" -eq 0 ]; then
    notify-send -u low -t 1500 "No external sink"
    rm -f "$STATE_FILE"
    exit 0
fi

if [ -f "$STATE_FILE" ]; then
    # Toggle OFF: revert to standard single default routing
    rm -f "$STATE_FILE"

    for sink in "${ext_sinks[@]}"; do
        pw-link -d effect_output.eq10:output_FL "${sink}:playback_FL" 2>/dev/null || true
        pw-link -d effect_output.eq10:output_FR "${sink}:playback_FR" 2>/dev/null || true
    done

    # Reconnect primary target (first external sink)
    primary_sink="${ext_sinks[0]}"
    pw-link effect_output.eq10:output_FL "${primary_sink}:playback_FL" 2>/dev/null || true
    pw-link effect_output.eq10:output_FR "${primary_sink}:playback_FR" 2>/dev/null || true

    notify-send -u low -t 1500 "Multi-output OFF"
else
    # Toggle ON: broadcast to all external sinks, unlink internal speaker
    touch "$STATE_FILE"

    # Disconnect internal laptop speaker
    pw-link -d effect_output.eq10:output_FL "${SPEAKER_SINK}:playback_FL" 2>/dev/null || true
    pw-link -d effect_output.eq10:output_FR "${SPEAKER_SINK}:playback_FR" 2>/dev/null || true

    # Link effect_output to every detected external sink
    for sink in "${ext_sinks[@]}"; do
        pw-link effect_output.eq10:output_FL "${sink}:playback_FL" 2>/dev/null || true
        pw-link effect_output.eq10:output_FR "${sink}:playback_FR" 2>/dev/null || true
    done

    notify-send -u low -t 1500 "Multi-output ON"
fi
