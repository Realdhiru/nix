{
  description = "NixOS Hyprland Rice & Desktop Configuration";

  inputs = {
    # nixos-unstable: floating, no pins. 2026-08-16 the flake was pinned to
    # e2587ca as a TEMPORARY recovery measure for the i915 GPU-hang storm
    # (see docs/decisions.md); the pin has been removed. Newer nixpkgs,
    # kernels, Mesa, WezTerm are expected and welcome; rebuild()'s health
    # gate is the safety net, not a version lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:Realdhiru/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anifetch = {
      url = "github:Notenlish/anifetch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Standalone repo: ~/Projects/flakes/codex-flake.
    chatgpt = {
      url = "github:Realdhiru/codex-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      user = import ./user.nix;
      motion-tokens = import ./dotfiles/hypr/motion-tokens.nix;
      motion-gen = import ./lib/motion-gen.nix { lib = pkgs.lib; };
    in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs user;
      };

      modules = [
        ({ pkgs, inputs, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              buuf-nestort-icon-theme =
                prev.callPackage ./pkgs/buuf-nestort.nix { };
              hypr-kdeconnect-portal =
                prev.callPackage ./pkgs/hypr-kdeconnect-portal.nix { };
              gameclean =
                prev.callPackage ./pkgs/gameclean.nix { };
              pcmanfm-qt = prev.pcmanfm-qt.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [ ./pkgs/pcmanfm-qt-appid.patch ];
              });
            } // (
              let
                patchFHS = orig:
                  let
                    wrapped = args:
                      orig (
                        if builtins.isFunction args then
                          (finalAttrs: (args finalAttrs) // { dieWithParent = false; })
                        else
                          args // { dieWithParent = false; }
                      );
                  in
                    prev.lib.makeOverridable wrapped;
              in {
                # Global fix: eliminate bubblewrap --die-with-parent across all FHS applications
                # (onlyoffice, lutris, bottles, chatgpt, appimage-run) so apps opened from file
                # managers, terminals, or scripts do not get killed when the parent window exits.
                buildFHSEnv = patchFHS prev.buildFHSEnv;
                buildFHSEnvChroot = patchFHS prev.buildFHSEnvChroot;
              }
            ))
            # chatgpt from the standalone ~/Projects/codex-flake flake.
            inputs.chatgpt.overlays.default
          ];
        })

        ./hosts/nixos/default.nix

        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";

          home-manager.extraSpecialArgs = {
            inherit inputs user;
          };

          home-manager.sharedModules = [ ];

          home-manager.users.${user.username} = import ./home.nix;
        }
      ];
    };

    checks = {
      ${system} = {
        motion-tokens = pkgs.runCommandLocal "motion-tokens" { } ''
          cmp ${pkgs.writeText "motion.lua.generated" (motion-gen.motionLua motion-tokens)} ${./dotfiles/hypr/motion.lua}
          cmp ${pkgs.writeText "Motion.qml.generated" (motion-gen.motionQml motion-tokens)} ${./dotfiles/hypr/scripts/quickshell/Motion.qml}
          mkdir -p "$out"
        '';
        qml-lint = pkgs.runCommandLocal "qml-lint" { } ''
          QT_QML=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
          QS_QML=${pkgs.quickshell}/lib/qt-6/qml
          QMLLINT=${pkgs.qt6.qtdeclarative}/bin/qmllint
          cp -r ${./dotfiles/hypr/scripts/quickshell} src
          fail=0
          while IFS= read -r f; do
            echo "qmllint: ''${f#src/}"
            if lintout=$("$QMLLINT" -I "$QT_QML" -I "$QS_QML" "$f" 2>&1); then
              if printf '%s\n' "$lintout" | grep -q "unknown attached property scope"; then
                echo "FAIL: unresolved attached property in ''${f#src/}:"
                printf '%s\n' "$lintout" | grep "unknown attached property scope"
                fail=1
              fi
            else
              echo "FAIL: qmllint exited non-zero on ''${f#src/}:"
              printf '%s\n' "$lintout" | tail -20
              fail=1
            fi
          done < <(find src -name '*.qml' -type f | sort)
          echo "motion-check: numeric durations and raw easings may only exist in Motion.qml"
          while IFS= read -r f; do
            case "''${f}" in
              */Motion.qml) continue ;;
              # Explicit user override: NetworkPopup.qml retains rich visual physics animations from origin/main
              */network/NetworkPopup.qml) continue ;;
            esac
            if grep -nE 'duration[[:space:]]*:[[:space:]]*[0-9]' "''${f}"; then
              echo "LINT: numeric duration in ''${f#src/}:"
            fi
            if { grep -nE 'Easing\.[A-Za-z]+' "''${f}" || grep -n 'bezierCurve' "''${f}" | grep -v 'bezierCurveTo'; } | grep -v '^$'; then
              echo "LINT: raw easing in ''${f#src/} (use Motion.qml tokens)"
            fi
          done < <(find src -name '*.qml' -type f | sort)
          mkdir -p "$out"
          exit "$fail"
        '';
        regression-guards = pkgs.runCommandLocal "regression-guards" { } ''
          cp -r ${./dotfiles} dotfiles
          cp -r ${./scripts} scripts
          fail=0

          echo "Guard 1: hyprctl reload outside reload.sh"
          while IFS= read -r line; do
            file=$(printf '%s\n' "$line" | cut -d: -f1)
            case "$file" in
              dotfiles/hypr/scripts/reload.sh) ;;
              *)
                echo "FAIL: Unauthorized hyprctl reload found in $file"
                fail=1
                ;;
            esac
          done < <(grep -rn "hyprctl reload" dotfiles/ 2>/dev/null || true)

          echo "Guard 2: sleep in QML files and unauthorized scripts"
          while IFS= read -r f; do
            if grep -nE 'sleep[[:space:]]+[0-9]' "$f" 2>/dev/null; then
              echo "FAIL: Unauthorized sleep found in QML file $f"
              fail=1
            fi
          done < <(find dotfiles/hypr/scripts/quickshell -name '*.qml')

          # Allowed scripts with sleep (hardware/external daemon settle delays or systemd-inhibit sleep infinity):
          # dotfiles/hypr/scripts/exit.sh
          # dotfiles/hypr/scripts/fix_audio.sh
          # dotfiles/hypr/scripts/fuzzel_menu.sh
          # dotfiles/hypr/scripts/qs_manager.sh
          # dotfiles/hypr/scripts/quickshell/music/music_info.sh
          # dotfiles/hypr/scripts/quickshell/music/player_control.sh
          # dotfiles/hypr/scripts/quickshell/network/bluetooth_panel_logic.sh
          # dotfiles/hypr/scripts/quickshell/network/bt_agent.sh
          # dotfiles/hypr/scripts/quickshell/restore_state.sh
          # dotfiles/hypr/scripts/quickshell/wallpaper/ddg_search.sh
          # dotfiles/hypr/scripts/reload.sh
          # dotfiles/hypr/scripts/rotate_display.sh
          # dotfiles/wallpaper/backend/ddg_search.sh
          # dotfiles/wallpaper/backend/ensure_awww.sh
          # dotfiles/wallpaper/backend/set.sh
          # dotfiles/wallpaper/backend/watcher.sh
          # scripts/selftest-modes.sh
          while IFS= read -r line; do
            f=$(printf '%s\n' "$line" | cut -d: -f1)
            case "$f" in
              dotfiles/hypr/scripts/exit.sh|\
              dotfiles/hypr/scripts/fix_audio.sh|\
              dotfiles/hypr/scripts/fuzzel_menu.sh|\
              dotfiles/hypr/scripts/qs_manager.sh|\
              dotfiles/hypr/scripts/quickshell/music/music_info.sh|\
              dotfiles/hypr/scripts/quickshell/music/player_control.sh|\
              dotfiles/hypr/scripts/quickshell/network/bluetooth_panel_logic.sh|\
              dotfiles/hypr/scripts/quickshell/network/bt_agent.sh|\
              dotfiles/hypr/scripts/quickshell/restore_state.sh|\
              dotfiles/hypr/scripts/reload.sh|\
              dotfiles/hypr/scripts/rotate_display.sh|\
              dotfiles/wallpaper/backend/ddg_search.sh|\
              dotfiles/wallpaper/backend/ensure_awww.sh|\
              dotfiles/wallpaper/backend/set.sh|\
              dotfiles/wallpaper/backend/watcher.sh|\
              scripts/health-check.sh|\
              scripts/measure-notif-latency.sh|\
              scripts/selftest-modes.sh|\
              scripts/test-ac-trigger.sh) ;;
              *)
                echo "FAIL: Unauthorized sleep found in $f"
                fail=1
                ;;
            esac
          done < <(grep -rnE 'sleep[[:space:]]+[0-9]' dotfiles/ scripts/ 2>/dev/null || true)

          echo "Guard 3: Python or Node in owned codebase"
          if grep -rnE '^#![[:space:]]*/usr/bin/(env[[:space:]]+)?(python|node)' dotfiles/ scripts/ 2>/dev/null; then
            echo "FAIL: Python or Node shebang found in owned codebase"
            fail=1
          fi
          if find dotfiles/ scripts/ -name '*.py' | grep -q .; then
            echo "FAIL: Python script found in owned codebase"
            fail=1
          fi

          echo "Guard 4: pkill or systemctl start/stop in QML"
          while IFS= read -r f; do
            if grep -nE '(pkill|systemctl[[:space:]]+(start|stop))' "$f" 2>/dev/null; then
              echo "FAIL: pkill or systemctl start/stop found in $f"
              fail=1
            fi
          done < <(find dotfiles/hypr/scripts/quickshell -name '*.qml')

          echo "Guard 5: sysfs battery reads in QML"
          while IFS= read -r f; do
            if grep -n 'sys/class/power_supply' "$f" 2>/dev/null; then
              echo "FAIL: sysfs battery read found in $f"
              fail=1
            fi
          done < <(find dotfiles/hypr/scripts/quickshell -name '*.qml')

          echo "Guard 6: bursts or retries for state settling"
          while IFS= read -r line; do
            echo "FAIL: State settling burst/retry found: $line"
            fail=1
          done < <(grep -rnE '(batterySettleTimer|_triggerBatteryBurst|settleTimer)' dotfiles/ scripts/ 2>/dev/null || true)

          echo "Guard 7: symlink shims in desktop scripts"
          while IFS= read -r line; do
            f=$(printf '%s\n' "$line" | cut -d: -f1)
            case "$f" in
              dotfiles/wallpaper/backend/thumbnail.sh|\
              scripts/health-check.sh) ;;
              *)
                echo "FAIL: Symlink shim found in $f: $line"
                fail=1
                ;;
            esac
          done < <(grep -rnE 'ln -s' dotfiles/ scripts/ 2>/dev/null || true)

          echo "Guard 8: hardcoded /run/current-system/sw/bin/* paths in dotfiles"
          while IFS= read -r line; do
            echo "FAIL: Hardcoded system path found in dotfiles: $line"
            fail=1
          done < <(grep -rnE '/run/current-system/sw/bin' dotfiles/ 2>/dev/null || true)

          echo "Guard 9: persistent state paths under ~/.cache"
          if grep -rnE '(\~|\$HOME)/\.cache/(quickshell/state\.json|modes/|power/profile|idle_inhibit|wallpaper_kill_throttle|gaming_mode|wallpaper_killed)' dotfiles/ 2>/dev/null; then
            echo "FAIL: persistent state path under ~/.cache found"
            fail=1
          fi

          echo "Guard 10: plaintext secrets or tracked API key files"
          if [ -f dotfiles/secrets/openweather.json ]; then
            echo "FAIL: openweather.json must not be tracked in git"
            fail=1
          fi
          if grep -rnE '(weatherApiKey|openweather.*api\.openweathermap\.org/data/2\.5/weather\?appid=[a-f0-9]{32})' dotfiles/ 2>/dev/null; then
            echo "FAIL: hardcoded weather API token found in dotfiles"
            fail=1
          fi

          echo "Guard 11: duplicate keybinds in keybinds.lua"
          if ! awk '
            /hl\.define_submap/ { in_submap = 1 }
            /hl\.bind\(/ {
              if (match($0, /hl\.bind\(([^,]+)/)) {
                key = substr($0, RSTART + 8, RLENGTH - 8)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
                scope = in_submap ? "submap" : "root"
                seen[scope ":" key]++
                if (seen[scope ":" key] > 1) {
                  print "Duplicate bind in " scope ": " key
                  dup = 1
                }
              }
            }
            /end\)/ { in_submap = 0 }
            END { exit dup }
          ' dotfiles/hypr/keybinds.lua; then
            echo "FAIL: duplicate keybind definition found in keybinds.lua"
            fail=1
          fi

          mkdir -p "$out"
          exit "$fail"
        '';
      };
    };
  };
}
