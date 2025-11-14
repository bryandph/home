{globals, ...}: {
  imports = [
    ./shell
  ];

  home = {
    username = globals.user;
    homeDirectory = "/Users/${globals.user}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
