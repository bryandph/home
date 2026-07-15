# Standalone configuration: `homeConfigurations.bryan` (x86_64-linux).
# Composes the bryan profile + stylix theming, and supplies what standalone
# activation needs beyond the profile: home.username/homeDirectory (set by
# the home-manager NixOS module when composed by the parent) and the workmux
# package from this flake's input (set per-host by the parent).
{
  config,
  inputs,
  ...
}: {
  configurations.home.bryan = {
    system = "x86_64-linux";
    module = {pkgs, ...}: {
      imports = [
        config.flake.modules.homeManager.bryan
        inputs.stylix.homeModules.stylix
      ];

      home = {
        username = config.meta.user.name;
        homeDirectory = "/home/${config.meta.user.name}";
      };

      programs.workmux = {
        enable = true;
        package = inputs.workmux.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      programs.herdr = {
        enable = true;
        package = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    };
  };
}
