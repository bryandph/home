# `configurations.home.<name>` factory — INFRASTRUCTURE. Maps each entry to
# `flake.homeConfigurations.<name>` plus a per-system build check
# (`configurations:home:<name>`, mirroring the parent's
# `configurations:nixos:<name>` naming). Always injects sops-nix (design
# decision: secrets plumbing is infrastructure, not a per-config import) and
# pins the HM-level `meta.user.*` options to this flake's top-level values so
# flake-level overrides propagate into every standalone configuration.
{
  lib,
  config,
  inputs,
  ...
}: {
  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.submodule {
      options = {
        system = lib.mkOption {
          type = lib.types.str;
          default = "x86_64-linux";
          description = "Platform the configuration activates on.";
        };
        module = lib.mkOption {
          type = lib.types.deferredModule;
          description = "Home Manager module composing flake.modules.homeManager features.";
        };
      };
    });
    default = {};
    description = "Standalone Home Manager configurations, composed from flake.modules.homeManager features.";
  };

  config.flake = {
    homeConfigurations =
      lib.mapAttrs (
        _name: cfg:
          inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs.legacyPackages.${cfg.system};
            modules = [
              cfg.module
              inputs.sops-nix.homeManagerModules.sops
              {
                meta.user = {inherit (config.meta.user) name email fullname gpgFingerprint;};
                # Mirrors the parent's factory convention
                # (modules/configurations/nixos.nix); standalone-only — the
                # parent composes profiles with useGlobalPkgs instead.
                nixpkgs.config.allowUnfree = true;
              }
            ];
          }
      )
      config.configurations.home;

    checks = lib.mkMerge (lib.mapAttrsToList (name: cfg: {
        ${cfg.system}."configurations:home:${name}" =
          config.flake.homeConfigurations.${name}.activationPackage;
      })
      config.configurations.home);
  };
}
