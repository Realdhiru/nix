# NixOS Rice — Documentation Home

Read this first. It maps the configuration so you know where things live and
what is safe to change.

> **Scope note:** `docs/` is **local-only** — intentionally excluded from the
> GitHub repo (`.gitignore` rule `docs/`). These docs describe the *current
> disk state* (`~/nix`), which may lag or lead the pushed repo.
> **The code is always authoritative.** When a doc disagrees with code,
> trust the code and mark the doc's contradiction (see
> `AGENTS-DOCUMENTATION.md`).

---

## System at a glance

- Host: `nixos` (hostname `NixOS`), ASUS Vivobook K5504VA, x86_64
- NixOS unstable, flakes, Home Manager (user `realdhiru`)
- WM: Hyprland + Quickshell (TopBar + popups), Hyprlock via in-tree lock.sh
- Sole power manager: TLP + ASUS udev rule; lid NEVER suspends
- Desktop-visible power profile: `apply_profile.sh` (single source of truth)

## Repo layout

```
~/nix/
├── flake.nix                  # inputs, overlays, home-manager wiring, qml-lint check
├── hosts/nixos/
│   ├── default.nix            # host config: imports modules, graphics, env
│   └── hardware-configuration.nix
├── modules/
│   ├── system/
│   │   ├── boot.nix           # bootloader, kernel params, ZRAM
│   │   ├── services.nix       # pipewire, bluetooth, printing, polkit, logind
│   │   ├── packages.nix       # packages + quickshellWrapped
│   │   ├── power.nix          # TLP config (SOLE tlp ac/bat authority)
│   │   └── fonts.nix / gaming.nix / users.nix
│   └── home/
│       ├── shell.nix          # zsh, rebuild() helper
│       ├── theme.nix          # GTK/Qt themes, matugen palette, dark mode
│       └── spicetify.nix      # spicetify-nix flake + extensions
├── home.nix                   # dotfile symlinks, systemd user services, EasyEffects
├── pkgs/                      # local packages (buuf-nestort icon theme, pcmanfm patch)
├── dotfiles/                  # mkOutOfStoreSymlink'd live configs
│   ├── hypr/                  # Lua hyprland configs, scripts/, shaders/
│   ├── fuzzel/ wezterm/ fastfetch/ matugen/
└── docs/                      # THIS directory (local-only)
```

### Config flow

```
flake.nix
  ├── hosts/nixos/default.nix ── system modules ── nixos-rebuild switch
  └── home.nix ── home-manager (shared modules incl. spicetify)
        └── xdg.configFile ── mkOutOfStoreSymlink → ~/nix/dotfiles/<app>
```

Everything under `dotfiles/` is symlinked (out-of-store), so edits apply
**immediately without rebuild** — but nothing about dotfiles is declarative
beyond the symlink itself.

## Startup sequence (Hyprland)

See `startup.conf` — order matters:

1. `dbus-update-activation-environment` (Wayland → D-Bus for notifications)
2. `killall -q dunst mako swaync hyprnotify` (free D-Bus namespace for Quickshell)
3. `lock.sh` (Hyprlock + lockscreen quickshell instance)
4. `boot_wallpaper.sh` (login wallpaper; warm-cache push ~0.2s vs cold ~27s)
5. `hypridle`, `cliphist` (text+image), `quickshell Shell.qml`, `equalizer.sh --init`, `setcursor`, `lid-monitor.sh`

## Quickshell layout

```
Shell.qml ── Main.qml (StackView: cache-then-push)
  ├── TopBar.qml          # bars + wsDaemon + NotifTicker (live notifier)
  ├── Floating.qml        # popup roots (layoutWidth/layoutHeight required!)
  ├── Lock.qml            # separate quickshell instance via lock.sh + WlSessionLock
  ├── SysData.qml         # power-profile picker → apply_profile.sh
  ├── MatugenColors.qml   # qs_colors.json consumer
  ├── Caching.qml / Config.qml / Scaler.qml
  ├── watchers/           # per-widget Process watchers (killed by reload.sh)
  └── <subsystem dirs>/   # battery, volume, music, network, wallpaper, focustime,
                          # monitors, calendar, clipboard, quickactions, notifications
```

Popups are toggled via `qs_manager.sh` (IPC into Main.qml; respawns shell if dead).

## Live daemons / services (systemd user)

| Service | Purpose | Notes |
|---|---|---|
| `focustime-daemon` | active-window tracker → state files | Restart=always; widget refuses stale state (date match) |
| `easyeffects` (HM) | EQ host, `--load-preset live_eq` | equalizer.sh only *hands off* preset loads |
| `vscodium-settings-sync` | live VSCodium settings → repo | sole trigger, never rebuilds |
| `playerctld` | MPRIS player detection | music widgets |
| `polkit-gnome-authentication-agent-1` | polkit agent (system) | |

