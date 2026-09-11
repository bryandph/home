{
  flake.modules.homeManager.polybar = {
    config,
    lib,
    pkgs,
    ...
  }: let
    colors =
      config.lib.stylix.colors or {
        base00 = "222222";
        base02 = "555555";
        base05 = "eeeeee";
      };
    font = config.stylix.fonts.monospace.name or "monospace";
    python = pkgs.python3.withPackages (ps: [ps.xlib]);
    launcher = pkgs.writeShellScript "desktop-polybar" ''
      exec ${python}/bin/python3 ${./_scripts/polybar-edge.py} \
        ${config.xdg.configFile."polybar/config.ini".source} \
        ${pkgs.polybar}/bin/polybar ${pkgs.polybar}/bin/polybar-msg ${pkgs.xrandr}/bin/xrandr
    '';
  in {
    # Render config without a second systemd-owned bar competing with i3 startup.
    home.packages = [pkgs.polybar];
    xsession.windowManager.i3.config.startup = [
      {
        command = toString launcher;
        notification = false;
      }
    ];
    xdg.configFile."polybar/config.ini".text = lib.generators.toINI {} {
      "settings"."screenchange-reload" = true;
      "bar/desktop" = {
        monitor = "\${env:MONITOR:}";
        width = "100%";
        height = 28;
        "font-0" = "${font}:size=10;2";
        background = "#${colors.base00}";
        foreground = "#${colors.base05}";
        "modules-left" = "workspaces";
        "modules-center" = "clock";
        "modules-right" = "audio tray";
        "enable-ipc" = true;
        "override-redirect" = true;
      };
      "module/workspaces" = {
        type = "internal/i3";
        "label-focused" = "%index%";
        "label-unfocused" = "%index%";
        "label-focused-padding" = 1;
        "label-unfocused-padding" = 1;
        "label-focused-background" = "#${colors.base02}";
      };
      "module/clock" = {
        type = "internal/date";
        interval = 5;
        date = "%a %d %b  %H:%M";
        label = "%date%";
      };
      "module/audio" = {
        type = "internal/pulseaudio";
        "format-volume" = "Volume <label-volume>";
        "label-volume" = "%percentage%%";
        "label-muted" = "Muted";
        "click-right" = "pavucontrol";
      };
      "module/tray" = {
        type = "internal/tray";
        "tray-spacing" = 8;
      };
    };
  };
}
