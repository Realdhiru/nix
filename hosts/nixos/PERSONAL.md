# Personal Machine Facts & Intentional Settings (host: nixos)

Machine- and user-specific facts for this physical installation. Machine-independent technical facts live in `docs/system.md`.

## 1. Physical Hardware Facts
- **Machine Model**: ASUS Vivobook S 15 OLED (K5504VA / S5504VA). Do NOT confuse with Zenbook, ROG, or Zephyrus.
- **CPU (`lscpu`)**: 13th Gen Intel(R) Core(TM) i5-13500H (12 cores / 16 threads: 4 Performance cores up to 4.7 GHz, 8 Efficient cores up to 3.5 GHz, 18 MiB L3 cache).
- **GPU**: Intel Iris Xe Graphics (i915 driver, Aquamarine DRM backend).
- **Internal Panel**: `eDP-1`, Samsung Display Corp. `0x4180` (2880x1620 @ 120Hz, 16:9, scale 2.0, 10-bit color). Pure black (`#000000`) turns OLED pixels completely off (0W).
- **User Identity**: User credentials declared in `user.nix` (`username = "realdhiru"`, `name = "D"`, `hostname = "NixOS"`).

## 2. Intentional System Settings
- **Display Refresh Rate by Power Source**: 60Hz on battery, 120Hz on AC. `dotfiles/hypr/scripts/refresh_monitor.sh` selects from Hyprland's advertised modes; `$DESKTOP_STATE_DIR/monitors/intent.json` remains the authority for resolution, layout, scale, transform, and placement.
- **Power Management Authority**: TLP 1.10.2 is the sole authority for hardware power profiles (`power.nix`). `asusd.service` is enabled strictly for 80% charge ceiling enforcement (`charge_control_end_threshold = 80`). `asusd.ron` platform profile switching on AC/battery is disabled (`change_platform_profile_on_battery = false`, `bat_profile = Balanced`).
- **USB Camera Stability**: Keep global `usbcore.autosuspend=-1` because the history identifies a webcam streaming stability issue without a VID:PID; TLP `USB_AUTOSUSPEND=0` mirrors that choice.
- **Balanced Battery Profile (Empirically Locked)**: `balance_performance`, Turbo `1`, platform profile `balanced`, ASPM `powersupersave`. Never throttle CPU clocks or disable boost; race-to-sleep to modern C-states ($C8/C10$) saves 3x more energy than throttling.
- **Optional Battery-First Balanced Variant**: `user.power.balancedBatteryFirst = false` preserves the current Balanced feel. When enabled, battery EPP changes to `power` and CPU boost is disabled; this is an opt-in tradeoff and does not alter the Power Saver profile.
- **Internal Speaker Keep-Awake**: Preserve the live speaker's `node.pause-on-idle = false` behavior and the declared `session.suspend-timeout-seconds = 0` rule. The repo does not explicitly set `pause-on-idle`; report its idle power cost without changing the behavior.
- **Automated Profile Switching**: Disconnecting AC power unconditionally switches power profile to `balanced` and clears manual overrides. Cold boots or reloads on battery never restore `performance`.
- **Lid Policy**: `HandleLidSwitch = "ignore"` in logind. Lid closure never suspends. Suspend is intentional (`Shift + Esc`) or automated via 30-minute idle sleep.
- **Dark Mode**: Default system aesthetic.
- **KDE Connect Lifecycle**: On-demand manual toggle (`Super + Shift + K`, `kdeconnect_toggle.sh`). Idle `kdeconnectd` is kept stopped on battery to prevent periodic LAN wakeups from breaking CPU/Wi-Fi deep C-states.
- **Audio Routing Priorities**:
  - `2200`: Virtual 10-band equalizer filter chain (`effect_input.eq10`), capturing all application streams.
  - `2150`: External physical sinks (Bluetooth A2DP AAC stereo, USB DAC, 3.5mm headphones).
  - `1000`: Internal speakers (`HiFi__Speaker__sink`).
  - `2100`: WebRTC echo-cancel source (`echo_cancel_source` canceling `effect_input.eq10:monitor`).
  - WirePlumber: `bluetooth.autoswitch-to-headset-profile = false` locks high-quality A2DP stereo, preventing AVDTP renegotiation crashes on TWS earbuds.
