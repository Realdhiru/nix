{ lib, config, ... }:

{
  config = {
    home.sessionVariables.DESKTOP_STATE_DIR = config.desktop.stateDir;
    xdg.configFile."environment.d/desktop_state.conf".text =
      "DESKTOP_STATE_DIR=${config.desktop.stateDir}\n";
  };

  options.desktop.stateDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.xdg.stateHome}/desktop";
    description = "Unified persistent state directory for desktop components";
  };
}
