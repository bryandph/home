# Preset: the full interactive shell bundle — every former bryan/shell/*
# feature plus the shared CLI package set. Hosts/profiles opt in by importing
# `flake.modules.homeManager.shell`; there is no enable gate.
# Note: ghostty is intentionally NOT part of this bundle (darwin-only today,
# composed directly by the bryan-darwin profile).
{config, ...}: {
  flake.modules.homeManager.shell = {
    imports = with config.flake.modules.homeManager; [
      git
      gpg
      helix
      herdr
      k9s
      neovim
      nix-tools
      nushell
      sesh
      shell-packages
      starship
      tmux
      workmux
    ];
  };
}
