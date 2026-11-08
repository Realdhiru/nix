# `gameclean` — Wine/Proton/Lutris Storage Janitor

A Nix-distributed helper binary (`pkgs/gameclean.nix`, wired via the flake overlay into `modules/system/gaming.nix`) that finds and removes Wine/Proton/Lutris **leftover files** — the junk that scattered installs leave behind after a game is uninstalled or a launch attempt fails.

## Why it exists

Wine games never live in one folder. When you install (or fail to install) a Wine/Proton title, files land in **five separate locations**:

| Location | What lands there |
| :--- | :--- |
| `~/Games/<title>/` | The game files themselves |
| `~/Games/prefixes/<name>/` | Wine prefix — fake Windows `C:` drive, registry, AppDefault entries |
| `~/Games/umu/umu-default/` | Shared umu/Proton prefix (`Temp`, shader caches) |
| `~/.cache/{lutris,winetricks,umu,dxvk,rpcs3,steam,...}` | Compiler/shader/installer caches (multi-GB) |
| `~/.local/share/lutris/games/*.yml` | Lutris launch entries |

Deleting only the game folder leaves the prefix, caches, and Lutris entry behind — which is how a few failed installs quietly cost tens of GB. `gameclean` finds all of it in one pass. **Run it after every game uninstall or failed launch attempt.**

## Usage

```bash
gameclean         # preview — safe, deletes nothing
gameclean -y      # delete safe candidates from the preview
gameclean -y -q   # delete, print only the freed size
gameclean -y --include-unmanaged-prefixes  # also opt in to unreferenced or stray prefixes
```

Never run `-y` without reading the preview first.
Unreferenced or stray prefixes are preserved by default because they may be used by
Steam, umu, or a manually managed Wine setup that has no Lutris entry. If any
are present, `-y` refuses the entire deletion pass unless the explicit
`--include-unmanaged-prefixes` option is supplied. Nested cleanup candidates
are counted and deleted once through their selected ancestor.

## What it scans

1. **Orphan Wine prefixes** in `~/Games/prefixes` that no Lutris `.yml` references.
2. **Broken installs** — Lutris entries whose `exe:`/`main_file:` path no longer exists.
3. **Wine `Temp` + shader caches** inside the shared umu/Proton prefix (`~/Games/umu/umu-default`), kept alive because working titles (e.g. FL Studio) rely on it.
4. **Game caches** in `~/.cache` (`lutris`, `winetricks`, `umu`, `rpcs3`, `dxvk`, `dxvk-cache`, `vkd3d`, `winelib`, `gamescope`, `wine`, `steam`).
5. **Stray `drive_c` prefixes** inside product folders anywhere under `~/Games` (junk from failed experiments).

## Safety model

- Working games are **never touched**: a prefix or game dir referenced by an existing Lutris `.yml` (Silksong, GTA:SA, NFS:MW, FL Studio, …) is protected — even broken entries only flag the *yml file itself*, never the referenced game data of other titles.
- The dots of trust are the Lutris entries: `gameclean` parses every `.yml` and builds the referenced set before deciding what is orphaned.
- Preview is the default mode; `-y` exists for after you've read it. Deleting
  unreferenced or stray prefixes needs the separate `--include-unmanaged-prefixes`
  opt-in.

- Source: `pkgs/gameclean/gameclean.sh` — Bash script using the packaged coreutils and gawk tools, with no Python or Node. Reads Lutris prefix and executable fields, including escaped spaces in paths.
- Packaging: `pkgs/gameclean.nix` wraps the script with `coreutils` and `gawk`; imported through the flake overlay (`flake.nix`) and exposed on system `PATH` via `environment.systemPackages` in `modules/system/gaming.nix`.
- Zero-Python compliance: fully adheres to the repo-wide rule banning Python in owned code.
