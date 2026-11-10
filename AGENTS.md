# Antigravity Persistent Rules

Behavior rules only. The single always-loaded file for this repository.

## 1. Operating Rules & Boundaries
- **Scope**: Change only what the task names. Report other problems; do not touch them.
- **Speed**: Be fast—one go, no benchmark rounds, no step-by-step test sessions unless requested.
- **Visual Changes**: Ask before a visual change ONLY if not explicitly requested; otherwise no question rounds. Colors, radius, fonts, and motion come only from tokens (Wallust palette, `Motion.qml`; no literals, no overshoot, time-based). One visual change applies to every widget in its category. Text contrast >= 4.5:1. Never add unrequested status icons into widget pills (e.g. battery pill).
- **Notifications**: 1–3 words with `notify-send -a "<App>"`. Silent for app launches, bar positions, and normal screenshots (notify ONLY on OCR text failure: "No text found"). Never add notifications to apps/shortcuts without explicit permission.
- **Keybind Conventions**: Web apps: `SUPER + ALT + <key>`; daily widgets: 2-button `SUPER + <key>`; secondary widgets: 3-button `SUPER + SHIFT + <key>`; system services: `SUPER + F<n>`. In-widget wallpaper fav toggle is `\`.
- **Privacy & Safety**: Never view screen images, read browser/chat/notes content. Screenshots allowed only when strictly necessary: one instant region capture of the specific widget, deleted immediately after inspection, with a one-line rationale; otherwise ask. Never run or test the lockscreen. Never delete inside `~/Projects`.
- **Code Hygiene**: No Python or Node in owned code except guarded calls to the user-managed wallpaper `auto_organize.py` (keep `python3` available); use Rust, C, bash, jq, awk, or Bun otherwise. No sleep, polling, or hacks in product code (QML timers only for clock ticks and animation gating). 1.5s GPU spacing applies to agent's own test steps (run one at a time); product code drops overlapping requests.
- **State Location**: Persistent state lives in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/` (subfolders by area). Regenerable data goes in `~/.cache`.
- **Modes**: Never toggle or reset Coffee Mode or other user-controlled live modes during agent work. Modes must be a state window rules read, not an imperatively flushed reload. Conflicting modes preempt automatically in a single atomic pass.
- **Verification & Git**: "Verified" requires pasted raw output. Finish tasks with `nix flake check`, then `rebuild`. The helper stages tracked changes, commits, builds, switches, health-checks, and rolls back when needed. Push ONLY when explicitly told. Always state whether `rebuild` is required to apply changes. One agent session per repo. QuickShell reloads only via IPC or `qs_manager.sh reload`.
- **Design & Architecture**: Implement tasks strictly minimal, bloat-free, battery-efficient, and native (zero dead code, unrequested daemons, or heavy languages). Home Manager feature modules own matching services and session state; `desktop.nix` composes general app setup. Figure out best idiomatic NixOS/Hyprland approach from brief intent; keep docs and README strictly accurate.
- **Audio Preferences**: Always keep A2DP stereo (never headset HSP/HFP) and preserve internal-speaker keep-awake behavior (`session.suspend-timeout-seconds=0`; report its idle cost only). The live speaker node reports `node.pause-on-idle=false`, though the repo does not declare that property. Karaoke cuts dead-center lead vocals/crowd (Depth=0.99, LowCutoff=100Hz) while keeping side harmonies/instruments 100% uncompressed (ReverbDuck=0, TransProt=0) with live stage acoustics across Bass/Karaoke/Vocal.
- **Wallpaper Invariants**: Wallpaper picker MUST always center on and display the currently applied desktop wallpaper on open. Sorting MUST strictly adhere to continuous color gradient & type rankings (`sortListModel`: Video -> GIF -> chromatic hue 0°-360° -> monochrome lightness). Video/GIF transitions MUST maintain instant zero-flicker poster frames without black screen flashes. Fav toggle is strictly `\`.
- **Docs Maintenance**: Mandatory pre-commit step: every change MUST atomically update all affected docs (`docs/system.md`, `decisions.md` ADR, `CHANGELOG.md`) and README in the exact same commit without requiring reminders. When user states a rule/preference, add one concise line here immediately, remove duplicates, and keep under ~40 lines.

## 2. Router: When to Read Other Docs
- `docs/system.md`: Read before touching desktop architecture, QuickShell widgets, audio routing, wallpaper backend, or power services.
- `hosts/<host>/PERSONAL.md`: Read when working on machine hardware quirks, display modes, power profiles, or intentional user settings.
- `docs/tacit_knowledge.md`: Read when diagnosing non-obvious bugs, crashes, udev/sysfs quirks, or Wayland/DRM edge cases.
- `docs/monitors_troubleshooting.md`: Read when troubleshooting external displays, docks, mirroring, or output resolution.
- `docs/decisions.md`: Read-only reference for historical architectural decision records (ADRs).
