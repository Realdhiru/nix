{ config, ... }:

{
  xdg.configFile."hypr/hyprland.conf" = { 
	source = ../../dotfiles/hypr/hyprland.conf;
	force = true;
    };
}
