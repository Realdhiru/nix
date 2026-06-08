{ ... }:

{
  programs.zsh = {
    enable = true;

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

      update() {
        cd ~/nix || return

        git pull
        nix flake update

        rebuild "flake update"
      }

      clean() {
        sudo nix-collect-garbage -d
      }
    '';
  };

  programs.starship = {
    enable = true;
  };
  xdg.configFile."starship.toml".source =
  ../../dotfiles/starship/starship.toml;
}