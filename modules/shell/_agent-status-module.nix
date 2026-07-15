# `agentic.statusHooks` — cross-harness agent status reporting into workmux
# (bryan/nixspace#86, capability agent-status-hooks).
#
# One canonical status model (working | waiting | done | clear, reported via
# `workmux set-window-status`), delivered per harness from the pinned workmux
# source's own integration resources — the same artifacts `workmux setup`
# would install, minus the imperative installer. We carry no forked hook or
# plugin logic; the only local delta is Codex's PermissionRequest → waiting
# mapping, which upstream's baseline lacks. Nested agents suppress reporting
# via WORKMUX_DISABLE_SET_WINDOW_STATUS=1 (upstream workmux behavior).
#
# One writer per file: Claude Code delivery deliberately rides the plugin
# mechanism (`--plugin-dir` wrapper args) and NEVER
# `programs.claude-code.settings`/`marketplaces` — home-manager renders those
# into a read-only store-symlinked ~/.claude/settings.json, breaking Claude
# Code's own write-back (asserted below). Likewise ~/.codex/config.toml stays
# unmanaged (codex writes project trust levels into it); only hooks.json is
# ours. Never run `workmux setup` or `herdr integration install` on hosts
# under this module.
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.agentic.statusHooks;
  jsonFormat = pkgs.formats.json {};

  # Canonical status model (data, not hook bodies) — positioned to lift into
  # the agentic core's schema once it exists (#85 follow-up). The
  # Claude/OpenCode/Pi event→state mappings live inside the upstream
  # artifacts delivered verbatim below; the Codex delta is the one mapping we
  # author, expressed as data and merged over upstream's baseline.
  statusModel = {
    states = ["working" "waiting" "done" "clear"];
    setStatus = state: "workmux set-window-status ${state}";
    codexDelta = {
      PermissionRequest = "waiting";
    };
  };

  # Per-harness resource paths inside the pinned workmux source (layout as of
  # v0.1.221 — dot-dirs at the repo root, not everything under resources/).
  # The existence assertions below catch upstream path moves on pin bumps.
  resources = {
    # Claude plugin root is the workmux source itself: marketplace.json lists
    # plugin source "./", hooks are bundled in .claude-plugin/plugin.json.
    claude = "${cfg.workmuxSrc}/.claude-plugin/plugin.json";
    opencode = "${cfg.workmuxSrc}/resources/opencode/plugins/workmux-status.ts";
    pi = "${cfg.workmuxSrc}/.pi/extensions/workmux-status.ts";
    codex = "${cfg.workmuxSrc}/.codex/hooks/workmux-status.json";
  };

  # Codex hooks: upstream baseline read from the pinned source (changes flow
  # in on pin bumps) + our waiting delta from the status model.
  codexBaseline = builtins.fromJSON (builtins.readFile resources.codex);
  codexHooks =
    codexBaseline
    // {
      hooks =
        codexBaseline.hooks
        // lib.mapAttrs (_event: state: [
          {
            hooks = [
              {
                type = "command";
                command = statusModel.setStatus state;
              }
            ];
          }
        ])
        statusModel.codexDelta;
    };

  harnessOption = name: default: extraDoc:
    lib.mkOption {
      type = lib.types.bool;
      inherit default;
      description = "Deliver the workmux status integration for ${name}. ${extraDoc}";
    };

  resourceAssertion = harness: {
    assertion = cfg.harnesses.${harness} -> builtins.pathExists resources.${harness};
    message = ''
      agentic.statusHooks: workmux resource for ${harness} not found at
      ${resources.${harness}} — the pinned workmux source has likely moved its
      integration resources (this happened before, v0.1.182). Update the
      resource paths in _agent-status-module.nix for the new layout.
    '';
  };
in {
  options.agentic.statusHooks = {
    enable = lib.mkEnableOption "cross-harness agent status reporting to workmux";

    workmuxSrc = lib.mkOption {
      type = lib.types.path;
      default = config.programs.workmux.package.src;
      defaultText = lib.literalExpression "config.programs.workmux.package.src";
      description = ''
        Pinned workmux source tree providing the per-harness integration
        resources. Defaults to the source of the configured workmux binary so
        resources and CLI stay in lockstep across pin bumps.
      '';
    };

    harnesses = {
      claude = harnessOption "Claude Code" true "Delivered as a plugin (`--plugin-dir`); settings.json is never managed.";
      opencode = harnessOption "OpenCode" true "Upstream plugin file placed in the (singular) plugin/ config dir.";
      codex = harnessOption "Codex" false ''
        Off by default: codex is not currently installed. Enabling manages
        ~/.codex/hooks.json (upstream baseline + PermissionRequest→waiting);
        the `[features] codex_hooks = true` flag must stay in the
        codex-writable, unmanaged ~/.codex/config.toml (codex records project
        trust levels there — one writer per file).
      '';
      pi = harnessOption "Pi" false "Off by default: pi is not currently set up. Enabling places workmux's extension in ~/.pi/agent/extensions/.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      map resourceAssertion (lib.attrNames resources)
      ++ [
        {
          assertion = cfg.harnesses.claude -> config.programs.claude-code.enable;
          message = "agentic.statusHooks.harnesses.claude requires programs.claude-code.enable (the plugin rides its wrapper).";
        }
        {
          assertion =
            cfg.harnesses.claude
            -> (config.programs.claude-code.settings == {} && config.programs.claude-code.marketplaces == {});
          message = ''
            agentic.statusHooks: programs.claude-code.settings/marketplaces
            must stay empty — home-manager renders either into a read-only
            store-symlinked ~/.claude/settings.json, breaking Claude Code's
            own write-back (the writability invariant of the
            agent-status-hooks capability).
          '';
        }
      ];

    programs.claude-code.plugins = lib.mkIf cfg.harnesses.claude [cfg.workmuxSrc];

    xdg.configFile."opencode/plugin/workmux-status.ts" = lib.mkIf cfg.harnesses.opencode {
      source = resources.opencode;
    };

    home.file = {
      ".pi/agent/extensions/workmux-status.ts" = lib.mkIf cfg.harnesses.pi {
        source = resources.pi;
      };
      ".codex/hooks.json" = lib.mkIf cfg.harnesses.codex {
        source = jsonFormat.generate "codex-workmux-hooks.json" codexHooks;
      };
    };
  };
}
