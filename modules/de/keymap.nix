# Shared semantic bindings; renderers translate actions, never duplicate keys.
{
  flake.modules.homeManager.de-keymap = {
    config,
    lib,
    ...
  }: let
    inherit (lib) mkOption types;
    binding = key: modifiers: action: argument: {inherit key modifiers action argument;};
    directions = ["Left" "Right" "Up" "Down"];
    viKeys = {
      Left = "h";
      Right = "l";
      Up = "k";
      Down = "j";
    };
    directional = lib.concatMap (direction:
      lib.concatMap (key: [
        (binding key ["mod"] "focus" (lib.toLower direction))
        (binding key ["mod" "Shift"] "move" (lib.toLower direction))
      ]) [direction viKeys.${direction}])
    directions;
    workspaces = lib.concatMap (n: [
      (binding (toString n) ["mod"] "workspace" (toString n))
      (binding (toString n) ["mod" "Shift"] "move-workspace" (toString n))
    ]) (lib.range 1 9);
    bindingType = types.submodule {
      options = {
        key = mkOption {
          type = types.str;
          description = "XKB keysym.";
        };
        modifiers = mkOption {
          type = types.listOf (types.enum ["mod" "Shift" "Control" "Alt"]);
          default = ["mod"];
          description = "Modifiers; mod resolves through de.keymap.mod.";
        };
        action = mkOption {
          type = types.enum ["exec" "close" "fullscreen" "float" "focus" "move" "workspace" "move-workspace" "resize-mode" "resize" "default-mode" "split" "lock" "exit"];
          description = "Window-manager-independent action.";
        };
        argument = mkOption {
          type = types.str;
          default = "";
          description = "Direction, workspace, or command name.";
        };
      };
    };
  in {
    options.de.keymap = {
      mod = mkOption {
        type = types.enum ["SUPER" "ALT" "CONTROL"];
        default = "SUPER";
        description = "Primary desktop modifier.";
      };
      commands = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Commands referenced by semantic exec bindings; lock is supplied by the session.";
      };
      bindings = mkOption {
        type = types.listOf bindingType;
        default =
          [
            (binding "Return" ["mod"] "exec" "terminal")
            (binding "d" ["mod"] "exec" "launcher")
            (binding "e" ["mod"] "exec" "files")
            (binding "Tab" ["mod"] "exec" "switcher")
            (binding "q" ["mod"] "close" "")
            (binding "f" ["mod"] "fullscreen" "")
            (binding "space" ["mod" "Shift"] "float" "")
            (binding "space" ["mod"] "split" "")
            (binding "r" ["mod"] "resize-mode" "")
            (binding "x" ["mod" "Shift"] "lock" "")
            (binding "e" ["mod" "Shift"] "exit" "")
          ]
          ++ directional ++ workspaces;
        description = "Bindings shared by all desktop sessions.";
      };
      resizeBindings = mkOption {
        type = types.listOf bindingType;
        default =
          map (direction: binding direction [] "resize" (lib.toLower direction)) directions
          ++ map (key: binding key [] "default-mode" "") ["Escape" "Return"];
        description = "Bindings active in resize mode.";
      };
    };
    config.de.keymap.commands = lib.mapAttrs (_: lib.mkOptionDefault) {
      terminal = "kitty";
      launcher = "rofi -show drun";
      files = "dolphin";
    };
    config.assertions = let
      check = bindings: let
        keys = map (b: lib.concatStringsSep "+" (b.modifiers ++ [b.key])) bindings;
      in {
        assertion = builtins.length keys == builtins.length (lib.unique keys);
        message = "de.keymap contains duplicate key combinations.";
      };
    in
      map check [config.de.keymap.bindings config.de.keymap.resizeBindings];
  };
}
