{ lib
, stdenv
, python3
}:

stdenv.mkDerivation rec {
  pname = "gameclean";
  version = "1.0.0";

  # Single self-contained Python script using only the stdlib
  # (its own minimal Lutris .yml parser — no PyYAML, no other deps).
  src = ./gameclean/gameclean.py;

  phases = [ "installPhase" ];

  installPhase = ''
    install -Dm755 $src $out/bin/gameclean
    # Pin shebang to the Nix store interpreter.
    sed -i "1s|^#!.*|#!${python3}/bin/python3|" $out/bin/gameclean
  '';

  meta = with lib; {
    description = "Wine/Proton/Lutris leftover file scanner and janitor for ~/Games";
    homepage = "https://github.com/Realdhiru/nix";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "gameclean";
  };
}
