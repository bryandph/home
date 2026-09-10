{config, ...}: {
  flake.modules.homeManager.de-common = {pkgs, ...}: {
    imports = with config.flake.modules.homeManager; [kitty chromium];
    home.packages = [pkgs.kdePackages.dolphin pkgs.pavucontrol];
  };
}
