# Vendored `programs.herdr` HM module — typed options over
# `~/.config/herdr/config.toml` (bryan/nixspace#86, capability
# agentic-user-tools). Option defaults reproduce the previously
# hand-maintained config, so enabling the module is behavior-preserving.
#
# Herdr legitimately writes runtime state into config.toml. Nix therefore
# renders only its desired projection and a launcher shim reconciles the
# Nix-owned keys into the writable live file before Herdr starts. Herdr writes
# its own settings under `[ui]`, so Nix owns `ui.<table>` entries rather than
# the whole section.
#
# Plugins are linked from the store by activation (`herdr plugin link`
# canonicalizes the path, so every new store path needs a relink); plugins
# dropped from the option are unlinked.
# Immutable agent-detection overrides remain direct Home Manager files. The
# package stays consumer-supplied (flake input / overlay).
#
# Default keybindings mirror shell/tmux.nix: ctrl+a prefix, vim pane focus
# with no-prefix alt+vim/alt+arrow fallbacks, shift+arrows for tab
# switching, and temporary TUI panes on mnemonic prefix chords. Herdr defaults
# that already
# match tmux (new_tab c, split v/-, focus hjkl, zoom z, copy-mode [,
# switch_tab 1..9) are left unset. To make room for the commands: goto moves
# g → f and toggle_sidebar moves b → e.
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.herdr;
  tomlFormat = pkgs.formats.toml {};

  keyBinding = lib.types.either lib.types.str (lib.types.listOf lib.types.str);

  commandType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "Key chord (e.g. \"prefix+g\").";
      };
      type = lib.mkOption {
        type = lib.types.enum ["pane" "popup"];
        default = "pane";
        description = "How the command opens.";
      };
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to run.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        description = "Label shown in herdr's key help.";
      };
    };
  };

  typedSettings =
    {
      keys =
        cfg.keys
        // lib.optionalAttrs (cfg.commands != []) {
          command = cfg.commands;
        };
    }
    // lib.optionalAttrs (cfg.terminal != {}) {inherit (cfg) terminal;};

  desiredSettings = typedSettings // cfg.extraConfig;
  desiredConfig = tomlFormat.generate "herdr-config-desired.toml" desiredSettings;
  herdrPython = pkgs.python3.withPackages (pythonPackages: [pythonPackages.tomlkit]);
  reconcileConfig = pkgs.writeShellApplication {
    name = "herdr-config-reconcile";
    runtimeInputs = [herdrPython];
    text = ''
      exec python3 ${./herdr-config-reconcile.py} "$@"
    '';
  };
  sshShim = import ./_herdr-ssh-shim.nix {
    inherit lib pkgs;
    noCompressionHosts = cfg.sshNoCompressionHosts;
    posixHosts = cfg.sshPosixHosts;
  };
  wrapArgs =
    lib.optionals (cfg.sshNoCompressionHosts ++ cfg.sshPosixHosts != []) ["--prefix" "PATH" ":" "${sshShim}/bin"]
    ++ ["--run" "${lib.getExe reconcileConfig} ${desiredConfig} --shared-table ui || exit $?"];
  pluginsJson = pkgs.writeText "herdr-plugins.json" (builtins.toJSON (lib.mapAttrs (_: toString) cfg.plugins));
  syncPlugins = pkgs.writeShellApplication {
    name = "herdr-plugins-sync";
    runtimeInputs = [cfg.package pkgs.coreutils pkgs.jq];
    text = builtins.readFile ./herdr-plugins-sync.sh;
  };
  wrappedPackage = pkgs.symlinkJoin {
    name = "herdr-wrapped";
    paths = [cfg.package];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/herdr" ${lib.escapeShellArgs wrapArgs}
    '';
  };

  conflictingKeys = lib.intersectLists (lib.attrNames typedSettings) (lib.attrNames cfg.extraConfig);
