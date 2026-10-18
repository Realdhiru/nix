---
title: Lua Configuration Model
tags: [hyprland, lua, configuration, modularity, refactoring]
---

# Lua Configuration Model: Modularizing Hyprland

Standard Hyprland setups rely on a single, monolithic configuration file: `hyprland.conf`.

As configurations scale to accommodate dozens of application rules, dynamic monitor geometries, and complex keybindings, monolithic configuration files suffer from syntax brittleness, merge conflicts, and zero programming logic.

We migrated our entire Hyprland configuration to native **Lua modules**.

---

## 1. Directory Structure and Module Boundaries

Our configuration resides under `dotfiles/hypr/` and is structured into logical sub-domains:

```
dotfiles/hypr/
├── hyprland.lua       # Root orchestrator; imports all child modules
├── env.lua            # Toolkit, Wayland, and XDG environment variables
├── startup.lua        # Sequential daemon startup sequence
├── keybinds.lua       # Keyboard and trackpad shortcut bindings
├── rules.lua          # Window rules, floating dimensions, and opacity tiers
├── appearance.lua     # Bezier curves, animations, gaps, and borders
├── input.lua          # Trackpad gestures, natural scroll, and repeat rates
└── misc.lua           # Direct scanout, tearing, and VRR settings
```

---

## 2. Architectural Advantages of the Lua Backend

### 1. Dynamic Evaluation Logic
In standard `hyprland.conf`, you cannot evaluate conditions based on filesystem markers or power states. In `rules.lua`, we execute real runtime checks:
```lua
-- Dynamically determine if windows should be opaque:
local function is_solid_mode()
    local state = read_cache_file("state.json")
    return state.gaming or state.wallpaper_killed or state.profile == "power-saver"
end

if is_solid_mode() then
    hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override" })
else
    hl.window_rule({ match = { class = "^(Alacritty)$" }, opacity = "0.70" })
    hl.window_rule({ match = { class = "^(obsidian)$" }, opacity = "0.65" })
    hl.window_rule({ match = { class = "^(antigravity)$" }, opacity = "0.47" })
end
```

### 2. Isolated Hot-Reloading
Because `dotfiles/hypr` is symlinked via `mkOutOfStoreSymlink`, editing any Lua file takes effect instantly when executing `reload.sh` (`SUPER + R`). The configuration reloads in ~15ms without unmapping Wayland surfaces or restarting user applications.

## Related Nodes
- [[Hyprland Architecture]]
- [[Compositor Rules & Opacity]]
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
