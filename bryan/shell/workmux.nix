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
      mode: session
      panes:
        - command: <agent>
          focus: true
        - command: lazygit
          split: horizontal
          size: 25
        - split: vertical
          size: 50
      nerdfont: true
    '';
  };
}
