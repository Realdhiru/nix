{ ... }:

{
  # FocusTime daemon — one systemd lifecycle owner for the QuickShell widget.
  systemd.user.services.focustime-daemon = {
    Unit.Description = "Focus time tracking daemon (Hyprland active window)";
    Service = {
      ExecStart = "%h/.config/hypr/scripts/quickshell/focustime/focus_daemon";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "QS_STATE_FOCUSTIME=%h/.local/state/desktop/focustime"
        "QS_RUN_FOCUSTIME=%t/quickshell/focustime"
        "PATH=/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
