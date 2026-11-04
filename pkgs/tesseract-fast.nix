{ lib
, symlinkJoin
, makeWrapper
, fetchurl
, runCommand
, tesseract
}:

let
  tessdata-fast-eng = fetchurl {
    url = "https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata";
    hash = "sha256-fUMivSp3SXJIeWg/w5EstULxmQbIO8waUhMlVkJxcLI=";
  };

  tessdata-dir = runCommand "tessdata-fast-dir" { } ''
    mkdir -p "$out"
    ln -s ${tessdata-fast-eng} "$out/eng.traineddata"
  '';
in
symlinkJoin {
  name = "tesseract-fast";
  paths = [ (tesseract.override { enableLanguages = [ "eng" ]; }) ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/tesseract \
      --set-default TESSDATA_PREFIX "${tessdata-dir}"
  '';

  meta = with lib; {
    description = "Tesseract OCR engine wrapped with tessdata_fast English model for low-latency desktop OCR";
    homepage = "https://github.com/tesseract-ocr/tesseract";
    license = licenses.asl20;
    platforms = platforms.linux;
    mainProgram = "tesseract";
  };
}
