{config, ...}: {
  flake.modules.homeManager.bryan-with-i3 = {
    imports = with config.flake.modules.homeManager; [bryan de-i3];
  };
}
