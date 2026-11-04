# Antigravity Persistent Rules

Behavior rules only. The single always-loaded file for this repository.

## 1. Operating Rules & Boundaries
- **Scope**: Change only what the task names. Report other problems; do not touch them.
- **Speed**: Be fast—one go, no benchmark rounds, no step-by-step test sessions unless requested.
- **Visual Changes**: Ask before a visual change ONLY if not explicitly requested; otherwise no question rounds. Colors, radius, fonts, and motion come only from tokens (Wallust palette, `Motion.qml`; no literals, no overshoot, time-based). One visual change applies to every widget in its category. Text contrast >= 4.5:1. Notifications: 1–3 words with `notify-send -a "<App>"`.
- **Privacy & Safety**: Never view screen images, read browser/chat/notes content. Screenshots allowed only when strictly necessary: one instant region capture of the specific widget, deleted immediately after inspection, with a one-line rationale; otherwise ask. Never run or test the lockscreen. Never delete inside `~/Projects`.
- **Code Hygiene**: No Python or Node in anything we own (use Rust, C, bash, jq, awk, or Bun). No sleep, polling, or hacks in product code (QML timers only for clock ticks and animation gating). 1.5s GPU spacing applies to agent's own test steps (run one at a time); product code drops overlapping requests.
- **State Location**: Persistent state lives in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/` (subfolders by area). Regenerable data goes in `~/.cache`.
- **Modes**: Modes must be a state window rules read, not an imperatively flushed reload. Conflicting modes preempt automatically in a single atomic pass.
- **State Settle**: State settle belongs in event signals, never in timers or polling loops.
- **Verification & Git**: "Verified" requires pasted raw output. Finish tasks with `nix flake check`, then `rebuild "<commit message>"`. Run the flake check; it enforces the rules. Commit only the task's files with a clear message; push ONLY when explicitly told. One agent session per repo. QuickShell reloads only via IPC or `qs_manager.sh reload`.
- **Docs Maintenance**: Automatically update wrong or newly relevant docs and CHANGELOG (one line per change) without prompting or bloating; keep concise. When user states a rule/preference, add one concise line here, remove duplicates, and keep under ~40 lines.

## 2. Router: When to Read Other Docs
- `docs/system.md`: Read before touching desktop architecture, QuickShell widgets, audio routing, wallpaper backend, or power services.
- `hosts/<host>/PERSONAL.md`: Read when working on machine hardware quirks, display modes, power profiles, or intentional user settings.
- `docs/tacit_knowledge.md`: Read when diagnosing non-obvious bugs, crashes, udev/sysfs quirks, or Wayland/DRM edge cases.
- `docs/monitors_troubleshooting.md`: Read when troubleshooting external displays, docks, mirroring, or output resolution.
- `docs/decisions.md`: Read-only reference for historical architectural decision records (ADRs).
