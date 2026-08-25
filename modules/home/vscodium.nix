{ config, pkgs, ... }:

{
  # VSCodium: settings live in dotfiles/vscodium (real files), mirrored
  # bidirectionally with the app's live config. home-manager's xdg.configFile
  # can only ever symlink into the read-only generation store, which VSCodium
  # cannot write through — so on every rebuild we copy the repo file onto the
  # real config path after the writeBoundary step (overwriting the managed
  # symlink). Changes flow back to the repo via the sync watcher service.
  home.activation.vscodiumSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/VSCodium/User"
    cp -f ${../../dotfiles/vscodium/settings.json} "$HOME/.config/VSCodium/User/settings.json"
    chmod 644 "$HOME/.config/VSCodium/User/settings.json"
  '';

  systemd.user.services.vscodium-settings-sync = {
    Unit = {
      Description = "Mirror VSCodium settings.json into the nix repo";
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash %h/nix/dotfiles/vscodium/sync_settings.sh";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PATH=/etc/profiles/per-user/realdhiru/bin:/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
