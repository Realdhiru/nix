{ inputs, pkgs, ... }:

{
  # anifetch backs the af() zsh function below (lost once as uncommitted
  # code — keep this file committed via rebuild()'s git add -A).
  home.packages = [ inputs.anifetch.packages.${pkgs.system}.default ];

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

        if ! sudo nixos-rebuild build --flake .#nixos; then
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
          if sudo nixos-rebuild switch --rollback --flake .#nixos; then
            local restored
            restored=$(readlink /nix/var/nix/profiles/system)
            if [ "$restored" = "$gen" ]; then
              echo "Rollback verified: generation $restored restored."
            else
              echo "NOTE: profile is at $restored, expected $gen — inspect manually."
            fi
          else
            echo "ROLLBACK COMMAND FAILED — manual: sudo nixos-rebuild switch --rollback --flake .#nixos"
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

      af() {
        local dir="$HOME/Pictures/fastfetch"
        local state="$HOME/.cache/anifetch_index"
        local -a files=("$dir"/*.gif(N) "$dir"/*.mp4(N))
        local n=''${#files}
        if (( n == 0 )); then
          echo "no gifs or videos in $dir"
          return 1
        fi
        local idx=0
        if [[ -f "$state" ]]; then
          idx=$(<"$state") 2>/dev/null || idx=0
          [[ "$idx" =~ ^[0-9]+$ ]] || idx=0
        fi
        local last_int=0 abort=0
        local font_file="$HOME/.cache/af_font_size"
        echo 'return 10' > "$font_file"
        trap 'rm -f "$HOME/.cache/af_font_size"' EXIT HUP TERM
        trap 'if (( $(date +%s%N) - last_int < 1000000000 )); then abort=1; else last_int=$(date +%s%N); echo "ctrl-c: next one..."; fi' INT
        sleep 0.3
        while true; do
          (( abort )) && return 130
          local file="''${files[$((idx % n + 1))]}"
          echo $((idx + 1)) > "$state"
          echo "▶ ''${file:t}"

          # measure the fastfetch info block the same way anifetch does
          local ffout
          ffout=$(fastfetch --logo none --pipe false 2>/dev/null) || ffout=""
          local -a ff_lines=("''${(f)ffout}")
          local nlines=''${#ff_lines}
          local fw=0 l clean
          for l in "''${ff_lines[@]}"; do
            clean=$(printf %s "$l" | sed 's/\x1b\[[0-9;]*m//g')
            (( ''${#clean} > fw )) && fw=''${#clean}
          done
          (( nlines < 1 )) && nlines=20
          (( fw < 1 )) && fw=60

          # terminal size (stty size prints "rows cols")
          local cols rows
          read -r rows cols <<< "$(stty size 2>/dev/null)"
          [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
          [[ "$rows" =~ ^[0-9]+$ ]] || rows=24

          # source aspect
          local sw sh
          sw=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")
          sh=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")
          [[ "$sw" =~ ^[0-9]+$ && "$sh" =~ ^[0-9]+$ ]] || { sw=16; sh=9; }

          # logo area in cells: left pad 4 + animation + gap 2 + fetch text <= cols
          # fit source (aspect sw/sh) into wmax x (2*hmax) pixels (cell aspect 2)
          local wmax=$((cols - 4 - 2 - fw))
          (( wmax < 1 )) && wmax=1
          local hmax=$nlines
          local W H
          if (( wmax * sh <= 2 * hmax * sw )); then
            W=$wmax
            H=$(( (W * sh) / (2 * sw) ))
          else
            H=$hmax
            W=$(( (2 * H * sw) / sh ))
          fi
          (( W < 1 )) && W=1
          (( H < 1 )) && H=1

          anifetch "$file" -W "$W" -H "$H"
          idx=$((idx + 1))
        done
      }
    '';

    shellAliases = {
    };
  };

  programs.starship.enable = true;

  xdg.configFile."starship.toml".source =
    ../../dotfiles/starship.toml;
}