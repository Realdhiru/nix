{ pkgs, ... }:

{
  # Virtual Webcam Loopback (/dev/video10) for DroidCam, OBS, and Phone-as-Webcam streaming
  boot.extraModulePackages = [ pkgs.linuxPackages_latest.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  boot.extraModprobeConfig = ''
    options v4l2loopback card_label="Webcam" video_nr=10 exclusive_caps=1
  '';
}

