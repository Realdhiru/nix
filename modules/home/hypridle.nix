{
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd = "pidof quickshell || ~/.config/hypr/scripts/lock.sh";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300; # 5 mins: Lock screen
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330; # 5.5 mins: Turn off screen (Saves battery!)
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 900; # 15 mins: Suspend laptop
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}