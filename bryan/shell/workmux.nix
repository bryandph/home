{
  workmux ? null,
  lib,
  ...
}:
lib.mkIf (workmux != null) {
  home.packages = [workmux];

  xdg.configFile."workmux/config.yaml".text = ''
    agent: claude
    merge_strategy: rebase
    panes:
      - command: <agent>
        focus: true
      - split: horizontal
  '';
}
