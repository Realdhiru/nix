---
title: How to Create a Standalone Flake for Any Software
tags: [nix, packaging, flakes, tutorial, rust, c, electron, python, build-systems]
---

# How to Create a Standalone Flake for Any Software

One of the most powerful capabilities of Nix is the ability to package **any arbitrary software**—whether open-source C/Rust code, a pre-compiled proprietary binary, an Electron app, or a Python script—into an isolated, self-contained **standalone Flake**.

Once packaged into a flake, the software can be run instantly on any NixOS machine via:
```bash
nix run github:your-username/your-app-flake
```
or added as a one-line declarative dependency in your root `flake.nix`.

This document provides complete, production-tested architectural blueprints for packaging the four most common software archetypes.

---

## 1. Blueprint 1: Pre-Compiled Proprietary / Upstream Binary (e.g. Zen Browser, Discord)

When an upstream project provides a pre-compiled Linux `.tar.gz`, `.deb`, or raw binary executable.

### The Problem
The binary has unpatched ELF headers expecting `/lib64/ld-linux-x86-64.so.2` and host library paths.

### The Complete `flake.nix`:
```nix
{
  description = "Standalone Flake for an upstream pre-compiled binary";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Supported architectures:
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # Allow unfree binaries if proprietary
          };

          version = "1.0.0";
        in
        {
          default = pkgs.stdenv.mkDerivation rec {
            pname = "my-binary-app";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/upstream/releases/download/v${version}/app-${version}-linux.tar.gz";
              hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Obtain via nix-prefetch-url
            };

            # Tools required during build time:
            nativeBuildInputs = with pkgs; [
              autoPatchelfHook  # Automatically fixes ELF interpreter and DT_RUNPATH
              makeWrapper       # Wraps executable with environment variables
              copyDesktopItems  # Installs desktop menu entries
            ];

            # Dynamic libraries required by the binary at runtime:
            buildInputs = with pkgs; [
              glibc
              gcc-unwrapped.lib
              xorg.libX11
              xorg.libXcursor
              libGL
              alsa-lib
              fontconfig
              freetype
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin $out/share/my-app
              cp -r * $out/share/my-app/

              # Create executable symlink in bin/:
              ln -s $out/share/my-app/bin/app-executable $out/bin/my-app

              # Wrap with Wayland flags or library search paths if needed:
              wrapProgram $out/bin/my-app \
                --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Upstream pre-compiled binary packaged natively for NixOS";
              homepage = "https://example.com";
              license = licenses.mit;
              platforms = platforms.linux;
              mainProgram = "my-app";
            };
          };
        }
      );
    }
}
```

---

## 2. Blueprint 2: Native Compiled C / C++ Project (CMake / Meson)

When packaging native C/C++ source code that must be compiled from source.

### The Complete `flake.nix`:
```nix
{
  description = "Standalone Flake for a native C/C++ project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "fast-tool";
            version = "0.1.0";

            src = ./.; # Points to local directory or pkgs.fetchFromGitHub

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
              ninja
            ];

            buildInputs = with pkgs; [
              libuv
              openssl
              zlib
            ];

            # CMake and Ninja automatically handle configure, build, and install phases!
            cmakeFlags = [
              "-DCMAKE_BUILD_TYPE=Release"
              "-DBUILD_TESTING=OFF"
            ];
          };
        }
      );

      # Developer shell for working on the C++ code locally:
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [ gdb clang-tools valgrind ];
          };
        }
      );
    }
}
```

---

## 3. Blueprint 3: Modern Rust Binary (`rustPlatform.buildRustPackage`)

When compiling a Rust application with Cargo.

### How Nix Solves Cargo's Impurity
Cargo normally downloads crates from crates.io at build time. Nix builds are network-isolated. Nix solves this by hashing the entire dependency tree into `cargoHash`.

### The Complete `flake.nix`:
```nix
{
  description = "Standalone Flake for a Rust CLI binary";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "rust-cli";
            version = "0.2.0";

            src = ./.;

            # Lockfile hash ensuring offline reproducibility:
            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = with pkgs; [ openssl dbus ];

            meta = with pkgs.lib; {
              description = "High-performance Rust utility";
              mainProgram = "rust-cli";
            };
          };
        }
      );
    }
}
```

---

## 4. Blueprint 4: Electron / Desktop Web Application

When packaging an Electron application from source or unpacked ASAR archive.

### The Complete `flake.nix`:
```nix
{
  description = "Standalone Flake for an Electron desktop app";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation rec {
            pname = "electron-desktop-app";
            version = "1.5.0";

            src = pkgs.fetchurl {
              url = "https://github.com/upstream/releases/download/v${version}/app.tar.gz";
              hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
            };

            nativeBuildInputs = with pkgs; [
              makeWrapper
              asar
            ];

            installPhase = ''
              mkdir -p $out/bin $out/share/my-electron-app
              cp -r resources/* $out/share/my-electron-app/

              # Wrap system electron binary with application source and Wayland flags:
              makeWrapper ${pkgs.electron}/bin/electron $out/bin/my-electron-app \
                --add-flags "$out/share/my-electron-app/app.asar" \
                --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-wayland-ime=true}}"
            '';
          };
        }
      );
    }
}
```

---

## 5. How to Obtain Hashes Deterministically

When packaging an external tarball or binary:
1. Obtain the NAR hash using `nix-prefetch-url`:
   ```bash
   nix-prefetch-url https://example.com/archive.tar.gz
   # Convert to SR1-32 hash:
   nix hash to-sri --type sha256 <output_hash>
   ```
2. Or let Nix compute it: set `hash = pkgs.lib.fakeHash;` (or empty string). Run `nix build`. Nix will fail and print:
   ```
   specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
   got:       sha256-ActualComputedHashHere1234567890abcdef=
   ```
   Copy the `got` hash into your `flake.nix`.

## Related Nodes
- [[Nix Flakes - Deep Dive Specification, Anatomy, and Evaluation]]
- [[Application Packaging - Derivations, FHS, AppImage, and Wrappers]]
- [[Flake Self-Hosting Architecture]]
