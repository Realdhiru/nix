{ pkgs, ... }:

{
  # ---- Steam ----
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # ---- GameMode: CPU governor/renice/IO-priority bump while a game runs ----
  # No GPU-power-state section here on purpose: gamemode's gpu.* knobs
  # (core/mem clock offsets) target discrete AMD/NVIDIA cards with exposed
  # power states. Iris Xe has no equivalent userspace clocking knob Mesa
  # exposes to gamemode, so setting apply_gpu_optimisations here would be
  # a silent no-op — omitted rather than left in as dead config.
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
        softrealtime = "auto";
      };
    };
  };

  # ---- MangoHud: FPS/frametime/thermal overlay ----
  # No NixOS module for this exists (programs.mangohud is not a real
  # option — confirmed by the actual eval error) — it's just the
  # mangohud package plus a plain config file MangoHud reads itself.
  environment.etc."mangohud/MangoHud.conf".text = ''
    cpu_temp
    gpu_temp
    ram
    vram
    frame_timing
    gpu_name
    engine_version
    position=top-left
    toggle_hud=Shift_R+F12
  '';

  # 32-bit graphics support — required for 32-bit Proton/Wine titles
  # (most older games). Was completely absent before; without it Steam
  # can fail to launch or silently drop 32-bit games entirely.
  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    # Launchers / prefix managers
    lutris
    heroic
    bottles
    protonup-qt      # GUI for installing GE-Proton/Wine-GE builds into Steam/Lutris

    # Iris Xe-specific: internal-resolution render + FSR upscale, and a
    # standalone sharpening/upscale Vulkan layer for games gamescope
    # doesn't wrap (e.g. borderless-windowed titles).
    # Usage: Steam launch options -> gamescope -w <internal> -h <internal> -W <output> -H <output> --fsr -- %command%
    gamescope
    vkbasalt

    # Manual Wine prefix tooling (Lutris/raw wine, not Steam/Bottles —
    # see note above on why standalone dxvk/vkd3d packages aren't here)
    winetricks
  ];
}
