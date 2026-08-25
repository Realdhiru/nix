# Workaround: ASUS Vivobook S15 OLED (K5504VA) — brightness keys die after the
# automatic critical-battery hybrid-sleep resume.
#
# What bug this works around
# --------------------------
# After an automatic UPower-triggered `hybrid-sleep` at critical battery
# (~0-5%), the Fn brightness keys (XF86MonBrightnessUp/Down) stop delivering any
# input event until a full reboot. The kernel-side `acpi_video` driver receives
# no ACPI video brightness notifications anymore (`/dev/input/event12` /
# "Video Bus" stays silent), even though the EC is alive and everything else
# (volume keys, touchpad) keeps working. Reproduced 2/2 times on the automatic
# critical-battery path; manual `hybrid-sleep` at normal battery never breaks.
#
# Full evidence trail: docs/debugging/010-debug-brightness-ab.md
#   §4.8  Experiment 8 — rebind-only recovery (method, source-verified callbacks)
#   §13.1 root cause (firmware `_DOS` contract loss, HP-v2 favored)
#   §13.2 proven recovery mechanism (kernel-owned rebind)
#   §13.3 this workaround
#
# Why the rebind is necessary
# ---------------------------
# Unbinding and rebinding the `acpi_video` auxiliary device re-runs the driver
# probe, which re-asserts `_DOS(4)` ("OS owns brightness-key delivery", bit 2),
# reinstalls the ACPI notify handler, recreates the input device and re-evaluates
# `_PS0` (drivers/acpi/acpi_video.c). Measured in a broken session: 0 brightness
# events before → keys working immediately, 42 events captured after the rebind.
# No reboot, no EC re-init, no module unload needed.
#
# Why unconditional on systemd-hybrid-sleep.service (instead of a battery or
# requester check)
# ------------------
# - The only requester of this unit in practice is UPower's critical-battery
#   action (logind lid-switch is `ignore`; no other automated requester).
#   "A hybrid-sleep happened" therefore covers the automatic path; manual
#   hybrids are rare and a rebind there is proven harmless.
# - A journal-based `upowerd` requester check was considered and rejected:
#   logind's message text is not a stable API, and a silent parse failure would
#   miss the rebind on exactly the path that needs it.
# - A battery-capacity snapshot was considered and rejected: it is only a proxy
#   for the trigger and adds state without additional confidence.
# - Churn is already scoped: ordinary s2idle (lid close) and manual hibernate
#   never run this unit. Only hybrid-sleep cycles touch it, and a rebind in a
#   healthy session is a momentary backlight/input re-registration, nothing more.
#
# How to remove
# -------------
# Once a future kernel or ASUS firmware/BIOS update fixes the issue:
#   1. Delete this file.
#   2. Remove the import from hosts/nixos/default.nix.
#   3. `sudo nixos-rebuild switch --flake ~/nix#nixos`
# To confirm it is no longer needed first: remove, rebuild, then verify
# brightness keys survive the next automatic critical-battery hybrid-sleep
# (see verification steps in report §13.3).
{ pkgs, ... }:

{
  systemd.services."systemd-hybrid-sleep" = {
    # ExecStartPost runs after the sleep cycle finishes (i.e. after wake).
    # systemd-hybrid-sleep.service ships no ExecStartPost, so this is a clean
    # append; ExecStart (systemd-sleep hybrid-sleep) is untouched.
    serviceConfig.ExecStartPost = [
      (pkgs.writeShellScript "asus-brightness-rebind" ''
        set -u

        d=/sys/bus/auxiliary/drivers/video
        if [ ! -d "$d" ]; then
          exit 0
        fi

        echo "asus-brightness-rebind: re-arming acpi.video_bus.0 after hybrid-sleep"

        # Unbind then rebind. Errors are ignored on purpose:
        # - unbind fails if the device is not currently bound (nothing to do);
        # - bind fails if the device already re-bound concurrently (keys fine).
        echo acpi.video_bus.0 > "$d"/unbind 2>/dev/null || true
        echo acpi.video_bus.0 > "$d"/bind 2>/dev/null || true
      '')
    ];
  };
}
