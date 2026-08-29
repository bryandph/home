{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    mkHome = extraModule:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./_workmux-module.nix
          {
            home = {
              username = "workmux-fixture";
              homeDirectory = "/home/workmux-fixture";
              stateVersion = "26.05";
            };
            programs.workmux = {
              enable = true;
              package = inputs.workmux.packages.${pkgs.stdenv.hostPlatform.system}.default;
            };
          }
          extraModule
        ];
      };

    renderedHome = mkHome {
      programs.workmux.agents = {
        string-alias = "claude --model fixture";
        structured = {
          type = "codex";
          command = "codex";
          args = [
            "-m"
            "fixture-model"
          ];
          env = {
            LITERAL = "fixture-value";
            FORWARDED.from_env = "FIXTURE_SOURCE";
          };
        };
        type-only.type = "claude";
      };
    };
    renderedConfig = renderedHome.config.xdg.configFile."workmux/config.yaml".source;

    conflictHome = mkHome {
      programs.workmux = {
        agents.typed = "claude";
        extraConfig.agents.freeform = "codex";
      };
    };
    conflictRejected = !(builtins.tryEval conflictHome.activationPackage.drvPath).success;
    python = pkgs.python3.withPackages (pythonPackages: [pythonPackages.pyyaml]);
  in {
    checks.workmux-agent-profiles = pkgs.runCommand "workmux-agent-profiles-check" {
      nativeBuildInputs = [python];
    } ''
      test ${if conflictRejected then "1" else "0"} = 1

      python - ${renderedConfig} <<'PY'
      import pathlib
      import sys
      import yaml

      config = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
      agents = config["agents"]
      assert agents["string-alias"] == "claude --model fixture"
      assert agents["structured"] == {
          "type": "codex",
          "command": "codex",
          "args": ["-m", "fixture-model"],
          "env": {
              "LITERAL": "fixture-value",
              "FORWARDED": {"from_env": "FIXTURE_SOURCE"},
          },
      }
      assert agents["type-only"] == {"type": "claude"}
      PY

      touch $out
    '';
  };
}
