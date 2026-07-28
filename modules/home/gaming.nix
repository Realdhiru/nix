{ config, ... }:

{
  home.file.".local/bin/game-sandbox.sh" = {
    source = ../../dotfiles/gaming/game-sandbox.sh;
    executable = true;
  };
}
