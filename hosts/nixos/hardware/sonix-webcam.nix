{ pkgs, ... }:

{
  # Hardware Quirk: Sonix Technology USB 2.0 FHD UVC WebCam (3277:0022)
  # The hardware USB controller has a firmware bug that triggers USB babble disconnects
  # whenever MJPEG is requested or when input geometry is forced.
  # This module creates a v4l2loopback virtual device (/dev/video10) and an on-demand
  # feeder service that streams native 1080p@5fps YUYV pass-through with zero CPU load.

  boot.extraModulePackages = [ pkgs.linuxPackages_latest.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  boot.extraModprobeConfig = ''
    options uvcvideo nodrop=1
    options v4l2loopback card_label="Virtual Webcam" video_nr=10
  '';

  # On-demand virtual webcam loopback feeder service
  systemd.user.services.camera-loopback = {
    description = "Sonix Webcam Loopback Feeder → /dev/video10";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [ pkgs.ffmpeg pkgs.coreutils pkgs.bash ];

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash %h/nix/dotfiles/hypr/scripts/camera-loopback.sh";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
