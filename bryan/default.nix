{lib, ...}: {
  imports = [
    ./shell
  ];

  home = {
    stateVersion = "26.05";
  };

  services = {
    ssh-agent = {
      enable = lib.mkDefault true;
    };
  };
}
