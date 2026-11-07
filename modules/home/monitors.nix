{ user, ... }:
{
  # The same standalone script handles startup and power-supply events. It
  # resolves all monitor data first, then sends one `hyprctl eval` containing
  # only hl.monitor(); nested hyprctl IPC from inside that eval can stall Hyprland.
  systemd.user.services.hypr-refresh-rate = {
    Unit = {
      Description = "Apply power profile and monitor refresh policy after power-supply events settle";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/hypr/scripts/power.sh auto";
      Environment = [
        "HYPR_REFRESH_AC=${toString user.desktop.refreshRate.ac}"
        "HYPR_REFRESH_BATTERY=${toString user.desktop.refreshRate.battery}"
      ];
    };
  };
  systemd.user.timers.hypr-refresh-rate = {
    Unit.Description = "Coalesce power-supply change bursts before applying desktop power policy";
    Timer = {
      OnActiveSec = "500ms";
      AccuracySec = "100ms";
      Unit = "hypr-refresh-rate.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
