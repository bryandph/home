{globals, ...}: {
  imports = [
    ./shell
  ];

  home = {
    username = globals.user;
    homeDirectory = "/Users/${globals.user}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
