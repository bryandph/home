# Exercise the actual Home Manager file, not a parallel test manifest. Each
# explain invocation uses an isolated HOME; no live server or config is touched.
{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
    home = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./_herdr-module.nix
        {
          home = {
            username = "detection-fixture";
            homeDirectory = "/home/detection-fixture";
            stateVersion = "26.05";
          };
          programs.herdr = {
            enable = true;
            package = herdr;
          };
        }
      ];
    };
    file = home.config.xdg.configFile."herdr/agent-detection/pi.toml";
  in {
    checks.herdr-agent-detection = assert file.enable;
      pkgs.runCommand "herdr-agent-detection-check" {nativeBuildInputs = [herdr pkgs.python3];} ''
        mkdir -p "$out"
        python3 ${./_tests/herdr-agent-detection.py} ${file.source} ${./_tests/herdr-detection} "$out"
      '';
  };
}
