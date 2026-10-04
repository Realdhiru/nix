{ stdenvNoCC, fetchFromGitHub, lib }:

stdenvNoCC.mkDerivation {
  pname = "buuf-nestort-icon-theme";
  version = "unstable-2022-02-07";

  # Upstream beucismis GitLab fork is gone (404). This is the same
  # "Buuf For Many Desktops (formerly Buuf Nestort)" theme, verified by
  # identical README/index.theme/directory layout, pinned to commit
  # 9ce6963 (2022-02-07). Canonical eudaimon/disroot upstream is
  # unreachable for bulk transfer from here; GitHub codeload is reliable.
  src = fetchFromGitHub {
    owner = "alfathmuqoddas";
    repo = "buuf-nestort";
    rev = "9ce696308923992ddcb1f60f926b8999253e0ea0";
    hash = "sha256-xWTr3tzwIA5gK+3IB3eOhJmEh97DiumGerTfi35K9UU=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/icons/buuf-nestort
    cp -r * $out/share/icons/buuf-nestort/

    # Strip out broken symlinks from the upstream repository
    find $out -xtype l -delete
  '';

  meta = with lib; {
    description = "Buuf For Many Desktops icon theme";
    homepage = "https://github.com/alfathmuqoddas/buuf-nestort";
    platforms = platforms.linux;
  };
}