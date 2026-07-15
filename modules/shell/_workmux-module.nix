# Vendored `programs.workmux` HM module — typed options over the global
# `~/.config/workmux/config.yaml` (bryan/nixspace#86, capability
# agentic-user-tools). Option defaults reproduce the previously
# hand-maintained config, so enabling the module is behavior-preserving.
#
# One writer per file: config.yaml is generated here — never run
# `workmux setup` on managed hosts (it edits harness configs imperatively;
# the same integrations are delivered by `agentic.statusHooks`). The
# package stays consumer-supplied (flake input / overlay).
#
# Option names are camelCase HM-style; serialization maps them to
# workmux's snake_case keys. Keys workmux grows that aren't typed yet go
# in `extraConfig` (same YAML namespace; typed/freeform key conflicts
# fail evaluation).
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.workmux;
  yamlFormat = pkgs.formats.yaml {};

  paneType = lib.types.submodule {
    options = {
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command run when the pane is created (`<agent>` expands to the configured agent). Null starts the default shell.";
      };
      focus = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Focus this pane after creation.";
      };
      split = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["horizontal" "vertical"]);
        default = null;
        description = "Split direction from the previous pane.";
      };
      size = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.u16;
        default = null;
        description = "Pane size in lines/cells (mutually exclusive with percentage).";
      };
      percentage = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 100);
        default = null;
        description = "Pane size as a percentage (mutually exclusive with size).";
      };
      zoom = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Zoom (fullscreen) this pane after creation; implies focus.";
      };
    };
  };

  # Drop null/false keys so the generated YAML stays as lean as the
  # hand-written one (workmux treats absent and default identically).
  cleanAttrs = lib.filterAttrs (_: v: v != null && v != false);

  typedSettings = lib.filterAttrs (_: v: v != null) {
    inherit (cfg) agent mode nerdfont;
    merge_strategy = cfg.mergeStrategy;
    panes =
      if cfg.panes == null
      then null
      else map cleanAttrs cfg.panes;
    status_format = cfg.statusFormat;
    status_icons =
      if cleanAttrs cfg.statusIcons == {}
      then null
      else cleanAttrs cfg.statusIcons;
  };

  conflictingKeys = lib.intersectLists (lib.attrNames typedSettings) (lib.attrNames cfg.extraConfig);
in {
  options.programs.workmux = {
    enable = lib.mkEnableOption "workmux";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The workmux package";
    };

    agent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "claude";
      description = "Agent command launched in `<agent>` panes.";
    };

    mergeStrategy = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["merge" "rebase" "squash"]);
      default = "rebase";
      description = "Default strategy for `workmux merge`.";
    };

    mode = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["window" "session"]);
      default = "session";
      description = "tmux unit per worktree: a window or a whole session.";
    };

    panes = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf paneType);
      default = [
        {
          command = "<agent>";
          focus = true;
        }
        {
          command = "lazygit";
          split = "horizontal";
          size = 25;
        }
        {
          split = "vertical";
          size = 50;
        }
      ];
      description = "Pane layout for new worktree windows (default: agent + lazygit split + shell split).";
    };

    nerdfont = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = true;
      description = "Use nerdfont icons in the dashboard.";
    };

    statusFormat = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Auto-apply agent status to the tmux window format (upstream default: true).";
    };

    statusIcons = {
      working = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Icon for the working state (upstream default: 🤖).";
      };
      waiting = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Icon for the waiting state (upstream default: 💬).";
      };
      done = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Icon for the done state (upstream default: ✅).";
      };
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = {};
      example = lib.literalExpression ''{ worktree_dir = "../wt"; post_create = ["direnv allow"]; }'';
      description = "Freeform workmux config merged with the typed options (snake_case keys as workmux expects). Setting a key both ways fails evaluation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = conflictingKeys == [];
        message = "programs.workmux: key(s) set both as typed option and in extraConfig: ${lib.concatStringsSep ", " conflictingKeys}";
      }
    ];

    home.packages = [cfg.package];

    xdg.configFile."workmux/config.yaml".source =
      yamlFormat.generate "workmux-config.yaml" (typedSettings // cfg.extraConfig);
  };
}
