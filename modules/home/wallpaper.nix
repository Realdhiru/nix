{ config, pkgs, user, ... }:

{
  home.sessionVariables = {
    DEFAULT_WALLPAPER = "${../../dotfiles/wallpaper/default.jpg}";
    WALLPAPER_DIR = "${config.home.homeDirectory}/${user.desktop.wallpaperDirectory}";
    WALLPAPER_ORGANIZER_PROJECTS_DIR = "${config.home.homeDirectory}/${user.desktop.wallpaperOrganizerProjectsDirectory}";
  };

  xdg.configFile."environment.d/wallpaper.conf".text =
    "DEFAULT_WALLPAPER=${../../dotfiles/wallpaper/default.jpg}\nWALLPAPER_DIR=${config.home.homeDirectory}/${user.desktop.wallpaperDirectory}\nWALLPAPER_ORGANIZER_PROJECTS_DIR=${config.home.homeDirectory}/${user.desktop.wallpaperOrganizerProjectsDirectory}\n";

  xdg.configFile."wallpaper" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/wallpaper";
    force = true;
  };

  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon --no-cache --format argb";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services."mpvpaper@" = {
    Unit = {
      Description = "mpvpaper video wallpaper for %i";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      EnvironmentFile = "%h/.local/state/mpvpaper/%i.env";
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p -o \"no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=%t/mpvpaper-%i.sock\" %i \${WALLPAPER_VIDEO}";
      Restart = "on-failure";
    };
  };
}
