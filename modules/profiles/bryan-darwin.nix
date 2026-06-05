# Coarse profile export: macOS home (Tier-1 `homeModules.bryan-darwin`).
# Unlike the Linux profile this one DOES set home.username/homeDirectory
# (from the HM-level meta options) — parity with the pre-dendritic
# bryan/darwin.nix, whose values came from the `globals` specialArg.
{config, ...}: {
  flake.modules.homeManager.bryan-darwin = hmArgs: {
    imports = with config.flake.modules.homeManager; [
      meta
      shell
      ghostty
    ];

    home = {
      username = hmArgs.config.meta.user.name;
      homeDirectory = "/Users/${hmArgs.config.meta.user.name}";
      stateVersion = "26.05";
    };

    programs.home-manager.enable = true;
  };
}
