{config, ...}: {
  flake.modules.homeManager.de-i3 = {
    imports = with config.flake.modules.homeManager; [desktop-i3 de-common i3-idle];
  };
}
