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
gameclean -y      # actually delete everything from the preview
gameclean -y -q   # delete, print only the freed size
```

Never run `-y` without reading the preview first.

## What it scans

1. **Orphan Wine prefixes** in `~/Games/prefixes` that no Lutris `.yml` references.
2. **Broken installs** — Lutris entries whose `exe:`/`main_file:` path no longer exists.
3. **Wine `Temp` + shader caches** inside the shared umu/Proton prefix (`~/Games/umu/umu-default`), kept alive because working titles (e.g. FL Studio) rely on it.
4. **Game caches** in `~/.cache` (`lutris`, `winetricks`, `umu`, `rpcs3`, `dxvk`, `dxvk-cache`, `vkd3d`, `winelib`, `gamescope`, `wine`, `steam`).
5. **Stray `drive_c` prefixes** inside product folders anywhere under `~/Games` (junk from failed experiments).

## Safety model

- Working games are **never touched**: a prefix or game dir referenced by an existing Lutris `.yml` (Silksong, GTA:SA, NFS:MW, FL Studio, …) is protected — even broken entries only flag the *yml file itself*, never the referenced game data of other titles.
- The dots of trust are the Lutris entries: `gameclean` parses every `.yml` and builds the referenced set before deciding what is orphaned.
- Preview is the default mode; `-y` exists for after you've read it.

## Implementation notes

- Source: `pkgs/gameclean/gameclean.py` — single stdlib-only Python script, **zero external dependencies** (ships a minimal regex-based Lutris `.yml` parser; supports UTF-8 and UTF-16 entries — Lutris stores several as UTF-16). Handles nested `game:`/`system:` keys with indentation-aware matching and prefix paths with escaped spaces (`gta\\ san` style).
- Packaging: `pkgs/gameclean.nix` pins the shebang to the Nix store `python3`; imported through the flake overlay (`flake.nix`) and exposed on system `PATH` via `environment.systemPackages` in `modules/system/gaming.nix`.
- Python here is acceptable: `gameclean` is an interactive, manually-invoked janitor — **not** a desktop hot path (see `docs/decisions.md`, §4).
