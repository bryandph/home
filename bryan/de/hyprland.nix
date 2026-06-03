{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  # Hyprland 0.55 moved configs from hyprlang to Lua. The home-manager
  # module (configType = "lua") turns each `settings` entry into an
  # `hl.<name>(...)` call; `_var` becomes a Lua local, `_args` a
  # multi-arg call, and `mkLuaInline` emits raw Lua. See
  # https://wiki.hypr.land/Configuring/Start/ and ../../../ issue home#1.

  # `hl.bind(mod .. " + <combo>", <dispatch>)` — combo is appended to the
  # `mod` Lua local; dispatch is raw Lua.
  bind = combo: dispatch: {
    _args = [
      (mkLuaInline ''mod .. " + ${combo}"'')
      (mkLuaInline dispatch)
    ];
  };

  focus = dir: ''hl.dsp.focus({ direction = "${dir}" })'';

  # movewindow has no confirmed native hl.dsp.* on 0.55, so dispatch via
  # hyprctl to preserve the exact prior behavior without risking a
  # nil-function error that would break the whole config load.
  moveWindow = dir: ''hl.dsp.exec_cmd("hyprctl dispatch movewindow ${dir}")'';
in {
  services.hyprpaper.enable = true;

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };
      listener = [
        {
          timeout = 900;
          on-timeout = "hyprlock";
        }
        {
          timeout = 1200;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
  programs = {
    hyprshell = {
      enable = true;
    };
    hyprlock.enable = true;
  };
  home.packages = with pkgs; [
    waybar
    waypipe
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    # Hyprland 0.55+ uses Lua; hyprlang is deprecated. (home#1)
    configType = "lua";
    settings = {
      # local mod = "ALT"
      mod._var = "ALT";

      # hl.config({ ... })
      config = {
        general = {
          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;
          layout = "dwindle";
        };
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
        };
        animations.enabled = true;
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad.natural_scroll = false;
        };
        ecosystem.no_update_news = true;
      };

      # hl.curve("myBezier", { type = "bezier", points = { ... } })
      curve._args = [
        "myBezier"
        {
          type = "bezier";
          points = [
            [0.05 0.9]
            [0.1 1.05]
          ];
        }
      ];

      # one hl.animation({ ... }) per element
      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 7;
          bezier = "myBezier";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 7;
          bezier = "default";
          style = "popin 80%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "borderangle";
          enabled = true;
          speed = 8;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 7;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 6;
          bezier = "default";
        }
      ];

      # hl.on("hyprland.start", function() hl.exec_cmd("waybar") end)
      on._args = [
        "hyprland.start"
        (mkLuaInline ''function() hl.exec_cmd("waybar") end'')
      ];

      # hl.bind(...) per element
      bind = [
        (bind "Return" ''hl.dsp.exec_cmd("kitty")'')
        (bind "q" "hl.dsp.window.close()")
        (bind "M" ''hl.dsp.exec_cmd("hyprctl dispatch exit")'')
        (bind "E" ''hl.dsp.exec_cmd("dolphin")'')
        (bind "V" ''hl.dsp.window.float({ action = "toggle" })'')
        (bind "F" ''hl.dsp.exec_cmd("wofi --show drun")'')
        (bind "P" "hl.dsp.window.pseudo()")
        (bind "J" ''hl.dsp.layout("togglesplit")'')

        (bind "left" (focus "left"))
        (bind "right" (focus "right"))
        (bind "up" (focus "up"))
        (bind "down" (focus "down"))

        (bind "SHIFT + H" (moveWindow "l"))
        (bind "SHIFT + L" (moveWindow "r"))
        (bind "SHIFT + K" (moveWindow "u"))
        (bind "SHIFT + J" (moveWindow "d"))

        (bind "SHIFT + left" (moveWindow "l"))
        (bind "SHIFT + right" (moveWindow "r"))
        (bind "SHIFT + up" (moveWindow "u"))
        (bind "SHIFT + down" (moveWindow "d"))
      ];
    };
  };
}
