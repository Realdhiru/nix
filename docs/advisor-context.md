# Advisor Context

Use this short file as an entry point when giving an external AI context about
the desktop. Repository agents should follow [`AGENTS.md`](../AGENTS.md) and
the [NixOS / Hyprland skill](../.agents/skills/nixos-hyprland/SKILL.md) as the
operational source of truth.

## Display shader ownership

- `hyprsunset` owns display temperature and gamma through the hardware CTM/LUT.
- Hyprland's single `decoration:screen_shader` slot owns saturation, paper
  grain, and CRT curvature together in one GLSL shader.
- These are separate mechanisms. A new display effect must use the slot that
  owns that property and must not replace the other subsystem's configuration.

See [`decisions.md`](decisions.md) for the architectural rationale and
[`debugging.md`](debugging.md) for past failures and verified recovery steps.
