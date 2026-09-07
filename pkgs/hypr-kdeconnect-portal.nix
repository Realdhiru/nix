{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, qt6
, wayland
, wayland-scanner
, libxkbcommon
, libei
}:

stdenv.mkDerivation rec {
  pname = "hypr-kdeconnect-portal";
  version = "0.1.0-unstable-2026-09-06";

  src = fetchFromGitHub {
    owner = "gfhdhytghd";
    repo = "hypr-kdeconnect-fix";
    rev = "0bc47e676ae2d6964cec4020be9966bbe85985e6";
    hash = "sha256-s8hWpEIyWpwW9w8t80Byqp+8jG0ChddtbDB7eJ/7ebA=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    wayland-scanner
  ];

  buildInputs = [
    qt6.qtbase
    wayland
    libxkbcommon
    libei
  ];

  cmakeFlags = [
    "-DBUILD_TESTING=ON"
  ];

  meta = with lib; {
    description = "KDE Connect RemoteDesktop portal backend for virtual-input Wayland compositors (Hyprland)";
    homepage = "https://github.com/gfhdhytghd/hypr-kdeconnect-fix";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
