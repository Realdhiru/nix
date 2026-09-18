# Documentation Rules for Future Agents

How to work in this repo as an AI assistant. Follow this before making any
change or writing any doc.

## Mandatory reading order

1. `docs/README.md` — map of the system and where things live.
2. `docs/decisions.md` — **required before touching power, audio, wallpaper,
   or quickshell.** The golden rules there are earned the hard way; violating
   them silently breaks the rice.
3. `docs/flow.md` — only if the task touches an existing flow.

## The code is authoritative

- Docs can lag or be wrong. When code and docs disagree, **trust the code**,
  fix the doc, and add a `> **Superseded:**` note explaining what changed.
- Never "simplify" a path or a command in a shell script without checking for
  runtime redefinition of `SCRIPT_DIR` and other variables (see the
  ddg_search regression, top of decisions.md). `bash -x` beats static
  analysis.
- Never delete a decision or a debugging doc — supersede with a note.

## When to update docs

A doc change ships with every **meaningful** change:

- New decision or reversal → new entry at the top of `decisions.md`.
- New/changed execution path → update `flow.md`.
- New subsystem doc → add a row to the README index (and to
  `AGENTS-DOCUMENTATION.md`? No — README only) with a Status line:
  `Status: CURRENT | CLOSED | HISTORICAL | INVESTIGATION | SUPERSEDED`
- After a debug session that proved something → new/updated `debugging/`
  doc, or mark the existing one CLOSED.

## Writing style

- Terse, factual, no fluff. Evidence over claims (logs, `bash -x`, timings).
- Preserve the "rejected approaches" — they are the cheapest insurance
  against regressions.
- Exact paths, exact file:line, exact command names. No approximations.
- Mark unknowns with `[UNKNOWN — needs verification]`; never fabricate.
- Prefer updating existing docs over spawning new ones. No doc sprawl.

## Ownership / hard rules to never break

| Rule | Source |
|---|---|
| Lid NEVER suspends (`HandleLidSwitch=ignore`) | decisions.md / AGENTS.md |
| apply_profile.sh is the only profile writer; no `tlp ac/bat` from it | decisions.md |
| udev rule is the sole AC/BAT authority | power.nix comment |
| EPP: set governor first | decisions.md |
| EasyEffects: presets in `~/.local/share/easyeffects/output`, liveness via systemctl, handoff not spawn | decisions.md |
| workspaces.sh exit 7 → don't respawn | AGENTS.md |
| Never rebuild without preserving/identifying the previous known-good generation; `rebuild()` + `health-check.sh` is the only sanctioned path; never run `nixos-rebuild switch` directly for routine changes | decisions.md 2026-08-16 / AGENTS.md |
| docs/ is local-only — never stage or commit it | README.md |

## Verification before declaring done

- QML: `nix build .#checks.x86_64-linux.qml-lint`
- Nix: `sudo nixos-rebuild dry-run --flake .#nixos`
- Shell: run with `bash -x` and check the effective path/args, not just
  exit status.
- State files: check `~/.cache`, `~/.local/state/quickshell`,
  `~/.local/share/easyeffects/output` — many scripts write state that a
  rebuild must not clobber.
- Ask before installing anything or changing system config (user rule).
