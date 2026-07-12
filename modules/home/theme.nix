# modules/home/theme.nix
{ pkgs, ... }:

{
  gtk = {
    enable = true;
    
    # Leverages GTK's native, built-in dark theme (zero extra packages)
    theme.name = "Adwaita-dark";
    
    iconTheme = {
      name = "buuf-nestort";
      package = pkgs.buuf-nestort-icon-theme;
    };

    # Force GTK3/GTK4 apps to respect the dark variant preference
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Declaratively define Thunar custom actions
  xdg.configFile."Thunar/uca.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
      <action>
        <icon>utilities-terminal</icon>
        <name>Open Terminal Here</name>
        <submenu></submenu>
        <unique-id>terminal-action</unique-id>
        <command>wezterm start --cwd %f</command>
        <description>Open WezTerm in current directory</description>
        <patterns>*</patterns>
        <startup-notify/>
        <directories/>
      </action>
      <action>
        <icon>document-print</icon>
        <name>Print</name>
        <submenu></submenu>
        <unique-id>print-action</unique-id>
        <command>lp %F</command>
        <description>Send selected file(s) to default printer</description>
        <patterns>*</patterns>
        <image-files/>
        <other-files/>
        <text-files/>
        <document-files/>
      </action>
    </actions>
  '';
}