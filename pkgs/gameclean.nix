{ lib
, stdenv
, makeWrapper
, coreutils
, gawk
}:

stdenv.mkDerivation rec {
  pname = "gameclean";
  version = "1.0.0";

  src = ./gameclean/gameclean.sh;

  nativeBuildInputs = [ makeWrapper ];

  phases = [ "installPhase" ];

  installPhase = ''
    install -Dm755 $src $out/bin/gameclean
    wrapProgram $out/bin/gameclean \
      --prefix PATH : ${lib.makeBinPath [ coreutils gawk ]}
  '';

  meta = with lib; {
    description = "Wine/Proton/Lutris leftover file scanner and janitor for ~/Games";
    homepage = "https://github.com/Realdhiru/nix";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "gameclean";
  };
}
