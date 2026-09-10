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
    launcher = pkgs.writeShellScript "desktop-polybar" ''
      child=""
      monitor=""
      cleanup() {
        if [ -n "$child" ]; then
          kill "$child" 2>/dev/null || true
          wait "$child" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT
      trap 'exit 0' INT TERM HUP
      while outputs="$(${pkgs.xrandr}/bin/xrandr --query 2>/dev/null)"; do
        primary="$(printf '%s\n' "$outputs" | ${pkgs.gawk}/bin/awk '$2 == "connected" && $3 == "primary" { print $1; exit }')"
        if [ -z "$primary" ]; then
          primary="$(printf '%s\n' "$outputs" | ${pkgs.gawk}/bin/awk '$2 == "connected" { print $1; exit }')"
        fi
        if [ "$primary" != "$monitor" ] || [ -z "$child" ] || ! kill -0 "$child" 2>/dev/null; then
          cleanup
          child=""
          monitor="$primary"
          if [ -n "$monitor" ]; then
            MONITOR="$monitor" ${pkgs.polybar}/bin/polybar -c ${config.xdg.configFile."polybar/config.ini".source} desktop &
            child=$!
          fi
        fi
        ${pkgs.coreutils}/bin/sleep 2
      done
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
        "wm-restack" = "i3";
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
