# `agentic.statusSounds` — notification sounds for agent status events
# (bryan/nixspace#86, agent-status-hooks capability, design D4).
#
# A separate, composable concern: off by default, hosts opt in individually
# (interactive workstations want it; shared/headless hosts stay silent).
# Delivery for Claude Code is a tiny locally-generated plugin — a second
# plugin next to the upstream workmux-status one, so the upstream artifact
# stays pure and ~/.claude/settings.json stays unmanaged (the writability
# invariant from _agent-status-module.nix). Harnesses without a
# command-capable event surface simply have no sound delivery.
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
      matcher = null;
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

  # Backgrounded so a slow player never delays the hook pipeline.
  playCommand = sound: "${cfg.player} ${lib.escapeShellArg sound} &";

  pluginManifest = {
    name = "status-sounds";
    version = "1.0.0";
    description = "Notification sounds for agent status events (home-manager generated)";
    hooks =
      lib.mapAttrs' (
        eventName: sound: let
          wiring = claudeHookFor.${eventName};
        in
          lib.nameValuePair wiring.event [
            (
              {
                hooks = [
                  {
                    type = "command";
                    command = playCommand sound;
                  }
                ];
              }
              // lib.optionalAttrs (wiring.matcher != null) {inherit (wiring) matcher;}
            )
          ]
      )
      cfg.events;
  };

  soundsPlugin = pkgs.runCommand "claude-status-sounds-plugin" {} ''
    install -Dm644 ${jsonFormat.generate "status-sounds-plugin.json" pluginManifest} \
      $out/.claude-plugin/plugin.json
  '';
in {
  options.agentic.statusSounds = {
    enable = lib.mkEnableOption "notification sounds for agent status events";

    player = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.isDarwin
        then "afplay"
        else "pw-play";
      defaultText = lib.literalExpression ''if pkgs.stdenv.isDarwin then "afplay" else "pw-play"'';
      description = ''
        Sound player invoked as `<player> <file> &`. Defaults to the
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
        assertion = config.programs.claude-code.enable;
        message = "agentic.statusSounds requires programs.claude-code.enable (sounds are delivered as a Claude Code plugin).";
      }
    ];

    programs.claude-code.plugins = [soundsPlugin];
  };
}
