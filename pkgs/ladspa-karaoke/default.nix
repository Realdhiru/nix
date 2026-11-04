{ stdenv, ladspa-header }:

stdenv.mkDerivation {
  pname = "ladspa-spectral-karaoke";
  version = "1.0.0";

  src = ./.;

  buildInputs = [ ladspa-header ];

  buildPhase = ''
    runHook preBuild
    $CC -O3 -fPIC -shared -Wall -Wextra spectral_karaoke.c -o spectral_karaoke.so -lm
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 spectral_karaoke.so $out/lib/ladspa/spectral_karaoke.so
    runHook postInstall
  '';
}
