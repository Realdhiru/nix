{
  # Primary user credentials and system identities.
  # When forking or installing on a new machine, change these values.
  username = "realdhiru";
  name = "D";
  hostname = "NixOS";

  # Hardware IDs specific to user peripherals (e.g. external mouse dongle)
  # Protected against TLP autosuspend on battery to prevent wake-up input lag.
  usbDenylist = "3554:fc00";
}

