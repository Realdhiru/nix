---
title: Application Packaging - Derivations, FHS, AppImage, and Wrappers
tags: [nix, packaging, derivations, fhs, appimage, electron, wrappers]
---

# Application Packaging in NixOS: Derivations, FHS Environments, AppImages, and Wrappers

The most common question developers ask when encountering NixOS is:
> *"How do I run an arbitrary piece of software if there is no `/usr/bin`, no `/lib64`, and running `./my-binary` crashes with `No such file or directory`?"*

In traditional Linux, dynamic binaries expect the dynamic linker at `/lib64/ld-linux-x86-64.so.2` and search standard FHS paths (`/usr/lib`, `/lib`). In NixOS, the standard FHS directory structure does not exist. Every dynamic library lives under an isolated hash path in `/nix/store/`.

This document details the **four distinct architectural mechanisms** used in this system to run, package, and adapt software, along with concrete cases, observations, and engineering trade-offs.

---

## 1. Mechanism 1: Native Package Derivations and `autoPatchelfHook`

### How It Works
When software is packaged natively (or when packaging proprietary binaries like Slack, Discord, or Obsidian):
1. Nix builds a derivation (`stdenv.mkDerivation`).
2. `autoPatchelfHook` inspects the ELF header of the pre-compiled binary.
3. It rewrites the binary's `PT_INTERP` (the dynamic loader path) from `/lib64/ld-linux-x86-64.so.2` to the exact glibc loader inside the Nix store (`/nix/store/<hash>-glibc/lib/ld-linux-x86-64.so.2`).
4. It inspects all `DT_NEEDED` dynamic library dependencies (e.g. `libX11.so`, `libGL.so`) and injects their exact Nix store paths into the binary's `DT_RUNPATH`.

### Applied Case in Our System: `obsidian`
Inspecting Nixpkgs' derivation for Obsidian (`package.nix`):
```nix
nativeBuildInputs = [ autoPatchelfHook makeWrapper asar ];
```
Nix unpacks upstream's `.tar.gz`, patches the embedded binaries, wraps Electron with Wayland flags, and outputs a self-contained closure.

### Trade-offs
- **Advantages**: Purest Nix architecture; zero runtime container overhead; exact dependency tracking; seamless integration with system themes.
- **Downsides**: Packaging complex software with hidden shared library calls requires tedious tracking of `buildInputs`. If an upstream binary attempts `dlopen()` on an unpatched `.so` at runtime, it crashes.

---

## 2. Mechanism 2: FHS User Environments (`buildFHSEnv`)

### How It Works
For proprietary, highly dynamic software that downloads unpatched binaries at runtime (e.g. Steam, Claude Desktop, IntelliJ language plugins):
- Nix uses Linux kernel namespaces (`user_namespaces`, `mount_namespaces`) to construct a transient, chrooted FHS directory tree in memory.
- Inside the environment, `/lib64`, `/usr/lib`, and `/usr/bin` exist and point to Nix store libraries.
- The binary executes inside this sandbox, believing it is running on a standard Ubuntu or Arch system.

### Applied Case: Steam and Claude Desktop
In our separate repository (`Realdhiru/claude-desktop-nix`), Claude Desktop unpacks the official Ubuntu `.deb` and wraps it in `buildFHSEnv`:
- Claude spawns language servers, QEMU microVMs, and node runtimes that expect standard `/usr/bin/env` paths.
- Running inside an FHS wrapper allows these dynamic processes to spawn without manual patching.

### Trade-offs
- **Advantages**: Runs proprietary, closed-source binaries that cannot be easily patchelfed; isolates foreign filesystem expectations.
- **Downsides**: Increases disk usage (pulls full FHS glibc closures); introduces subtle inter-process communication hurdles when interfacing with host Wayland sockets or input methods.

---

## 3. Mechanism 3: Kernel-Level AppImage Execution (`binfmt_misc` + `appimage-run`)

### How It Works
AppImages bundle an application and its core dependencies into a self-mounting squashfs image. In traditional NixOS, double-clicking an AppImage fails because its internal runtime launcher expects `/lib64/ld-linux-x86-64.so.2`.

