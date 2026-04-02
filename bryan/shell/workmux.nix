{
  lib,
  config,
  ...
}: let
  cfg = config.programs.workmux;
in {
  options.programs.workmux = {
    enable = lib.mkEnableOption "workmux";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The workmux package";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    xdg.configFile."workmux/config.yaml".text = ''
      agent: claude
      merge_strategy: rebase
      panes:
        - command: <agent>
          focus: true
        - split: horizontal
      nerdfont: true
    '';
  };
}
