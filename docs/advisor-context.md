# Advisor Context & Architectural Memory

## Display & Shader Architecture Split

- **hyprsunset daemon** owns **Temperature + Gamma** (hardware CTM/gamma LUT).
- **Hyprland's single `decoration:screen_shader` slot** owns **Saturation + Paper Grain + CRT Curvature** together in one unified GLSL file, since Hyprland only supports one active `screen_shader` at a time.
- These two systems are fully independent — verify this separation before adding any new visual effect toggle, to avoid accidentally colliding with whichever mechanism already owns that property.

## Sysfs Inotify & Event Source Watcher Rules

- `FileView` on `/sys` or `/proc` never fires (`sysfs` emits no `inotify` events). Use `udevadm monitor`, UPower D-Bus, or a slow timer. Never replace a udev-based watcher with a `FileView` on sysfs.
- Before replacing any watcher, prove the new event source fires by logging timestamps on a real state change.

## Lockscreen Safety Rule

- **Never test/spawn lockscreen directly/autonomously**: Testing or executing the lockscreen manually breaks the PAM session and session lock state when attempting to log back in.

## Projects Directory Protection Rule

- **Never delete files or directories inside `~/Projects/`**: `~/Projects/` and its subdirectories contain user backups, reference repositories, and independent projects. Never run `rm` or delete paths under `~/Projects/`.



