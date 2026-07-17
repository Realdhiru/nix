{ lib, fetchFromGitHub, hyprland, hyprlandPlugins, ... }:

# Built against `hyprland` from the SAME nixpkgs revision your system uses
# (via `pkgs.hyprland`, passed in automatically since this is loaded through
# your overlay). This matters: a plugin built against a different Hyprland
# commit than the one actually running is an ABI mismatch and can crash
# the compositor on load. mkHyprlandPlugin guarantees they match.
(hyprlandPlugins.mkHyprlandPlugin hyprland {
  pluginName = "hyprexpo";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "main";
    hash = lib.fakeHash;
  };

  meta = {
    homepage = "https://github.com/sandwichfarm/hyprexpo";
    description = "Maintained hyprexpo fork with keyboard nav, labels, multi-monitor support";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}).overrideAttrs (old: removeAttrs old [ "NIX_MAIN_PROGRAM" ])
