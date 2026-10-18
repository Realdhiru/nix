---
title: The rebuild() Function
tags: [workflow, rebuild, automation, safety-gate, shell, rollbacks]
---

# The rebuild() Function: The Autonomous Safety Gate

In `modules/home/shell.nix`, we defined a custom shell function that completely replaces manual `nixos-rebuild switch`:

```bash
rebuild "commit message"
```

This document details the multi-stage validation pipeline that guarantees system changes cannot leave the machine in a broken or unbootable state.

---

## 1. The 4-Stage Atomic Pipeline

```
[rebuild "msg"]
      │
      ├─▶ 1. Code Formatting & Git Staging
      │      Executes Alejandra (Nix formatter) and stages files (`git add -A`)
      │
      ├─▶ 2. Sandboxed Dry-Build Gate (`nixos-rebuild build --flake .#nixos`)
      │      Compiles derivations in sandbox WITHOUT modifying the active system!
      │      If evaluation or compilation fails: STOPS IMMEDIATELY.
      │
      ├─▶ 3. Generation Switch (`nixos-rebuild switch`)
      │      Activates the new generation, reloads systemd units, registers bootloader
      │
      └─▶ 4. Automated Post-Switch Health Gate (`scripts/health-check.sh`)
             Executes headless compositor, terminal, and user daemon validation
             ├─▶ All Tests PASS: Logs success, commits git generation
             └─▶ ANY Critical FAIL: Automatically invokes `switch --rollback`!
```

---

## 2. Core Safety Guarantees

1. **Pre-Activation Compilation**: If a syntax error or broken dependency exists, Stage 2 catches it before anything on the live system changes.
2. **Headless Verification**: If an update compiles successfully but causes the compositor or terminal emulator to crash on launch, Stage 4 detects the failure within 5 seconds and rolls back automatically.
3. **Audit Trail**: Every rebuild logs its start time, previous generation number, and git commit hash to `~/.cache/nix_rebuild_log`.

## Related Nodes
- [[Automated Rollback Safeguards]]
- [[Emergency Recovery Protocol]]
- [[Root Flake Topology]]
