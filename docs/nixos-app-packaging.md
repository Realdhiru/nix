# Packaging & Maintaining Third-Party Apps on NixOS (`.deb` / `.rpm` / AppImage)

A practical guide: how to run a Linux app that only ships as a distro-specific
`.deb`, why the usual workarounds (Podman/Distrobox, `appimage-run`) are often
overkill, and how to wrap it as a **first-class Nix package** that you rebuild,
update, and maintain with the rest of your flake.

> **Case study throughout:** the official **ChatGPT / Codex desktop** app
> (`chatgpt_amd64.deb`). Since §7 it lives in a **standalone, publishable flake**
> at [`~/Projects/codex-flake`](file:///home/realdhiru/Projects/codex-flake)
> ([`pkgs/chatgpt.nix`](file:///home/realdhiru/Projects/codex-flake/pkgs/chatgpt.nix)),
> which `~/nix` consumes as a flake input.

---

## 0. TL;DR

1. A `.deb` is just `ar` archive → `control.tar.xz` + `data.tar.xz`.
2. Extract it with `dpkg-deb -x`, then wrap the app binary in a **`buildFHSEnv`**
   that supplies the libraries the app expects under `/usr/lib`.
3. Declare it as a normal derivation, register it in a flake **overlay**, add it
   to `environment.systemPackages`, rebuild.
4. Maintain it by bumping the pinned `sha256` (+ `version`) in one file.

No container, no runtime daemon, no root, no `/etc/os-release` hacks.

---

## 1. Why distro binaries don't "just run" on NixOS

NixOS intentionally breaks the assumptions a `.deb`/`.rpm` app makes:

| The app assumes | NixOS reality |
| :--- | :--- |
| `/lib64/ld-linux-x86-64.so.2` exists | Dynamic linker lives in `/nix/store/…-glibc/lib` |
| Libraries in `/usr/lib`, `/lib` | Everything is in the read-only Nix store |
| `/bin/sh`, `/usr/bin/env` present | Only `PATH`-provided; `/bin` is minimal |
| It can `apt install` its `Depends` | No package manager; deps must be declared in Nix |
| Mutable `/usr/share` for `.desktop`, icons | Merged from store paths via a profile |

The ELF binary itself is usually **not** broken — its *interpreter* and the
contents of its `DT_NEEDED` search path are. Two categories of fix exist:

- **Make the binary run in a fake FHS** → `buildFHSEnv` (what we use here).
- **Rewrite the binary's paths into the store** → `autoPatchelfHook` (great for
  self-contained binaries; harder when there are hundreds of bundled `.so`s and
  a hardcoded `/usr/lib` prefix, as with Electron/Chromium bundles).

### Alternative approaches and when they fit

| Approach | How | Best for | Downside |
| :--- | :--- | :--- | :--- |
| `buildFHSEnv` | fake `/usr`, `/lib`, `bwrap` sandbox | GUI apps with many deps + bundled libs | larger closure; needs unprivileged userns |
| `autoPatchelfHook` | rewrite `DT_NEEDED`/interpreter to store | single static-ish binaries, CLI tools | breaks if app hardcodes `/usr/lib` at runtime |
| `nix-ld` | provides `/lib64/ld-linux…` + `LD_LIBRARY_PATH` bridge | quick one-off binaries, AppImages | system-wide interpreter shim; deps still manual |
| `programs.appimage` | binfmt + FUSE run | true AppImages only | `.deb`/`.rpm` aren't AppImages |
| Distrobox / Podman | run a full Ubuntu container | complex apps, many runtime deps | background daemon/overhead, weaker isolation integration |
| `steam-run` / `buildFHSEnv` | reusable FHS | generic | not declaratively tied to your config |

**Rule of thumb:** for a *GUI Electron/Chromium/Qt app shipped as `.deb`*, use
`buildFHSEnv`. You already enabled `programs.appimage` and Distrobox in this repo
(`decisions.md` §7); the FHS wrapper is the lighter, daemonless sibling.

---

## 2. Case study — the ChatGPT/Codex desktop app

**The problem:** the user wanted the official GUI (`pkgs.chatgpt`). But:

- nixpkgs `chatgpt` is **macOS-only** (`meta.platforms = ["aarch64-darwin"]`) →
  evaluates to *"not available on `x86_64-linux`"*.
- OpenAI ships Linux as **`.deb`/`.rpm` only** (no nixpkgs, no AppImage, no source).
- Some third-party flakes tried it, but were unverifiable / pinned to a stale
  Electron and not trustworthy to build.

**The solution:** treat the vendor `.deb` as the source and wrap its bundled
Chromium app in an FHS environment.

```
fetchurl (pinned sha256)          # download the .deb deterministically
      │
      ▼
dpkg-deb -x  (stdenv.mkDerivation)  # unpack to $out/usr/…
      │
      ▼
buildFHSEnv                        # fake /usr,/lib + bwrap, targetPkgs = deps
      │   runScript = …/usr/lib/chatgpt/ChatGPT
      ▼
symlinkJoin                        # merge in real .desktop + icon
      │
      ▼
flake overlay `chatgpt` ──► environment.systemPackages ──► /run/current-system
```

Everything is a normal Nix derivation: reproducible, cached, part of
`nixos-rebuild switch`, returned by `nix build .#chatgpt`. No container.

---

## 3. Reverse-engineering an unknown `.deb`

Do this **read-only** first (this repo's "read-only first" rule). Given
`chatgpt_amd64.deb`:

```bash
# 1. What is it, and does it download?
curl -sIL "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"

# 2. A .deb is an `ar` archive. List its members (offsets matter):
ar t chatgpt_amd64.deb          # debian-binary, control.tar.xz, data.tar.xz, _gpgorigin

# 3. Read metadata (version + the crucial Depends list):
ar p chatgpt_amd64.deb control.tar.xz | tar -xJ -O ./control
#   Package: chatgpt
#   Version: 26.1007.21434
#   Depends: libgtk-3-0, libnss3, libnspr4, libgbm1, libasound2, libatspi2.0-0, …

# 4. List the payload (find the real executable + .desktop + icon):
ar p chatgpt_amd64.deb data.tar.xz | tar -tJf -
#   ./usr/lib/chatgpt/ChatGPT              <-- the app (bundles Chromium)
#   ./usr/share/applications/chatgpt.desktop
#   ./usr/lib/chatgpt/resources/icon-chatgpt.png
```

Notes:

- **`Depends` maps 1:1 to `targetPkgs`.** e.g. Debian `libgtk-3-0` → nixpkgs
  `gtk3`; `libgbm1` → `libgbm`; `libatspi2.0-0` → `at-spi2-core`; `libssl3` →
  `openssl`; `libudev1` → `systemd`; `libstdc++6`/`libgcc-s1` → `stdenv.cc.cc`.
- The app often **bundles its own** Chromium libs (`libEGL.so`, `libvulkan.so`,
  `chrome_*.pak`, `resources/`), so you only need to supply the *system* deps
  (`gtk3`, `nss`, `gbm`, …), not every `.so`.
- Pin the download: `nix-prefetch-url <url>` (or `nix-prefetch-url --unpack`) to
  get the `sha256-…` / SRI hash for `fetchurl`.

---

## 4. The derivation (annotated)

Full file: [`pkgs/chatgpt.nix`](file:///home/realdhiru/Projects/codex-flake/pkgs/chatgpt.nix).

```nix
{ lib, stdenv, fetchurl, dpkg, symlinkJoin, buildFHSEnv }:

let
  version = "26.1007.21434";

  # Deterministic download. `sha256` freezes the exact bytes; if the vendor
  # silently republishes /latest/, the hash mismatch alerts you instead of
  # quietly changing your system.
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    sha256 = "sha256-J2tTQcPXSyYdOtUhBvf6ft3gaEHkdn/ipAy1QJmx8+0=";
  };

  # Unpack the .deb payload into $out/usr/… (read-only, no activation).
  unpacked = stdenv.mkDerivation {
    pname = "chatgpt-data";
    inherit version src;
    sourceRoot = ".";
    nativeBuildInputs = [ dpkg ];
    installPhase = ''
      runHook preInstall
      dpkg-deb -x $src $out
      runHook postInstall
    '';
  };

  # The FHS sandbox. It creates fake /usr, /lib, /bin inside a bubblewrap
  # namespace and sets LD_LIBRARY_PATH from targetPkgs.
  # Custom Chromium ("owl") needs --ozone-platform=wayland (not the Electron env var)
  launch = writeShellScript "chatgpt-launch" ''
    exec ${unpacked}/usr/lib/chatgpt/ChatGPT --ozone-platform=wayland "$@"
  '';

  fhs = buildFHSEnv {
    name = "chatgpt-fhs";
    executableName = "chatgpt";              # -> $out/bin/chatgpt
    runScript = launch;
    targetPkgs = p: with p; [
      gtk3 libnotify nss nspr at-spi2-core at-spi2-atk atk libdrm
      mesa libgbm libGL vulkan-loader alsa-lib cairo cups dbus expat
      gdk-pixbuf glib pango openssl systemd libusb1 libxkbcommon zlib
      stdenv.cc.cc fontconfig                       # libstdc++/libgcc
      libx11 libxcb libxcomposite libxdamage libxext libxfixes libxrandr
      xdg-utils git                                 # for browser login / hooks
    ];
  };
in
symlinkJoin {
  name = "chatgpt-${version}";
  paths = [ fhs ];
  postBuild = ''                                     # merge real desktop entry + icon
    mkdir -p $out/share/applications $out/share/icons/hicolor/512x512/apps
    cp ${unpacked}/usr/lib/chatgpt/resources/icon-chatgpt.png \
       $out/share/icons/hicolor/512x512/apps/chatgpt.png
    cp ${unpacked}/usr/share/applications/chatgpt.desktop \
       $out/share/applications/chatgpt.desktop
  '';
  meta = with lib; {
    description = "ChatGPT by OpenAI (official Linux build via FHS env)";
    homepage = "https://developers.openai.com/codex/app";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
```

Why each piece:

- **`fetchurl` + pinned hash** = reproducibility (the whole point of Nix).
- **`dpkg-deb -x`** = extract `data.tar` without needing a real `dpkg` database.
- **`buildFHSEnv`** = the fake filesystem + `LD_LIBRARY_PATH`. `runScript` is the
  absolute path (in the store) of the real binary to exec inside it.
- **`executableName`** = name of the launcher in `$out/bin` (see the gotcha in §6).
- **`symlinkJoin`** = `buildFHSEnv` only produces `bin/`; merge the vendor's
  `.desktop`, icon, and any `share/` so Fuzzel/`gtk-launch` find them.
- **`meta`** = `license = unfree` (allowed here via `nixpkgs.config.allowUnfree`),
  `sourceProvenance = binaryNativeCode` (ethically marks it as a prebuilt binary).

---

## 5. Wiring it into the flake

Register the package as an **overlay** so it appears in `pkgs` everywhere
(identical pattern to `buuf-nestort-icon-theme`):

[`flake.nix`](file:///home/realdhiru/nix/flake.nix)

```nix
modules = [
  ({ pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        chatgpt = prev.callPackage ./pkgs/chatgpt.nix { };
        # … other local packages …
      })
    ];
  })
  ./hosts/nixos/default.nix
  # …
];
```

Then add it to the system:

[`modules/system/packages.nix`](file:///home/realdhiru/nix/modules/system/packages.nix)

```nix
environment.systemPackages = with pkgs; [
  # …
  chatgpt            # local overlay (shadows the macOS-only nixpkgs attr)
  # …
];
```

Why an overlay instead of `callPackage` inline? One definition, usable from
multiple modules, `home-manager`, or even `nix shell`. `lib`.

---

## 6. Iterative runtime debugging (the real errors we hit)

`nixos-rebuild` succeeding ≠ the app working. **Always run the binary directly
before declaring victory:**

```bash
# Build just the package (no system switch):
nix build --impure --expr \
  '((builtins.getFlake "/home/realdhiru/nix").nixosConfigurations.nixos.pkgs.chatgpt)'

# Run the wrapper under your live Wayland session:
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 timeout 15 result/bin/chatgpt
```

Errors we actually hit, and the fixes:

### (a) Desktop entry existed but nothing launched — wrong binary name
`buildFHSEnv` in current nixpkgs names the launcher from its **`name`**
attribute (`executableName ? args.pname or name`), *not* `runScriptName`
(which silently did nothing in an older mental model). Result: `$out/bin/chatgpt-fhs`,
while the `.desktop` said `Exec=chatgpt` → launcher found nothing.
**Fix:** `executableName = "chatgpt";`. Verify: `ls result/bin`.

### (b) `error while loading shared libraries: libgbm.so.1`
Current nixpkgs **split `mesa`**: `libgbm` is now its own package. Listing
`mesa` is not enough. **Fix:** add `libgbm`. (General lesson: after any runtime
"missing so" error, search the store: `find /nix/store -name 'libgbm.so.1'` →
read the package name → add that attr.)

### (c) Eval-time renames (build-time, not runtime)
- `alsaLib` → **`alsa-lib`**
- `xorg.libX11` → **`libx11`**, `xorg.libxcb` → `libxcb`, `…libXcomposite` →
  `libxcomposite`, `…libXdamage` → `libxdamage`, `…libXext` → `libxext`,
  `…libXfixes` → `libxfixes`, `…libXrandr` → `libxrandr`
- `systemdLib` → **`systemd`** (provides `libudev`)

Handy checks:

```bash
# does an attr exist in this nixpkgs?
nix eval --impure --expr 'let p=(builtins.getFlake "/home/realdhiru/nix").nixosConfigurations.nixos.pkgs; in p ? libgbm'

# inside the FHS, check what a binary still needs:
nix build … && ldd result/bin/chatgpt          # or ldd on the ChatGPT binary
```

### (d) `bwrap` / sandbox errors (if they appear)
`buildFHSEnv` uses bubblewrap + unprivileged user namespaces. NixOS enables
`security.unprivilegedUsernsClone` by default; if disabled, re-enable it or use
`pkgs.buildFHSEnvChrootenv` instead of `buildFHSEnv`.

---

## 7. Making a package for **any** app — decision tree

```
Is it already in nixpkgs?          ── yes ─► just use pkgs.<name>.  (search: nix search nixpkgs <term>)
        │ no
        ▼
Is source available (git/tarball)? ── yes ─► write a normal derivation:
        │                                     stdenv.mkDerivation / rustPlatform /
        │                                     buildGoModule / python3Packages / etc.
        ▼
Ships as AppImage?                 ── yes ─► programs.appimage, or extract & autoPatchelf
        │
        ▼
Ships as .deb / .rpm / tarball     ── yes ─► ★ this guide: fetchurl + dpkg-deb -x +
        (binary only, no source)               buildFHSEnv (+ symlinkJoin for share/)
        │
        ▼
Only in a distro repo / upstream  ──► Distrobox (decisions.md §7) as last resort.
vendor lock-in
```

**Standalone flake template for any single app** (so you can also `nix run`,
share it, or consume it elsewhere):

```nix
# myapp-flake/flake.nix
{
  description = "MyApp packaged for NixOS";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems
        (s: f nixpkgs.legacyPackages.${s});
    in {
      packages = forAll (pkgs: rec {
        myapp = pkgs.callPackage ./myapp.nix { };
        default = myapp;
      });
      overlays.default = final: prev: {
        myapp = final.callPackage ./myapp.nix { };
      };
    };
}
```

Consume it from your main flake:

```nix
inputs.myapp.url = "github:you/myapp-flake";
# Option A — as an overlay (recommended, matches this repo):
nixpkgs.overlays = [ inputs.myapp.overlays.default ];
# Option B — reference directly:
environment.systemPackages = [ inputs.myapp.packages.${system}.default ];
```

In *this* repo you don't need a separate flake: keep it as
`pkgs/<app>.nix` + one overlay line in `flake.nix` (§5).

---

## 8. Maintaining it for everyday use

### Where it lives / how it survives
- The package is just files in git (`pkgs/`, `flake.nix`, `packages.nix`).
  Every `rebuild` (see [§12–13 flow.md](file:///home/realdhiru/nix/docs/flow.md))
  rebuilds and activates it; the old generation stays bootable.
- The vendor `.deb` is downloaded into the **Nix store** and cached. It is not
  re-downloaded on every rebuild unless the hash/URL changes.

### Version bumps (the only routine task)
The URL is `/latest/`, so a new release **changes the bytes** and the pinned hash
will mismatch. Workflow:

```bash
# 1. Force Nix to fetch and tell you the NEW hash:
nix build --impure --expr \
  '((builtins.getFlake "/home/realdhiru/nix").nixosConfigurations.nixos.pkgs.chatgpt)'
#    -> error: hash mismatch … specified: sha256-J2tT… got: sha256-<NEW>

# 2. In pkgs/chatgpt.nix: bump `version` and paste the new `sha256`.

# 3. Rebuild:
rebuild "chatgpt: bump to <new version>"
```

Prefer a **versioned URL** when the vendor provides one (e.g.
`…/deb/<version>/app.deb`) so the URL itself documents the version; here only
`/latest/` exists, so the `version` string + pinned hash do that job.

Optional automation (when the vendor has a stable appcast):

```nix
passthru.updateScript = ./update.sh;   # then: nix-update --flake chatgpt
```

where `update.sh` greps the version from an appcast/manifest and rewrites
`version` + `src`. Until then, the manual 3-step bump above is fine (~1 min per
release).

### Day-to-day usage
```bash
nix build  ~/nix#nixos                       # build system, no activation
sudo nixos-rebuild dry-run --flake ~/nix#nixos   # preview the switch
rebuild "…"                                  # build → switch → health gate
nix run    ~/nix#nixos.config.system.build.… # (or launch `chatgpt` directly)
chatgpt                                      # runs the FHS wrapper
```

### Keeping the store small
Old `.deb` copies and derivations accumulate. Periodically:
```bash
sudo nix-collect-garbage --delete-older-than 14d   # safe; keeps last generations
```
Never delete the store path of the *active* generation or a `known-good` tag's
generation — `nixos-rebuild` won't let you accidentally.

### If the vendor changes their packaging
Re-run §3 (list the new `.deb`, re-read `Depends`, find the new binary path),
update `runScript` + `targetPkgs` accordingly, rebuild. The wrapper is a thin
shim, so changes are localized to one file.

---

## 9. Troubleshooting quick reference

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `… does not provide attribute` / "not available on hostPlatform" | nixpkgs attr is macOS-only or wrong name | write your own derivation (§4) |
| Build OK but launcher does nothing | `.desktop` `Exec=` ≠ actual binary name | set `executableName`/check `ls result/bin` |
| `error while loading shared libraries: libX.so.N` | dep missing from `targetPkgs` | `find /nix/store -name 'libX.so.N'`, add its package |
| `undefined variable 'alsa-lib'`/`'xorg.x'` | attr renamed in nixpkgs | use the new name (§6c) |
| Blank/black window, crash on launch | XWayland/GPU | force `--ozone-platform=wayland` (done; `ELECTRON_OZONE_PLATFORM_HINT` is ignored by this runtime), ensure `mesa`,`libgbm`,`vulkan-loader`; try `--disable-features=Vulkan` if Vulkan/XWayland conflict |
| `bwrap: … Operation not permitted` | unprivileged userns off | enable `security.unprivilegedUsernsClone` |
| Login opens no browser | missing `xdg-open` | add `xdg-utils` to `targetPkgs` |
| No icon / not in Fuzzel | `.desktop`/icon not merged | `symlinkJoin` with `share/applications` + `share/icons` |
| Hash mismatch after vendor update | `/latest/` republished | bump `version` + `sha256` (§8) |

---

## 10. Reference files

- [`pkgs/chatgpt.nix`](file:///home/realdhiru/Projects/codex-flake/pkgs/chatgpt.nix) — the wrapper.
- [`flake.nix`](file:///home/realdhiru/nix/flake.nix) — overlay registration.
- [`modules/system/packages.nix`](file:///home/realdhiru/nix/modules/system/packages.nix) — `systemPackages`.
- [`docs/decisions.md`](file:///home/realdhiru/nix/docs/decisions.md) §7 (Distrobox) & §39 (this approach).
- [`docs/debugging.md`](file:///home/realdhiru/nix/docs/debugging.md) §6 — packaging & rebuild safety.
- [`docs/flow.md`](file:///home/realdhiru/nix/docs/flow.md) §12–13 — rebuild → health gate → rollback.
