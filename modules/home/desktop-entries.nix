{ config, pkgs, lib, ... }:

let
  # Change this once if you ever switch terminals.
  terminal = "wezterm";

  terminalExec = command:
    if terminal == "wezterm" then
      "wezterm start -- ${command}"
    else if terminal == "kitty" then
      "kitty ${command}"
    else if terminal == "ghostty" then
      "ghostty -e ${command}"
    else if terminal == "foot" then
      "foot ${command}"
    else
      "${terminal} -e ${command}";
in
{
  xdg.desktopEntries = {

    opencode = {
      name = "OpenCode";
      genericName = "AI Coding Assistant";
      comment = "Open OpenCode in a terminal";

      exec = terminalExec "opencode";

      terminal = false;
      startupNotify = true;

      icon = "utilities-terminal";

      categories = [
        "Development"
        "Utility"
      ];

      keywords = [
        "AI"
        "Code"
        "LLM"
        "Terminal"
      ];
    };

  };
}