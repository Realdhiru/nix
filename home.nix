{ config, pkgs, inputs, user, lib, ... }:

{
  imports = [
    ./modules/home/audio.nix
    ./modules/home/desktop-state.nix
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
  ];

  # Declarative Default Wallpaper (Flake store-path)
  home.sessionVariables.DEFAULT_WALLPAPER = "${./dotfiles/wallpaper/default.jpg}";
  home.sessionVariables.DESKTOP_STATE_DIR = config.desktop.stateDir;
  home.sessionVariables.TERMINAL = "alacritty";
  home.sessionVariables.BROWSER = "brave";
  home.sessionVariables.EDITOR = "gram";
  home.sessionVariables.FILEMANAGER = "pcmanfm-qt";
  xdg.configFile."environment.d/wallpaper.conf".text =
    "DEFAULT_WALLPAPER=${./dotfiles/wallpaper/default.jpg}\n";
  xdg.configFile."environment.d/desktop_state.conf".text =
    "DESKTOP_STATE_DIR=${config.desktop.stateDir}\n";

  # Host-specific refresh policy for the Samsung panel. Available modes come
  # from Hyprland; monitors/intent.json remains the authority for layout,
  # resolution, scale, transform, and placement.
  xdg.configFile."hypr-local/monitors.lua" = {
    force = true;
    text = ''
      local hyprctl = "${pkgs.hyprland}/bin/hyprctl"
      local jq = "${pkgs.jq}/bin/jq"
      local flock = "${pkgs.util-linux}/bin/flock"
      local output_name = "eDP-1"
      local output_desc = "Samsung Display Corp. 0x4180"
      local display_key = "desc:" .. output_desc
      local desktop_state = os.getenv("DESKTOP_STATE_DIR") or ((os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/desktop")
      local monitors_dir = desktop_state .. "/monitors"
      local intent_file = monitors_dir .. "/intent.json"
      local lock_file = intent_file .. ".lock"
      local tmp_file = intent_file .. ".tmp"

      local function shell_quote(value)
          local quote = string.char(39)
          local replacement = quote .. string.char(92) .. quote .. quote
          return quote .. tostring(value):gsub(quote, replacement) .. quote
      end

      local function is_ac_online()
          for _, path in ipairs({
              "/sys/class/power_supply/AC0/online",
              "/sys/class/power_supply/ADP1/online",
              "/sys/class/power_supply/AC/online",
              "/sys/class/power_supply/ucsi-source-psy-USBC000:001/online"
          }) do
              local f = io.open(path, "r")
              if f then
                  local v = f:read("*l")
                  f:close()
                  if v == "1" then return true end
              end
          end
          return false
      end

      local function read_intent()
          local query = string.format(
              "%s -r --arg key %s --arg name %s '[(.layout // \"extend\"), (.displays[$key].mode // .displays[$name].mode // \"\"), (.displays[$key].scale // .displays[$name].scale // \"\"), (.displays[$key].transform // .displays[$name].transform // \"\")] | @tsv' %s 2>/dev/null",
              shell_quote(jq), shell_quote(display_key), shell_quote(output_name), shell_quote(intent_file)
          )
          local pipe = io.popen(query, "r")
          if not pipe then return "extend", "", "", "" end
          local line = pipe:read("*l") or ""
          pipe:close()
          local layout, mode, scale, transform = line:match("([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
          return layout or "extend", mode or "", scale or "", transform or ""
      end

      local function get_available_modes()
          local command = string.format(
              "%s monitors all -j 2>/dev/null | %s -r '.[] | select(.name == \"%s\" or .description == \"%s\") | .availableModes[]?'",
              shell_quote(hyprctl), shell_quote(jq), output_name, output_desc
          )
          local pipe = io.popen(command, "r")
          if not pipe then return {} end
          local modes = {}
          for line in pipe:lines() do
              local w, h, rate = line:match("^(%d+)x(%d+)@([%d%.]+)Hz$")
              if w and h and rate then
                  table.insert(modes, { width = tonumber(w), height = tonumber(h), rate = tonumber(rate) })
              end
          end
          pipe:close()
          return modes
      end

      local function parse_mode(mode)
          if not mode or mode == "" then return nil, nil end
          local w, h = mode:match("^(%d+)x(%d+)@")
          return tonumber(w), tonumber(h)
      end

      local function choose_mode(modes, width, height, target_rate)
          local chosen, fallback
          for _, mode in ipairs(modes) do
              if mode.width == width and mode.height == height then
                  if not fallback or mode.rate < fallback.rate then fallback = mode end
                  if mode.rate <= target_rate and (not chosen or mode.rate > chosen.rate) then
                      chosen = mode
                  end
              end
          end
          chosen = chosen or fallback
          if not chosen then return nil end
          return string.format("%dx%d@%d", chosen.width, chosen.height, math.floor(chosen.rate + 0.5))
      end

      local layout, saved_mode, saved_scale, saved_transform = read_intent()
      local active_output
      for _, monitor in ipairs(hl.get_monitors()) do
          if monitor.name == output_name then active_output = monitor end
      end

      local modes = get_available_modes()
      if #modes == 0 then return end

      local width, height = parse_mode(saved_mode)
      if not width and active_output then
          width, height = tonumber(active_output.width), tonumber(active_output.height)
      end
      if not width then
          local largest
          for _, mode in ipairs(modes) do
              if not largest or mode.width * mode.height > largest.width * largest.height then largest = mode end
          end
          if largest then width, height = largest.width, largest.height end
      end
      if not width or not height then return end

      local target_rate = is_ac_online() and 120 or 60
      local target_mode = choose_mode(modes, width, height, target_rate)
      if not target_mode then return end

      local scale = tonumber(saved_scale) or (active_output and tonumber(active_output.scale)) or 2
      local transform = tonumber(saved_transform) or (active_output and tonumber(active_output.transform)) or 0
      local jq_filter = '.layout = (.layout // "extend") | .displays = (.displays // {}) | ($key) as $k | .displays[$k] = ((.displays[$k] // {scale: $scale, transform: $transform}) + {name: $name, description: $description, mode: $mode})'
      local write_command = string.format(
          "mkdir -p %s && (%s 9; [ -s %s ] || %s -n '{layout:\"extend\",displays:{}}' > %s; %s --arg key %s --arg name %s --arg description %s --arg mode %s --argjson scale %s --argjson transform %s '%s' %s > %s && mv -f %s %s) 9>%s",
          shell_quote(monitors_dir), shell_quote(flock), shell_quote(intent_file), shell_quote(jq), shell_quote(intent_file),
          shell_quote(jq), shell_quote(display_key), shell_quote(output_name), shell_quote(output_desc), shell_quote(target_mode), tostring(scale), tostring(transform),
          jq_filter, shell_quote(intent_file), shell_quote(tmp_file), shell_quote(tmp_file), shell_quote(intent_file), shell_quote(lock_file)
      )
      os.execute(write_command)

      -- get_monitors() contains active outputs only, so a disabled internal panel
      -- stays disabled while an external-only layout is selected.
      if active_output then
          hl.monitor({ output = output_name, mode = target_mode, scale = scale, transform = transform })
      end
    '';
  };

  # Universal Hardware Acceleration Wrapper for Brave & Web Apps:
  # Injects VA-API zero-copy and ANGLE GL flags into the PATH wrapper, ensuring
  # hardware decoding on Intel/AMD/Nvidia without relying on unparsed flags.conf.
  # Dynamically suppresses detached DownloadBubble popup subsurfaces via partial_view_enabled
  # profile preferences to prevent out-of-screen Wayland anchor offset bugs in app and multi-window modes.
  home.file.".local/bin/brave" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      for pref in "$HOME/.config/BraveSoftware/Brave-Browser/"*"/Preferences"; do
        if [ -f "$pref" ] && command -v jq >/dev/null 2>&1; then
          if jq -e '.download_bubble.partial_view_enabled != false' "$pref" >/dev/null 2>&1; then
            tmp="$pref.tmp.$$"
            jq '.download_bubble.partial_view_enabled = false' "$pref" > "$tmp" && mv -f "$tmp" "$pref"
          fi
        fi
      done

      exec /run/current-system/sw/bin/brave \
        --use-gl=angle \
        --use-angle=gl \
        --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations \
        --enable-zero-copy \
        "$@"
    '';
  };

  # Declarative OnlyOffice Wrapper:
  # Enforces system window decorations to prevent CEF custom titlebar redraw/blanking drops under XWayland.
  home.file.".local/bin/onlyoffice-desktopeditors" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec /run/current-system/sw/bin/onlyoffice-desktopeditors --system-title-bar "$@"
    '';
  };

  xdg.configFile."hypr" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/hypr";
    force = true;
  };

  xdg.configFile."fuzzel" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fuzzel";
    force = true;
  };


  xdg.configFile."fastfetch/config.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fastfetch.jsonc";
    force = true;
  };
      
  xdg.configFile."wallust" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wallust";
    force = true;
  };

  xdg.configFile."wallpaper" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wallpaper";
    force = true;
  };

  # Declarative mpv MPRIS plugin symlink (auto-tracked across nix store generations)
  xdg.configFile."mpv/scripts/mpris.so" = {
    source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
    force = true;
  };

  # Hide misleading / unused entries from application launcher (Fuzzel)
  xdg.desktopEntries."pcmanfm-qt-desktop-pref" = {
    name = "Desktop";
    noDisplay = true;
  };

  xdg.desktopEntries."org.opengamingcollective.rog-control-center" = {
    name = "ROG Control Center";
    noDisplay = true;
  };

  # Mutable user-managed MIME associations (allows casual right-click "Set as Default" in PCManFM-Qt)
  xdg.mimeApps.enable = false;

  # WirePlumber: Disable conflicting libcamera monitor so UVC cameras are exclusively handled by V4L2
  xdg.configFile."wireplumber/wireplumber.conf.d/50-disable-libcamera.conf" = {
    force = true;
    text = ''
      wireplumber.profiles = {
        main = {
          monitor.libcamera = disabled
        }
      }
    '';
  };


  # PCManFM-Qt: file-based config (app reads/writes this INI directly, no
  # other mechanism), so the few mixed settings live inline here.
  xdg.configFile."pcmanfm-qt/default/settings.conf" = {
    force = true;
    text = ''
      [Places]
      HiddenPlaces=/home/${user.username}/Desktop, menu:///applications/

      [System]
      Terminal=alacritty
      Archiver=lxqt-archiver

      [Thumbnail]
      MaxThumbnailFileSize=262144
    '';
  };


  # Focus time tracking daemon — single authoritative lifecycle owner.
  # Previously launched via Hyprland `exec-once` + a shell supervisor loop
  # (launch_daemon.sh); both removed. systemd restarts it on crash, boots,
  # Hyprland restarts, nixos-rebuild, etc. without any other supervision.
  systemd.user.services.focustime-daemon = {
    Unit = {
      Description = "Focus time tracking daemon (Hyprland active window)";
    };
    Service = {
      ExecStart = "%h/.config/hypr/scripts/quickshell/focustime/focus_daemon";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "QS_STATE_FOCUSTIME=%h/.local/state/desktop/focustime"
        "QS_RUN_FOCUSTIME=%t/quickshell/focustime"
        "PATH=/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Clipboard history recorders — supervised systemd replacements for the
  # unsupervised `wl-paste --watch cliphist store` one-shots previously
  # launched from Hyprland startup.lua. If a watcher dies (or Hyprland
  # restarts and the Wayland socket drops), systemd restarts it in 2s so
  # cliphist can never silently stop recording. Same process count as
  # before, no resident shell, zero extra battery cost.
  systemd.user.services.cliphist-text-watcher = {
    Unit = {
      Description = "Record text clipboard selections into cliphist history";
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.cliphist-image-watcher = {
    Unit = {
      Description = "Record image clipboard selections into cliphist history";
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Declarative wallpaper daemon managed by systemd
  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon --no-cache --format argb";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Per-output mpvpaper video wallpaper template service
  systemd.user.services."mpvpaper@" = {
    Unit = {
      Description = "mpvpaper video wallpaper for %i";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      EnvironmentFile = "%h/.local/state/mpvpaper/%i.env";
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p -o \"no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=%t/mpvpaper-%i.sock\" %i \${WALLPAPER_VIDEO}";
      Restart = "on-failure";
    };
  };

  # Declarative color temperature and display CTM daemon managed by systemd
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "hyprsunset color temperature and gamma manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset -i";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Native event-driven refresh rate updater on AC plug/unplug events
  systemd.user.services.hypr-refresh-rate = {
    Unit = {
      Description = "Apply declarative monitor refresh rate on power event";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "apply-refresh-rate" ''
        set -euo pipefail
        if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
          SIG=$(find "$runtime_dir/hypr" -maxdepth 2 -name ".socket.sock" -printf '%T@ %h\n' 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}' | xargs -r basename || true)
          if [ -n "$SIG" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
          fi
        fi
        if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          echo "hypr-refresh-rate: failed to find active HYPRLAND_INSTANCE_SIGNATURE in ''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" >&2
          exit 1
        fi
        echo "hypr-refresh-rate: applying monitors.lua with signature $HYPRLAND_INSTANCE_SIGNATURE"
        ${pkgs.hyprland}/bin/hyprctl eval "dofile(os.getenv('HOME') .. '/.config/hypr-local/monitors.lua')"
      ''}";
    };
  };


  programs.alacritty.enable = true;

  xdg.configFile."alacritty/alacritty.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/alacritty/alacritty.toml";
    force = true;
  };

  home.username = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
