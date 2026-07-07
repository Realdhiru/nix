My personal declarative configuration for a Wayland-based desktop environment. Built for low latency and reproducibility using Nix Flakes.


## Stack
* **OS:** NixOS
* **WM:** Hyprland
* **UI:** Quickshell (QML)
* **Theming:** Matugen (Dynamic color extraction)
* **Terminal:** WezTerm + Starship
* **Launcher:** Rofi

## Details
The interface is entirely custom-built in QML. To maintain zero UI lag, heavy hardware polling and network executions are decoupled into asynchronous Python/Bash daemons via IPC. Monitor and scaling states are routed through volatile `~/.cache` files to prevent DRM modeset flashes during compositor reloads. 

![Desktop Showcase](https://via.placeholder.com/1200x675/1e1e2e/cdd6f4?text=Insert+Screenshot+Here)