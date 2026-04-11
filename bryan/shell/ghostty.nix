{lib, pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = lib.mkForce null; # installed via Homebrew cask
    settings = {
      # Stylix auto-sets: font-family, font-size, background-opacity, full color theme

      # Scrollback — u32::MAX, effectively unlimited (matches iTerm2)
      scrollback-limit = 4294967295;

      # Cursor — non-blinking block (matches iTerm2)
      cursor-style = "block";
      cursor-style-blink = false;

      # macOS window chrome — tabs in titlebar, no extra decoration
      macos-titlebar-style = "tabs";
      window-padding-x = 4;
      window-padding-y = 4;
      confirm-close-surface = false;

      # Launch nushell instead of the macOS default login shell (zsh)
      command = lib.getExe pkgs.nushell;

      # Nushell has built-in shell integration (OSC 133); Ghostty's
      # auto-inject only supports bash/zsh/fish/elvish
      shell-integration = "none";
    };
  };
}
