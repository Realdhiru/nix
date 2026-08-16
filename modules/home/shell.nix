{ ... }:

{
  programs.zsh = {
    enable = true;

    enableCompletion = true;

    autosuggestion.enable = true;

    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      path = "$HOME/.zsh_history";
    };

    initContent = ''
      if [ -z "$DISPLAY" ] && [ "''${XDG_VTNR:-0}" = "1" ]; then
          exec start-hyprland
      fi
      # Rebuild safety policy (2026-08-16 i915 incident, docs/decisions.md):
      #   record known-good -> commit -> BUILD (no activation on failure) ->
      #   switch -> health gate -> auto-rollback on critical checks.
      # The bad generation is NEVER deleted: it stays selectable in the
      # profile and bootable via bootctl. See docs/flow.md §12.
      rebuild() {
        cd ~/nix || return

        local start gen rev
        start=$(date -Is)
        gen=$(readlink /nix/var/nix/profiles/system)
        rev=$(git rev-parse HEAD)

        mkdir -p "$HOME/.cache"
        printf '%s %s %s\n' "$start" "$gen" "$rev" >> "$HOME/.cache/nix_rebuild_log"
        git tag -f known-good >/dev/null 2>&1

        git add -A

        if git diff --cached --quiet && git diff --quiet; then
          echo "Nothing to commit."
        else
          if [ $# -eq 0 ]; then
            git commit -m "Update configuration"
          else
            git commit -m "$*"
          fi
        fi

        if ! sudo nixos-rebuild build --flake .#nixos --store-path /tmp/nixos-build-check; then
          echo "BUILD FAILED — nothing activated; still on generation $gen."
          return 1
        fi

        sudo nixos-rebuild switch --flake .#nixos || {
          echo "SWITCH FAILED — still on generation $gen (build itself was fine)."
          echo "Manual recovery: ~/nix/docs/flow.md §13"
          return 1
        }
        local new_gen
        new_gen=$(readlink /nix/var/nix/profiles/system)

        "$HOME/nix/scripts/health-check.sh" "$start"
        local hc=$?
        if [ $hc -eq 0 ]; then
          echo "Rebuild OK: generation $new_gen (previous known-good: $gen)"
        elif [ $hc -eq 2 ]; then
          echo "Rebuild: generation $new_gen active WITH WARNINGS (see log above)."
        else
          echo "=== CRITICAL health-check failure — auto-rollback ==="
          if sudo nixos-rebuild switch --rollback; then
            local restored
            restored=$(readlink /nix/var/nix/profiles/system)
            if [ "$restored" = "$gen" ]; then
              echo "Rollback verified: generation $restored restored."
            else
              echo "NOTE: profile is at $restored, expected $gen — inspect manually."
            fi
          else
            echo "ROLLBACK COMMAND FAILED — manual: sudo nixos-rebuild switch --rollback"
          fi
          echo "Failed generation: $new_gen (kept — still selectable/bootable)"
          echo "Restored generation: $(readlink /nix/var/nix/profiles/system)"
          echo "Health report: $(ls -t "$HOME"/.cache/nix_health_*.log 2>/dev/null | head -1)"
          echo "Investigate: journalctl -k --since '$start' | grep -iE 'GPU HANG|call trace'"
          echo "Docs: ~/nix/docs/flow.md §12–13"
          return 1
        fi
      }

      update() {
        cd ~/nix || return

        git pull
        nix flake update

        rebuild "flake update"
      }

      clean() {
        # 14d window keeps the previous generation bootable/rollbackable
        # (nix.gc automatic weekly is also --delete-older-than 14d).
        sudo nix-collect-garbage --delete-older-than 14d
      }

      ff() {
        fastfetch
      }
    '';

    shellAliases = {
    };
  };

  programs.starship.enable = true;

  xdg.configFile."starship.toml".source =
    ../../dotfiles/starship/starship.toml;
}