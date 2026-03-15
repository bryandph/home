{globals, ...}: {
  imports = [
    ./shell
    ./shell/ghostty.nix
  ];

  home = {
    username = globals.user;
    homeDirectory = "/Users/${globals.user}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
