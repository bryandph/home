{
  flake.modules.homeManager.waybar = {
    programs.waybar = {
      enable = true;
      systemd.enable = false;
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        modules-left = ["hyprland/workspaces"];
        modules-center = ["clock"];
        modules-right = ["pulseaudio" "tray"];
        clock.format = "{:%a %d %b  %H:%M}";
        pulseaudio = {
          format = "Volume {volume}%";
          format-muted = "Muted";
          on-click = "pavucontrol";
        };
        tray.spacing = 8;
      };
    };
  };
}