Shell scripts: `workspaces.sh` (wsDaemon, flock contract: exit 7 = lost lock, do NOT respawn), `lid-monitor.sh` (udevadm-driven, no polling), `osd.sh` (volume/brightness OSD), `apply_profile.sh` (profile), `ensure_awww.sh` (awww daemon lifecycle, single owner).

## Rebuild & verification

- `rebuild <msg>` (zsh helper): `git add -A` → commit → `sudo nixos-rebuild switch --flake .#nixos`
- Dry check: `sudo nixos-rebuild dry-run --flake .#nixos`
- QML lint: `nix build .#checks.x86_64-linux.qml-lint` (fails on unresolved attached properties)
- Reload quickshell without rebuild: `reload.sh` (pkill watchers first, then respawn shell)

## Documentation index

### Read-first
- `README.md` (this file)
- `decisions.md` — why things are the way they are (READ before touching power/audio/wallpaper)
- `flow.md` — execution flows for every subsystem

### Keep current
- `AGENTS-DOCUMENTATION.md` — rules for future AI/agents working in this repo

### Subsystem docs (`debugging/`)

| Doc | Status | Topic |
|---|---|---|
| `010-debug-brightness-ab.md` | CLOSED | ASUS brightness keys after hibernate → asus-brightness-rebind.nix |
| `2026-08-awww-daemon.md` | CURRENT | mpvpaper daemon lifecycle, 10-bit `--format xrgb` |
| `2026-08-quickshell-popup-layout-corruption.md` | CURRENT | popup root width/height → layoutWidth/layoutHeight |
| `2026-08-lockscreen-live-wallpaper-and-search-thumbnails.md` | CURRENT | Lock.qml live wallpaper; **ddg_search path section superseded** |
| `2026-08-wallpaper-login-delay.md` | CURRENT | boot_wallpaper.sh login path, warm/cold cache |
| `2026-08-spotify-renderer-gpu-profile.md` | INVESTIGATION | GPU vs CPU renderer measurements, no change made |
| `2026-08-liquify-config-reproducibility.md` | CURRENT | Liquify V2 = localStorage leveldb seeding |
| `2026-08-gtk-theme-env-channel.md` | CURRENT | only GTK_THEME env works; portal 2nd-display bug |
| `2026-08-focustime-daemon-lifecycle.md` | CURRENT | systemd user service, stale-state refusal |
| `2026-08-coffee-mode-idle-inhibit.md` | CURRENT | SUPER CTRL I → systemd-inhibit |
| `2026-08-spicy-lyrics-popup-freeze.md` | CURRENT | rAF fallback extension |
| `2026-08-audit-and-reimplementation.md` | HISTORICAL | 4 commits (2a099f8…) reverted; both audits' consolidated history |

## Persistent state (NOT declarative — do not nuke blindly)

| Path | Owned by |
|---|---|
| `~/.cache/current_wallpaper.txt` | set_wallpaper.sh — active wallpaper |
| `~/.cache/qs_pre_saver_shader.conf` | apply_profile.sh — pre-saver shader + power-saver flag |
| `~/.cache/hypr_power_monitor.conf`, `~/.cache/current_shader.conf` | home.nix activation (touch) |
| `~/.cache/matugen/qs_colors.json` (+`.tmp`) | extract_raw_colors.sh — atomic |
| `~/.local/state/quickshell/focustime` | focus_daemon.py |
| `~/.cache/spotify/Default/Local Storage/leveldb` | Liquify V2 state |
| `~/.local/share/easyeffects/output` | EasyEffects presets (NOT ~/.config!) |
| `~/.local/state/quickshell/` (run dirs) | watchers/daemons |

## Golden rules (proven the hard way)

1. Lid NEVER suspends. `HandleLidSwitch = "ignore"` stays. Suspend is manual (`Shift+Esc`).
2. `apply_profile.sh` never calls `tlp ac/bat`; the ASUS udev rule in power.nix is the sole AC/BAT authority.
3. EPP writes are refused (EBUSY) while governor=performance — set governor first (`set_epp.sh`).
4. EasyEffects presets live in `~/.local/share/easyeffects/output`; liveness via `systemctl --user is-active`.
5. `workspaces.sh` exit 7 = lost flock → TopBar must NOT respawn.
6. Quickshell `Repeater.model` compares arrays by identity — use canonical `readonly property var` constants.
7. Lock wallpaper is drawn INSIDE Lock.qml (own quickshell instance), never a separate window.
8. `caching.sh` **redefines `SCRIPT_DIR`** when sourced — paths in sourced scripts must be nested from the scripts root, not the script's own dir. (See the ddg_search regression in decisions.md.)
9. `docs/` stays local-only. Never commit it.

See `decisions.md` for the reasoning behind each.
