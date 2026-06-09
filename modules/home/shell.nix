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
      rebuild() {
        cd ~/nix || return

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

        sudo nixos-rebuild switch --flake .#vivobook
      }

      update() {
        cd ~/nix || return

        git pull
        nix flake update

        rebuild "flake update"
      }

      clean() {
        sudo nix-collect-garbage -d
      }


  programs.starship.enable = true;

  xdg.configFile."starship.toml".source =
    ../../dotfiles/starship/starship.toml;
}