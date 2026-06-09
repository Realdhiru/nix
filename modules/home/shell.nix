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
      rebuild() {
        cd ~/nix || return

        git add -A

        if [ $# -eq 0 ]; then
          git commit -m "Update configuration" || true
        else
          git commit -m "$*" || true
        fi

        sudo nixos-rebuild switch --flake .#vivobook
      }

      clean() {
        sudo nix-collect-garbage -d
      }
    '';

    initExtra = ''
      if [[ -o interactive ]]; then
        fastfetch
      fi
    '';
};