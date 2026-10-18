---
title: Host Configuration Anatomy
tags: [architecture, hardware, intel, kernel, bootloader, oled]
---

# Host Configuration Anatomy

The host configuration located in `hosts/nixos/default.nix` defines the low-level operating system configuration for our physical machine: **ASUS Vivobook S 15 OLED (K5504VA / S5504VA)** powered by an **Intel Core i5-13500H** processor and Intel Iris Xe Graphics.

---

## 1. Intel Graphics Early KMS and Fastboot

By default, the Linux kernel initializes display modesetting late in user space (stage 2). This causes an unsightly screen flicker and causes the ASUS UEFI splash logo to flash twice during boot.

We eliminated this via kernel parameters and initrd configuration:
```nix
# Force stage-1 initrd to load the Intel display driver immediately:
boot.initrd.kernelModules = [ "i915" ];

# Kernel parameters:
boot.kernelParams = [
  "i915.fastboot=1"        # Preserves UEFI GOP framebuffer without mode re-initialization
  "i915.enable_fbc=1"       # Enables Framebuffer Compression, saving ~2.2 GB/s memory bandwidth
  "i915.enable_psr=1"       # Panel Self Refresh for OLED battery conservation
  "resume_offset=39880704"  # Physical swapfile offset for instant disk hibernate resume
];
```

---

## 2. System-Wide Native Wayland Backend

Rather than writing per-application wrapper scripts for Chromium and Electron applications, we declare the backend globally at the system session level:
```nix
environment.sessionVariables = {
  LIBVA_DRIVER_NAME = "iHD"; # Intel Iris Xe VA-API hardware video decode driver
  NIXOS_OZONE_WL = "1";     # Instructs Chromium/Electron wrappers to run natively on Wayland
};
```
Because Nixpkgs wrappers inspect `NIXOS_OZONE_WL`, packages like **Obsidian**, **Brave**, **ChatGPT**, and **Discord** automatically append `--ozone-platform=wayland` and `--enable-wayland-ime=true` with zero custom wrapper maintenance.

---

## 3. Storage and Swap Architecture

- **Root Filesystem**: Ext4 on NVMe with standard discard mounts.
- **Swapfile**: 16GB dedicated swapfile (`/swapfile`) paired with `boot.resumeDevice`. Configured to support clean system hibernation during critical low-battery events without unannounced shutdowns.

## Related Nodes
- [[TLP Exclusive Authority]]
- [[ASUS Hardware Quirks]]
- [[Root Flake Topology]]