in {
  options.programs.herdr = {
    enable = lib.mkEnableOption "herdr";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The herdr package";
    };

    keys = lib.mkOption {
      type = lib.types.attrsOf keyBinding;
      default = {
        prefix = "ctrl+a";
        # tmux detaches on prefix+d; keep herdr's prefix+q too
        detach = ["prefix+d" "prefix+q"];
        # no-prefix pane focus (tmux: bind -n M-h/j/k/l + M-arrows); alt+up/down
        # stay with Pi (message dequeue, model reorder — shell/pi.nix)
        focus_pane_left = ["prefix+h" "alt+h" "alt+left"];
        focus_pane_down = ["prefix+j" "alt+j"];
        focus_pane_up = ["prefix+k" "alt+k"];
        focus_pane_right = ["prefix+l" "alt+l" "alt+right"];
        # no-prefix tab switching (tmux: bind -n S-Left/S-Right)
        previous_tab = ["prefix+p" "shift+left"];
        next_tab = ["prefix+n" "shift+right"];
        # displaced by the lazygit/btop command bindings
        goto = "prefix+f";
        toggle_sidebar = "prefix+e";
      };
      description = "Action → key chord(s) for herdr's [keys] section (tmux-parity defaults).";
    };

    commands = lib.mkOption {
      type = lib.types.listOf commandType;
      default = [
        {
          key = "prefix+g";
          type = "pane";
          command = "lazygit";
          description = "lazygit";
        }
        {
          key = "prefix+shift+k";
          type = "pane";
          command = "k9s";
          description = "k9s";
        }
        {
          key = "prefix+shift+f";
          type = "pane";
          command = "lf";
          description = "lf";
        }
        {
          key = "prefix+shift+h";
          type = "pane";
          command = "hx";
          description = "helix";
        }
        {
          key = "prefix+b";
          type = "pane";
          command = "btop";
          description = "btop";
        }
      ];
      description = "Command shortcuts rendered as [[keys.command]] tables.";
    };

    terminal = lib.mkOption {
      inherit (tomlFormat) type;
      default = {
        # Herdr resolves bare login-shell names against the detached server's
        # inherited PATH, which may omit the per-user Nix profile on macOS.
        default_shell = lib.getExe pkgs.nushell;
        # tmux parity: splits/tabs open in the pane's cwd (#{pane_current_path})
        new_cwd = "follow";
      };
      description = "The [terminal] section, verbatim (herdr key names).";
    };

    agentDetection = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      example = lib.literalExpression ''{ "claude.toml" = ./herdr/claude-detection.toml; }'';
      description = "Agent-detection manifest overrides installed under ~/.config/herdr/agent-detection/.";
    };

    sshNoCompressionHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["openshell-*"];
      description = ''
        SSH destination globs for which herdr's ssh/scp calls must not request
        compression. Herdr always passes `-C`; a shim first on herdr's PATH
        removes it for matching hosts only (the PATH also reaches herdr's panes).
      '';
    };

    sshPosixHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["blackwin" "mac"];
      description = ''
        SSH destination globs whose login shell is not POSIX (nushell).
        Herdr sends some remote commands unwrapped; the shim runs every
        command for these hosts under /bin/sh instead.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      example = lib.literalExpression ''{ "example.layout" = pkgs.callPackage ./layout-plugin.nix {}; }'';
      description = ''
        Plugin id → plugin directory (containing herdr-plugin.toml) linked by
        activation. The id must match the manifest's. Linked plugins are
        enabled; ones removed from this option are unlinked.
      '';
    };

    extraConfig = lib.mkOption {
      inherit (tomlFormat) type;
      default = {};
      description = "Freeform herdr config merged with the typed sections. Setting a top-level key both ways fails evaluation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = conflictingKeys == [];
        message = "programs.herdr: key(s) set both as typed option and in extraConfig: ${lib.concatStringsSep ", " conflictingKeys}";
      }
      {
        assertion = !(cfg.keys ? command);
        message = "programs.herdr: declare command shortcuts via programs.herdr.commands, not keys.command.";
      }
    ];

    home.packages = [wrappedPackage];

    home.activation.herdrPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${lib.getExe syncPlugins} ${pluginsJson}
    '';

    xdg.configFile =
      lib.mapAttrs' (
        name: file:
          lib.nameValuePair "herdr/agent-detection/${name}" {source = file;}
      )
      cfg.agentDetection;
  };
}
