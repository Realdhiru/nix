---
title: Automated Rollback Safeguards
tags: [recovery, health-check, rollback, safety, self-healing]
---

# Automated Rollback Safeguards and Health Checks

When `rebuild()` activates a new system generation, it immediately transfers execution to `scripts/health-check.sh`.

This document explains the test harness that enables our operating system to self-heal when updates fail runtime verification.

---

## 1. The Verification Probes

The health check executes three independent verification passes:

### 1. Compositor IPC Probe
Verifies that the Hyprland UNIX domain socket is active and accepting IPC queries (`hyprctl monitors`).

### 2. Isolated Terminal Sandbox Probe
Spawns an isolated `alacritty` instance with test arguments to verify that GPU acceleration, font rendering, and terminal libraries did not break under the new Mesa or Wayland libraries.

### 3. Critical User Daemon Audit
Queries systemd user services to ensure critical infrastructure is active:
- `pipewire.service`
- `wireplumber.service`
- `cliphist-text-watcher.service`
- `cliphist-image-watcher.service`

---

## 2. The Exit Code Protocol

- **Exit Code 0 (PASS)**: All probes succeeded. Generation is declared healthy.
- **Exit Code 2 (WARNING)**: Non-critical telemetry warning (e.g. battery charger state unreadable). Logged to `~/.cache/nix_health_*.log` without rolling back.
- **Exit Code 1 (CRITICAL FAIL)**: A critical service or display server crashed. The script immediately executes:
  ```bash
  sudo nixos-rebuild switch --rollback --flake ~/nix#nixos
  ```
  The system restores the known-good generation in under 3 seconds.

## Related Nodes
- [[The rebuild() Function]]
- [[Emergency Recovery Protocol]]
