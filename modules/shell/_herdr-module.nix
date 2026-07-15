{
  lib,
  config,
  ...
}: let
  cfg = config.programs.herdr;
in {
  options.programs.herdr = {
    enable = lib.mkEnableOption "herdr";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The herdr package";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # Keybindings mirror shell/tmux.nix: ctrl+a prefix, vim pane focus with
    # no-prefix alt+vim/alt+arrow fallbacks, shift+arrows for tab switching,
    # v/- splits, and lazygit/btop on prefix+g/b. Herdr defaults that already
    # match tmux (new_tab c, split v/-, focus hjkl, zoom z, copy-mode [,
    # switch_tab 1..9) are left unset. To make room for the popups:
    # goto moves g → f and toggle_sidebar moves b → e.
    xdg.configFile."herdr/config.toml".text = ''
      [keys]
      prefix = "ctrl+a"

      # tmux detaches on prefix+d; keep herdr's prefix+q too
      detach = ["prefix+d", "prefix+q"]

      # no-prefix pane focus (tmux: bind -n M-h/j/k/l + M-arrows)
      focus_pane_left = ["prefix+h", "alt+h", "alt+left"]
      focus_pane_down = ["prefix+j", "alt+j", "alt+down"]
      focus_pane_up = ["prefix+k", "alt+k", "alt+up"]
      focus_pane_right = ["prefix+l", "alt+l", "alt+right"]

      # no-prefix tab switching (tmux: bind -n S-Left/S-Right)
      previous_tab = ["prefix+p", "shift+left"]
      next_tab = ["prefix+n", "shift+right"]

      # displaced by the lazygit/btop bindings below
      goto = "prefix+f"
      toggle_sidebar = "prefix+e"

      [[keys.command]]
      key = "prefix+g"
      type = "pane"
      command = "lazygit"
      description = "lazygit"

      [[keys.command]]
      key = "prefix+b"
      type = "pane"
      command = "btop"
      description = "btop"

      [terminal]
      default_shell = "nu"
      # tmux parity: splits/tabs open in the pane's cwd (#{pane_current_path})
      new_cwd = "follow"
    '';
  };
}
