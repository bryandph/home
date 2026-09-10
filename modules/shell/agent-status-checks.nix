{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    mkHome = extra:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./_workmux-module.nix
          ./_herdr-module.nix
          ./_agent-status-module.nix
          ./_status-sounds-module.nix
          {
            home = {
              username = "sound-fixture";
              homeDirectory = "/home/sound-fixture";
              stateVersion = "26.05";
            };
            programs.claude-code.enable = true;
            programs.workmux.package = pkgs.emptyDirectory // {src = ./_tests/workmux;};
            programs.herdr = {
              enable = true;
              package = pkgs.emptyDirectory // {src = inputs.herdr.outPath;};
            };
            agentic.statusHooks = {
              enable = true;
              harnesses = {
                claude = true;
                codex = true;
                pi = true;
                opencode = false;
              };
            };
            agentic.statusSounds = {
              enable = true;
              harnesses = {
                claude = true;
                codex = true;
                pi = true;
              };
              player = "${pkgs.python3}/bin/python3 ${./_tests/record-sound.py}";
              events = lib.genAttrs ["session-start" "working" "waiting" "done"] (_: "/fixture/sound 'quoted' $(literal).aiff");
            };
          }
          extra
        ];
      };
    both = (mkHome {}).config;
    soundsOnly = (mkHome {agentic.statusHooks.enable = lib.mkForce false;}).config;
    statusOnly = (mkHome {agentic.statusSounds.enable = lib.mkForce false;}).config;
    disabled = (mkHome {agentic.statusSounds.harnesses.codex = lib.mkForce false;}).config;
    status = both.agentic.statusHooks.codexHooks;
    sounds = both.agentic.statusSounds.codexHooks;
    composed = lib.zipAttrsWith (_: groups: lib.concatLists groups) [status sounds];
    bundle = pkgs.writeText "sound-fixtures.json" (builtins.toJSON {
      inherit status composed;
      codex = sounds;
      plugin = builtins.head soundsOnly.programs.claude-code.plugins;
      sound = both.agentic.statusSounds.events.done;
      soundsOnly = soundsOnly.agentic.statusSounds.codexHooks;
      statusOnly = statusOnly.agentic.statusHooks.codexHooks;
      disabled = disabled.agentic.statusSounds.codexHooks;
    });
    piOnly =
      (mkHome {
        programs.claude-code.enable = lib.mkForce false;
        agentic.statusHooks.enable = lib.mkForce false;
        agentic.statusSounds.harnesses.claude = lib.mkForce false;
      }).config;
    invalid = mkHome {agentic.statusSounds.events.bogus = "bad";};
    files = both.home.file;
    mutableFiles = [".claude/settings.json" ".codex/hooks.json" ".codex/config.toml" ".pi/agent/settings.json" ".pi/agent/auth.json" ".pi/agent/trust.json"];
    assertionsPass = lib.all (a: a.assertion) both.assertions;
  in {
    checks.agent-status-sounds = assert assertionsPass;
    assert lib.all (a: a.assertion) piOnly.assertions;
    assert !(builtins.tryEval invalid.activationPackage.drvPath).success;
    assert lib.all (path: !(builtins.hasAttr path files)) mutableFiles;
    assert toString files.".pi/agent/extensions/herdr-agent-state.ts".source == "${inputs.herdr.outPath}/src/integration/assets/pi/herdr-agent-state.ts";
    assert toString files.".pi/agent/extensions/workmux-status.ts".source == "${both.agentic.statusHooks.workmuxSrc}/resources/pi/extensions/workmux-status.ts";
    assert !(soundsOnly.home.file ? ".pi/agent/extensions/workmux-status.ts");
    assert !(statusOnly.home.file ? ".pi/agent/extensions/status-sounds.ts");
      pkgs.runCommand "agent-status-sounds-check" {nativeBuildInputs = [pkgs.python3 pkgs.nodejs];} ''
        python3 ${./_tests/sound-hooks.py} ${bundle}
        node --experimental-strip-types ${./_tests/pi-sounds.mjs} ${files.".pi/agent/extensions/status-sounds.ts".source}
        node --experimental-strip-types ${./_tests/pi-prompts.mjs} ${files.".pi/agent/extensions/status-prompts.ts".source}
        touch "$out"
      '';
  };
}
