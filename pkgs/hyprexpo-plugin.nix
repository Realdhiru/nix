{ lib, stdenv, fetchFromGitHub, hyprland, pkg-config, cmake
, pixman, libdrm, pango, cairo, libinput, systemd, wayland, libxkbcommon, lua5_4
}:

# Bypasses hyprlandPlugins.mkHyprlandPlugin entirely — that helper throws a
# "NIX_MAIN_PROGRAM overlapping in env/derivation-args" error on this
# nixpkgs revision before it ever returns a derivation, so there is no
# attrset left to override or patch around. Building directly with
# stdenv.mkDerivation avoids that helper's internals altogether and uses
# the plugin's own documented build (`make all` / `make install`), still
# linked against the exact `hyprland` package your system runs so the
# plugin ABI matches.
stdenv.mkDerivation {
  pname = "hyprexpo";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "refs/heads/main";
    # Placeholder — the build WILL fail on first run with a message like:
    #   error: hash mismatch ... got: sha256-XXXXXXXX...
    # Copy that "got:" hash back in here and rebuild. Normal/expected.
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [
    hyprland
    pixman
    libdrm
    pango
    cairo
    libinput
    systemd  # provides libudev
    wayland
    libxkbcommon
    lua5_4
  ];

  # Matches the repo's own documented build entry point.
  buildPhase = ''
    runHook preBuild
    make all
    runHook postBuild
  '';

  # The repo warns: use `install`/`make install`, never a plain `cp`, when
  # placing a .so that Hyprland might later map into its running process.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    install -m755 hyprexpo.so $out/lib/hyprexpo.so
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/sandwichfarm/hyprexpo";
    description = "Maintained hyprexpo fork with keyboard nav, labels, multi-monitor support";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
