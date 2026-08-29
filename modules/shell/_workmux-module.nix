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
#
# Job watching (nixspace#86 D8 outcome, verified 2026-07-15): to run and
# watch a long task in a worktree, use the shipped primitives — `workmux
# run <wt> -- <cmd>` opens a split pane beside the agent, streams output
# to the caller, and propagates completion (`-b` to background,
# `--timeout` to bound); `workmux send/capture/wait` drive and observe
# the agent itself; interactive tools ride `programs.herdr.commands`
# pane shortcuts. No extra wrapper: window status carries *agent*
# semantics — a job-completion flag in the same window would fight the
# agent's own status hooks. Note: agents appear in `workmux
# status`/`wait` once their first status hook fires (registration rides
# `set-window-status`); on a fresh host workmux's first `add` asks to
# install status hooks — answer no, they are delivered by
# `agentic.statusHooks`.
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

  agentEnvSourceType = lib.types.submodule {
    options.from_env = lib.mkOption {
      type = lib.types.str;
      description = "Environment variable to read from the workmux launch environment.";
    };
  };

  agentProfileType = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Built-in workmux agent behavior used for prompt injection and lifecycle handling.";
      };
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Executable or command string to launch (defaults to the agent type or profile name).";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Literal arguments appended after the command and before an injected prompt.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.str agentEnvSourceType);
        default = {};
        description = "Environment values as literals or launch-time `from_env` references.";
      };
    };
  };

  # Drop null/false keys so the generated YAML stays as lean as the
  # hand-written one (workmux treats absent and default identically).
  cleanAttrs = lib.filterAttrs (_: v: v != null && v != false);
  cleanAgentProfile = lib.filterAttrs (_: v: v != null && v != [] && v != {});
  cleanAgentEntry = _: entry:
    if builtins.isString entry
    then entry
    else cleanAgentProfile entry;

  typedSettings = lib.filterAttrs (_: v: v != null) {
    inherit (cfg) agent mode nerdfont;
    agents =
      if cfg.agents == {}
      then null
      else lib.mapAttrs cleanAgentEntry cfg.agents;
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

    agents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str agentProfileType);
      default = {};
      description = "Global named agent profiles (string aliases or structured launch profiles).";
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
      inherit (yamlFormat) type;
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
