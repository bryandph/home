# Coarse profile export: Linux home + desktop environment
# (Tier-1 `homeModules.bryan-with-de`).
{config, ...}: {
  flake.modules.homeManager.bryan-with-de = {
    imports = with config.flake.modules.homeManager; [
      bryan
      de
    ];
  };
}
