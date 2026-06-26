{ stdenvNoCC, fetchgit, lib }:

stdenvNoCC.mkDerivation {
  pname = "buuf-nestort-icon-theme";
  version = "48cbf7b8";

  src = fetchgit {
    url = "https://gitlab.com/beucismis/buuf-nestort.git";
    rev = "48cbf7b8";
    hash = lib.fakeHash;
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/icons/buuf-nestort
    cp -r * $out/share/icons/buuf-nestort/
  '';

  meta = with lib; {
    description = "Buuf For Many Desktops icon theme";
    homepage = "https://gitlab.com/beucismis/buuf-nestort";
    platforms = platforms.linux;
  };
}