{ config, lib, pkgs, ... }:

let
  asusctl = config.services.asusd.package;

  asus-shutdown-unit = pkgs.writeText "asus-shutdown.service" ''
    [Unit]
    Description=ASUS Deferred Shutdown Handler
    Before=shutdown.target reboot.target halt.target
    After=asusd.service systemd-logind.service network.target basic.target

    [Service]
    Environment=IS_SERVICE=1
    Environment=RUST_LOG="info,asus_shutdown=debug,zbus::connection::handshake::common=error,zbus::connection::handshake::client=error"
    ExecStart=${asusctl}/bin/asus-shutdown
    Restart=on-failure
    RestartSec=1
    Type=simple
    SELinuxContext=system_u:system_r:unconfined_t:s0
    KillSignal=SIGTERM
    SendSIGKILL=no
    TimeoutStopSec=45

    AmbientCapabilities=
    CapabilityBoundingSet=
    MemoryDenyWriteExecute=true
    NoNewPrivileges=true
    LockPersonality=true
    KeyringMode=private

    PrivateBPF=true
    PrivateIPC=true
    PrivateDevices=false
    PrivateNetwork=true
    PrivateMounts=true
    PrivateTmp=true
    PrivateUsers=false

    ProtectProc=default
    ProtectSystem=strict
    ProtectHome=true

    ProtectClock=true
    ProtectControlGroups=strict
    ProtectHostname=true
    ProtectKernelLogs=true
    ProtectKernelModules=true
    ProtectKernelTunables=true

    RestrictAddressFamilies=AF_UNIX
    RestrictNetworkInterfaces=lo
    RestrictNamespaces=true
    RestrictRealtime=true
    RestrictSUIDSGID=true

    ReadOnlyPaths=/
    RemoveIPC=true

    SystemCallArchitectures=native
    SystemCallFilter=@system-service
    SystemCallFilter=~@privileged @resources

    IPAddressDeny=any
    SocketBindDeny=any

    X-RestartIfChanged=false
    X-StopIfChanged=false

    [Install]
    WantedBy=multi-user.target
  '';

  # Copy of asusctl's systemd units with asus-shutdown.service replaced by
  # our coupling-free replica above. asusd.service stays byte-identical to
  # what the package ships (store paths included).
  asusctl-units = pkgs.runCommand "asusctl-systemd-units" { } ''
    mkdir -p $out/lib/systemd/system
    cp -rL ${asusctl}/lib/systemd/system/. $out/lib/systemd/system/
    rm -f $out/lib/systemd/system/asus-shutdown.service
    install -m 0644 ${asus-shutdown-unit} $out/lib/systemd/system/asus-shutdown.service
  '';
in
{
  # --- 1. KERNEL-LEVEL POWER FIXES ---
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
  };

  # --- 2. TLP CONFIGURATION (SOLE POWER MANAGER) ---
  # NixOS strictly forbids running both TLP and power-profiles-daemon
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # CPU & Performance Management (Restored to TLP)
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "quiet";

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # FIX: Prevent USB Bluetooth interface from dropping
      USB_AUTOSUSPEND = 0;
      USB_EXCLUDE_BTUSB = 1;
      USB_DENYLIST = "3554:fc00";

      # FIX: Prevent Wi-Fi interface from ignoring beacons
      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "off";

      SOUND_POWER_SAVE_ON_AC      = 1;
      SOUND_POWER_SAVE_ON_BAT     = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # Battery charge threshold managed by TLP directly
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0  = 80;
    };
  };

  services.asusd.enable = true;

  # asus-shutdown holds a logind shutdown inhibitor and acts exactly once, at
  # real shutdown (deferred ASUS GPU firmware writes, exits on PrepareForShutdown).
  # Its SIGTERM handler deliberately refuses to exit mid-session and the unit has
  # SendSIGKILL=no — so it must never be stopped/restarted on live config changes.
  # The packaged unit couples its lifecycle to asusd.service (Requires=/PartOf=),
  # so a live asusd unit swap (e.g. asusctl update) propagates a stop into the
  # handler -> SIGTERM deferral -> TimeoutStopSec=45 failure -> switch exits 4.
  # systemd cannot remove dependency directives via drop-ins (systemd.unit(5)),
  # and suppressedSystemUnits would drop the whole unit (and is a no-op for
  # systemd.packages anyway) — so systemd.packages ships a copy of asusctl's
  # units where asus-shutdown.service is an exact replica minus the coupling.
  # X-RestartIfChanged=false / X-StopIfChanged=false keep switch-to-configuration
  # from ever stopping it; the new asusctl version is picked up at next boot.
  systemd.packages = lib.mkForce [ asusctl-units ];


  # --- 3. ASUS CHARGER-CONNECTED PERFORMANCE FIX ---
  # When battery is capped at 80%, ASUS firmware reports power source as
  # "Battery" even though charger is physically connected.
  # These rules force TLP into AC/performance mode natively.
  #
  # This udev rule is the SOLE authority for tlp ac/bat switching in the
  # entire system. The Quickshell BatteryPopup.qml power-profile picker
  # intentionally does NOT call `tlp ac`/`tlp bat` itself — it only manages
  # per-core EPP (via set_epp.sh) and CPU turbo/boost, both of which are
  # orthogonal to AC/BAT mode. (power-profiles-daemon is force-disabled
  # above, so `powerprofilesctl` is never used anywhere in this config.)
  # Do not re-add a `tlp ac`/`tlp bat` call anywhere else; it would
  # silently race against this rule.
services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-USBC000:001", ATTR{online}=="1", \
      RUN+="${pkgs.tlp}/bin/tlp ac"

    SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-USBC000:001", ATTR{online}=="0", \
      RUN+="${pkgs.tlp}/bin/tlp bat"
  '';
  
}