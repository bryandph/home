# `agentic.statusSounds` — notification sounds for agent status events
# (bryan/nixspace#86, agent-status-hooks capability, design D4).
#
# A separate, composable concern: off by default, hosts opt in individually
# (interactive workstations want it; shared/headless hosts stay silent).
# Delivery for Claude Code is a tiny locally-generated plugin — a second
# plugin next to the upstream workmux-status one, so the upstream artifact
# stays pure and ~/.claude/settings.json stays unmanaged (the writability
# invariant from _agent-status-module.nix). Codex exposes hook data for the
# parent launcher; Pi uses a separate extension. No harness settings are owned.
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.agentic.statusSounds;
  jsonFormat = pkgs.formats.json {};

  # Abstract sound events → Claude Code hook wiring. `waiting` uses the same
  # matcher as workmux's status plugin so both fire on the same prompts.
  claudeHookFor = {
    session-start = {
      event = "SessionStart";
      matcher = "startup|resume|clear";
    };
    working = {
      event = "UserPromptSubmit";
      matcher = null;
    };
    waiting = {
      event = "Notification";
      matcher = "permission_prompt|elicitation_dialog";
    };
    done = {
      event = "Stop";
      matcher = null;
    };
  };

  # Event mappings are data; all harnesses share the files and player.
  codexHookFor = {
    session-start = {
      event = "SessionStart";
      matcher = "startup|resume|clear";
    };
    working = {
      event = "UserPromptSubmit";
      matcher = null;
    };
    waiting = {
      event = "PermissionRequest";
      matcher = null;
    };
    done = {
      event = "Stop";
      matcher = null;
    };
  };
  soundConfig = jsonFormat.generate "agent-status-sounds.json" {
    inherit (cfg) player events;
  };
  runner = pkgs.writeShellScript "agent-status-sound" ''
    exec ${pkgs.python3}/bin/python3 ${./status-sound.py} ${soundConfig} "$@"
  '';
  hooksFor = harness: mapping:
    lib.mapAttrs' (event: _sound: let
      wiring = mapping.${event};
    in
      lib.nameValuePair wiring.event [
        ({
            hooks = [
              {
                type = "command";
                command = "${runner} ${harness} ${lib.escapeShellArg event}";
              }
            ];
          }
          // lib.optionalAttrs (wiring.matcher != null) {inherit (wiring) matcher;})
      ])
    (lib.filterAttrs (event: _: mapping ? ${event}) cfg.events);

  pluginManifest = {
    name = "status-sounds";
    version = "2.0.0";
    description = "Notification sounds for agent status events (home-manager generated)";
    hooks = hooksFor "claude" claudeHookFor;
  };
  piExtension =
    pkgs.writeText "status-sounds.ts" (lib.replaceStrings
      ["@runner@"] ["${runner}"] (builtins.readFile ./status-sounds-pi.ts));
  soundsPlugin = pkgs.runCommand "claude-status-sounds-plugin" {} ''
    install -Dm644 ${jsonFormat.generate "status-sounds-plugin.json" pluginManifest} \
      $out/.claude-plugin/plugin.json
  '';
in {
  options.agentic.statusSounds = {
    enable = lib.mkEnableOption "notification sounds for agent status events";

    harnesses = {
      claude = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deliver the Claude sound plugin.";
      };
      codex = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Expose the Codex sound hook projection.";
      };
      pi = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Deliver the Pi sound extension.";
      };
    };

    codexHooks = lib.mkOption {
      inherit (jsonFormat) type;
      default =
        if cfg.enable && cfg.harnesses.codex
        then hooksFor "codex" codexHookFor
        else {};
      readOnly = true;
      internal = true;
      description = "Event-to-hook-groups projection. The launcher concatenates groups per event with statusHooks.codexHooks and reconciles writable files. Interactive root Claude/Codex launchers must set AGENTIC_SOUNDS_INTERACTIVE=1; nested/headless launches must unset it. AGENTIC_SOUNDS_DISABLE=1 suppresses every harness.";
    };

    player = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.isDarwin
        then "afplay"
        else "pw-play";
      defaultText = lib.literalExpression ''if pkgs.stdenv.isDarwin then "afplay" else "pw-play"'';
      description = ''
        Sound player invoked asynchronously with the file as one argument (player arguments use shell-style quoting, without shell expansion). Defaults to the
        platform's native player (afplay on darwin, pipewire's pw-play on
        linux); override with e.g. "paplay" on PulseAudio hosts.
      '';
    };

    events = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression ''
        {
          session-start = "/System/Library/Sounds/Glass.aiff";
          working = "/System/Library/Sounds/Pop.aiff";
          waiting = "/System/Library/Sounds/Submarine.aiff";
          done = "/System/Library/Sounds/Hero.aiff";
        }
      '';
      description = ''
        Status event → sound file. Valid events:
        ${lib.concatStringsSep ", " (lib.attrNames claudeHookFor)}.
        Sound files are host paths (strings), not store paths — system sounds
        stay where they live.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.events != {}) {
    assertions = [
      {
        assertion = cfg.events == {} || lib.all (e: claudeHookFor ? ${e}) (lib.attrNames cfg.events);
        message = ''
          agentic.statusSounds.events: unknown event name. Valid events:
          ${lib.concatStringsSep ", " (lib.attrNames claudeHookFor)}.
        '';
      }
      {
        assertion = cfg.harnesses.claude -> (config.programs.claude-code.enable && config.programs.claude-code.settings == {} && config.programs.claude-code.marketplaces == {});
        message = "agentic.statusSounds.harnesses.claude requires Claude Code enabled with empty settings/marketplaces so settings remain writable.";
      }
    ];

    programs.claude-code.plugins = lib.mkIf cfg.harnesses.claude [soundsPlugin];
    home.file.".pi/agent/extensions/status-sounds.ts" = lib.mkIf cfg.harnesses.pi {
      source = piExtension;
    };
  };
}
