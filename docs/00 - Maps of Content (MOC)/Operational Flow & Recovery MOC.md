---
title: Operational Flow & Recovery Map of Content
type: moc
tags: [moc, workflow, rebuild, recovery, index]
---

# Operational Flow and Recovery Map of Content

The engineering safety pipeline that guarantees system stability.

---

## Core Documents

1. [[The rebuild() Function]]
   - 4-stage atomic pipeline: format, dry-build gate, generation switch, and health check.
   - Automated git staging and generation logging.

2. [[Automated Rollback Safeguards]]
   - Headless test harness verifying compositor socket, Alacritty terminal sandbox, and systemd units.
   - Automated rollback trigger within 3 seconds of runtime failure.

3. [[Emergency Recovery Protocol]]
   - Keybinding emergency escapes (QuickShell cold restart, ALSA/HDA audio driver unbind).
   - Low-level TTY recovery runbook.

## Related Domains
- [[Flake & System Architecture MOC]]
- [[System Architecture MOC]]
