{ lib, config, ... }:

{
  options.desktop.stateDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.xdg.stateHome}/desktop";
    description = "Unified persistent state directory for desktop components";
  };
}
