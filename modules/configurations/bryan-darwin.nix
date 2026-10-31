# Standalone configuration: `homeConfigurations.bryan-darwin`
# (aarch64-darwin). The profile already sets home.username/homeDirectory.
# Note: the pre-dendritic flake built this with the nonexistent
# `inputs.nix-darwin.legacyPackages` (standalone eval was broken on main);
# the factory now uses nixpkgs.legacyPackages like every other system.
{
  config,
  inputs,
  ...
}: {
  configurations.home.bryan-darwin = {
    system = "aarch64-darwin";
    module = {
      imports = [
        config.flake.modules.homeManager.bryan-darwin
        inputs.stylix.homeModules.stylix
      ];
    };
  };
}
