{ stdenvNoCC, fetchgit, lib }:

stdenvNoCC.mkDerivation {
  pname = "buuf-nestort-icon-theme";
  version = "master";

  src = fetchgit {
    url = "https://gitlab.com/beucismis/buuf-nestort.git";
    rev = "refs/heads/master";
    hash = "sha256-1BvMLgi6FDwqyEV7W0CBbte97bybkGAOYkJKW6HqK9g="; 
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