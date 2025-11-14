{lib, ...}: {
  imports = [
    ./shell
  ];

  home = {
    stateVersion = "25.05";
  };

  services = {
    ssh-agent = {
      enable = lib.mkDefault true;
    };
  };
}
