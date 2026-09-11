{
  flake.modules.homeManager.i3 = {
    config,
    lib,
    pkgs,
    ...
  }: let
    python = pkgs.python3.withPackages (ps: [ps.i3ipc]);
    singleWindow = pkgs.writeShellScript "i3-single-window" ''
      exec ${python}/bin/python3 ${./_scripts/i3-single-window.py}
    '';
    keymap = config.de.keymap;
    mod =
      {
        SUPER = "Mod4";
        ALT = "Mod1";
        CONTROL = "Control";
      }.${
        keymap.mod
      };
    combo = b:
      lib.concatStringsSep "+" ((map (m:
          if m == "mod"
          then mod
          else if m == "Alt"
          then "Mod1"
          else m)
        b.modifiers)
        ++ [b.key]);
    render = b:
      {
        exec = "exec --no-startup-id ${keymap.commands.${b.argument}}";
        close = "kill";
        fullscreen = "fullscreen toggle";
        float = "floating toggle";
        focus = "focus ${b.argument}";
        move = "move ${b.argument}";
        workspace = "workspace number ${b.argument}";
        move-workspace = "move container to workspace number ${b.argument}";
        resize-mode = "mode resize";
        resize =
          {
            left = "resize shrink width 10 px or 10 ppt";
            right = "resize grow width 10 px or 10 ppt";
            up = "resize shrink height 10 px or 10 ppt";
            down = "resize grow height 10 px or 10 ppt";
          }.${
            b.argument
          };
        default-mode = "mode default";
        split = "layout toggle split";
        lock = "exec --no-startup-id ${keymap.commands.lock}";
        exit = "exit";
      }.${
        b.action
      };
    bindings = bs:
      builtins.listToAttrs (map (b: {
          name = combo b;
          value = render b;
        })
        bs);
  in {
    de.keymap.commands.lock = lib.mkDefault "${pkgs.i3lock}/bin/i3lock -n -c 222222";
    xsession.enable = true;
    xsession.windowManager.i3 = {
      enable = true;
      config = {
        modifier = mod;
        terminal = keymap.commands.terminal;
        menu = keymap.commands.launcher;
        keybindings = bindings keymap.bindings;
        modes.resize = bindings keymap.resizeBindings;
        bars = [];
        startup = [
          {
            command = toString singleWindow;
            notification = false;
          }
        ];
        gaps = {
          smartGaps = true;
          inner = 5;
          outer = 20;
        };
      };
    };
    services.dunst.enable = true;
  };
}
