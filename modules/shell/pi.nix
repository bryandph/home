# Pi keybindings shared by every client terminal. Pi is mostly driven over
# SSH inside herdr from both macOS and Windows clients, and its defaults
# differ per platform (alt+up vs alt+q for dequeue, alt+enter vs ctrl+q for
# follow-up). Bind both chords everywhere so muscle memory carries across
# clients. Keep herdr's no-prefix chords off these keys (shell/_herdr-module.nix).
# Pi only reads keybindings.json, so a store symlink is safe; settings.json
# stays tool-owned.
{
  flake.modules.homeManager.pi = {pkgs, ...}: {
    home.file.".pi/agent/keybindings.json".source = (pkgs.formats.json {}).generate "pi-keybindings.json" {
      # Option+Up on macOS, Alt+Up on Windows: edit the last queued steer.
      "app.message.dequeue" = ["alt+up" "alt+q"];
      # Windows Terminal claims alt+enter for fullscreen.
      "app.message.followUp" = ["alt+enter" "ctrl+q"];
    };
  };
}