We solve this declaratively at the kernel level in `modules/system/packages.nix`:
```nix
programs.appimage = {
  enable = true;
  binfmt = true;
};
```
1. NixOS registers the AppImage ELF binary header signature with the Linux kernel's `binfmt_misc` subsystem.
2. Whenever the kernel encounters an executable matching the AppImage magic byte signature, it intercepts the `execve` syscall and routes execution through `appimage-run`.
3. `appimage-run` extracts the squashfs payload into a temporary FHS user namespace and executes it.

### Applied Case: Ad-Hoc Creative Tools and CAD
When running experimental tools or portable utilities (e.g., custom slicing engines or standalone emulators) that are not packaged in Nixpkgs:
- We can download an `.AppImage` directly and execute it via `chmod +x tool.AppImage && ./tool.AppImage`.
- No Nix code, derivation writing, or rebuild required.

### Trade-offs
- **Advantages**: Instant execution of portable Linux binaries without maintaining derivations.
- **Downsides**: Imperative and unmanaged; does not benefit from Nix garbage collection or declarative locking.

---

## 4. Mechanism 4: Program Wrappers (`makeWrapper` / `symlinkJoin`)

### How It Works
Often a package is already compiled and available in Nixpkgs, but requires specific environment variables, plugin paths, or CLI flags to function correctly in our Wayland desktop.

Instead of recompiling the package from source (which would require hours of compilation), we use `symlinkJoin` and `makeWrapper` to generate a lightweight shell wrapper around the binary.

### Applied Case 1: `quickshellWrapped` (`modules/system/packages.nix`)
QuickShell's stock upstream package only links against standard Qt modules (`qtbase`, `qtdeclarative`, `qtwayland`). Our lockscreen (`Lock.qml`) requires `QtMultimedia` to render hardware-accelerated video wallpapers.

Rather than rebuilding QuickShell from C++ source, we wrap it:
```nix
let
  qtmultimedia = pkgs.qt6Packages.qtmultimedia;
  quickshellWrapped = pkgs.symlinkJoin {
    name = "quickshell-wrapped";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/quickshell \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH ':' "${qtmultimedia}/lib/qt-6/qml" \
        --prefix QT_PLUGIN_PATH ':' "${qtmultimedia}/lib/qt-6/plugins"
    '';
  };
in ...
```
- Compilation time: **0 seconds** (instant symlink join).
- Result: QuickShell launches with `QtMultimedia` plugins available in its search path.

### Applied Case 2: Upstream `obsidian` Wayland Wrapper
In Nixpkgs' official `obsidian` package:
```bash
makeWrapper ${electron}/bin/electron $out/bin/obsidian \
  --add-flags "\${NIXOS_OZONE_WL:+\${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-wayland-ime=true --wayland-text-input-version=3}}"
```
By setting `NIXOS_OZONE_WL = "1"` in `hosts/nixos/default.nix`, the wrapper detects the variable and injects native Wayland flags at startup.

---

## 5. Architectural Decision Matrix

| Mechanism | When to Use | Performance Cost | Maintenance Effort |
| :--- | :--- | :--- | :--- |
| **Native Derivation + `autoPatchelfHook`** | Standard software packaged in Nixpkgs or stable open/closed source binaries | Zero overhead | Medium (defining buildInputs) |
| **`buildFHSEnv`** | Complex software downloading foreign binaries (Steam, Claude Desktop) | Low (namespace mount) | Low once defined |
| **`programs.appimage` (`binfmt_misc`)** | Quick one-off execution of standalone portable tools | Low (squashfs mount) | Zero (system feature flag) |
| **`makeWrapper` / `symlinkJoin`** | Injecting runtime env vars, search paths, or flags into existing packages | Zero (shell wrapper) | Very Low (minutes to write) |

## Related Nodes
- [[Host Configuration Anatomy]]
- [[Flake Self-Hosting Architecture]]
- [[MPV MPRIS Pipeline]]
