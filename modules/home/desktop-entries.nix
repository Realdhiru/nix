{ lib, ... }:

let
  # Your preferred terminal.
  terminal = "wezterm";

  terminalExec =
    command:
      if terminal == "wezterm" then
        "wezterm start -- ${command}"
      else if terminal == "ghostty" then
        "ghostty -e ${command}"
      else if terminal == "kitty" then
        "kitty ${command}"
      else if terminal == "foot" then
        "foot ${command}"
      else
        "${terminal} -e ${command}";

  mkTerminalDesktop =
    {
      name,
      command,
      icon ? "utilities-terminal",
      genericName ? "",
      comment ? "",
      categories ? [ "Utility" ],
    }:
    {
      inherit
        name
        genericName
        comment
        icon
        categories
        ;

      exec = terminalExec command;

      terminal = false;
      startupNotify = true;
    };
in
{
  xdg.desktopEntries = {

    opencode = mkTerminalDesktop {
      name = "OpenCode";
      genericName = "AI Coding Assistant";
      comment = "Launch OpenCode";
      command = "opencode";
      categories = [ "Development" ];
    };

  };
}