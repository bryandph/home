# Declarative delivery of Herdr's pinned integrations. Harness settings remain
# mutable and launcher-owned; no imperative integration installer runs.
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.agentic.statusHooks;
  jsonFormat = pkgs.formats.json {};
  resource = name: "${cfg.herdrSrc}/src/integration/assets/${name}";
  resources = {
    claude = resource "claude/herdr-agent-state.sh";
    codex = resource "codex/herdr-agent-state.sh";
    opencode = resource "opencode/herdr-agent-state.js";
    pi = resource "pi/herdr-agent-state.ts";
  };
  script = harness:
    pkgs.writeShellScript "herdr-${harness}-status" ''
      export PATH=${lib.makeBinPath [pkgs.python3 pkgs.coreutils]}:$PATH
      exec ${pkgs.runtimeShell} ${resources.${harness}} "$@"
    '';
  hook = command: {
    hooks = [
      {
        type = "command";
        inherit command;
        timeout = 10;
      }
    ];
  };
  # Native Codex resources report lifecycle/working/idle. PermissionRequest is
  # an extra blocked event, delivered beside (not patched into) upstream code.
  waiting = pkgs.writeShellScript "herdr-codex-waiting" ''
    exec ${pkgs.python3}/bin/python3 ${./status-report.py}
  '';
  codexHooks = {
    SessionStart = [(hook "${script "codex"} session")];
    UserPromptSubmit = [(hook "${script "codex"} working")];
    Stop = [(hook "${script "codex"} idle")];
    Interrupt = [(hook "${script "codex"} idle")];
    PermissionRequest = [(hook "${waiting}")];
  };
  claudePlugin = pkgs.runCommand "claude-herdr-status-plugin" {} ''
    install -Dm644 ${jsonFormat.generate "herdr-status-plugin.json" {
      name = "herdr-status";
      version = "1.0.0";
      hooks.SessionStart = [(hook "${script "claude"} session")];
    }} $out/.claude-plugin/plugin.json
  '';
  piPromptBridge = pkgs.writeText "pi-status-prompts.ts" (builtins.readFile ./pi-status-prompts.ts);
  harnessOption = name: default:
    lib.mkOption {
      type = lib.types.bool;
      inherit default;
      description = "Deliver the pinned Herdr integration for ${name}.";
    };
in {
  options.agentic.statusHooks = {
    enable = lib.mkEnableOption "cross-harness agent status reporting to Herdr";
    herdrSrc = lib.mkOption {
      type = lib.types.path;
      default = config.programs.herdr.package.src;
      defaultText = lib.literalExpression "config.programs.herdr.package.src";
      description = "Pinned Herdr source providing native integration resources.";
    };
    harnesses = {
      claude = harnessOption "Claude Code" true;
      opencode = harnessOption "OpenCode" true;
      codex = harnessOption "Codex" false;
      pi = harnessOption "Pi" false;
    };
    codexHooks = lib.mkOption {
      inherit (jsonFormat) type;
      default =
        if cfg.enable && cfg.harnesses.codex
        then codexHooks
        else {};
      readOnly = true;
      internal = true;
      description = "Codex hooks for the mutable-file launcher reconciler.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions =
      (map (harness: {
        assertion = cfg.harnesses.${harness} -> builtins.pathExists resources.${harness};
        message = "agentic.statusHooks: missing pinned Herdr resource ${resources.${harness}}";
      }) (lib.attrNames resources))
      ++ [
        {
          assertion = config.programs.herdr.enable;
          message = "agentic.statusHooks requires programs.herdr.enable.";
        }
        {
          assertion = cfg.harnesses.claude -> (config.programs.claude-code.enable && config.programs.claude-code.settings == {} && config.programs.claude-code.marketplaces == {});
          message = "agentic.statusHooks: Claude must be enabled with empty settings/marketplaces so settings remain writable.";
        }
      ];
    programs.claude-code.plugins = lib.mkIf cfg.harnesses.claude [claudePlugin];
    xdg.configFile."opencode/plugin/herdr-agent-state.js" = lib.mkIf cfg.harnesses.opencode {source = resources.opencode;};
    home.file = {
      ".pi/agent/extensions/status-prompts.ts" = lib.mkIf cfg.harnesses.pi {source = piPromptBridge;};
      ".pi/agent/extensions/herdr-agent-state.ts" = lib.mkIf cfg.harnesses.pi {source = resources.pi;};
      ".codex/herdr-agent-state.sh" = lib.mkIf cfg.harnesses.codex {source = script "codex";};
    };
  };
}
