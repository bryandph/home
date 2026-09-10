{
  flake.modules.homeManager.hyprland = {
    config,
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

    # rofi's X11 window mode cannot enumerate native Wayland clients.
    # Keep the shared switcher binding and rofi UI, selecting via Hyprland IPC.
    windowSwitcher = pkgs.writeShellScript "hyprland-window-switcher" ''
      clients="$(${pkgs.hyprland}/bin/hyprctl clients -j)"
      selection="$(printf '%s' "$clients" | ${pkgs.jq}/bin/jq -r '.[] | "[\(.workspace.name)] \(.class): \(.title | gsub("[\\n\\r]"; " "))"' | ${config.programs.rofi.package}/bin/rofi -config ${config.home.file.${config.programs.rofi.configPath}.source} -dmenu -i -format i -p Windows)" || exit 0
      case "$selection" in ""|*[!0-9]*) exit 0 ;; esac
      address="$(printf '%s' "$clients" | ${pkgs.jq}/bin/jq -r --argjson index "$selection" '.[$index].address // empty')"
      if [ -n "$address" ]; then
        ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow "address:$address"
      fi
    '';
    keymap = config.de.keymap;
    combo = b:
      lib.concatStringsSep " + " ((map (m:
          if m == "mod"
          then keymap.mod
          else lib.toUpper m)
        b.modifiers)
        ++ [b.key]);
    exec = command: "hl.dsp.exec_cmd(${builtins.toJSON command})";
    dispatch = command: exec "hyprctl dispatch ${command}";
    render = b:
      {
        exec = exec keymap.commands.${b.argument};
        close = "hl.dsp.window.close()";
        fullscreen = dispatch "fullscreen 0";
        float = ''hl.dsp.window.float({ action = "toggle" })'';
        focus = ''hl.dsp.focus({ direction = "${b.argument}" })'';
        move = dispatch "movewindow ${{
            left = "l";
            right = "r";
            up = "u";
            down = "d";
          }.${
            b.argument
          }}";
        workspace = dispatch "workspace ${b.argument}";
        move-workspace = dispatch "movetoworkspacesilent ${b.argument}";
        resize-mode = ''hl.dsp.submap("resize")'';
        resize = dispatch "resizeactive ${{
            left = "-10 0";
            right = "10 0";
            up = "0 -10";
            down = "0 10";
          }.${
            b.argument
          }}";
        default-mode = ''hl.dsp.submap("reset")'';
        split = ''hl.dsp.layout("togglesplit")'';
        lock = exec keymap.commands.lock;
        exit = dispatch "exit";
      }.${
        b.action
      };
    bind = b: {_args = [(combo b) (mkLuaInline (render b))];};
  in {
    de.keymap.commands.lock = lib.mkDefault "hyprlock";
    de.keymap.commands.switcher = lib.mkDefault (toString windowSwitcher);
    services.hyprpaper.enable = true;

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          lock_cmd = keymap.commands.lock;
        };
        listener = [
          {
            timeout = 900;
            on-timeout = keymap.commands.lock;
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
      waypipe
    ];
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      # Hyprland 0.55+ uses Lua; hyprlang is deprecated. (home#1)
      configType = "lua";
      settings = {
        # Shared primary modifier
        mod._var = keymap.mod;

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

        bind = map bind keymap.bindings;
        define_submap._args = [
          "resize"
          (mkLuaInline ("function()\n" + lib.concatMapStringsSep "\n" (b: "hl.bind(${builtins.toJSON (combo b)}, ${render b})") keymap.resizeBindings + "\nend"))
        ];
      };
    };
  };
}
