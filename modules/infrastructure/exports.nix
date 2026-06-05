# Export surface for consumers — INFRASTRUCTURE.
#
# Tier-1 (classic): `homeModules.{bryan, bryan-with-de, bryan-darwin}` — the
# stable contract the nixspace parent imports into home-manager.sharedModules
# and `lib.mkHomeConfiguration{,WithGlobals}` consumes. Values are the merged
# deferred modules from flake.modules.homeManager, so non-dendritic consumers
# keep working unchanged.
#
# Tier-2 (dendritic): `flakeModules.default` — a flake-parts module that
# re-exports the coarse profiles into a consumer's own
# `flake.modules.homeManager.*` tree. Re-export of values only (no option
# declarations), so it cannot collide with the consumer's flake-level options.
#
# `lib.mkHomeConfiguration{,WithGlobals}` keep the legacy `globals` calling
# convention: the attrset is still passed through extraSpecialArgs for any
# pre-dendritic consumer modules, and additionally translated onto the
# HM-level `meta.user.*` options that the converted feature modules read.
{
  config,
  inputs,
  ...
}: let
  hm = config.flake.modules.homeManager;

  defaultGlobals = {
    user = config.meta.user.name;
    inherit (config.meta.user) email fullname;
    gpg_thumbprint = config.meta.user.gpgFingerprint;
  };

  # Legacy `globals` shape -> HM `meta.user.*` definitions. Imports the meta
  # option module by PATH so the module system dedups it against the same
  # path arriving via a profile import. Also supplies mkDefault
  # home.username/homeDirectory derived from globals + system (the legacy lib
  # never set them, leaving standalone activation broken) and the same
  # allowUnfree the factory uses.
  globalsToShim = globals: system: {lib, ...}: {
    imports = [../meta/_hm-module.nix];
    meta.user = {
      name = globals.user;
      inherit (globals) email fullname;
      gpgFingerprint = globals.gpg_thumbprint;
    };
    home = {
      username = lib.mkDefault globals.user;
      homeDirectory = lib.mkDefault (
        if lib.hasSuffix "darwin" system
        then "/Users/${globals.user}"
        else "/home/${globals.user}"
      );
    };
    nixpkgs.config.allowUnfree = true;
  };

  mkWithGlobals = globals: {
    system,
    modules,
    extraSpecialArgs ? {},
  }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {inherit globals;} // extraSpecialArgs;
      modules =
        modules
        ++ [
          inputs.sops-nix.homeManagerModules.sops
          (globalsToShim globals system)
        ];
    };
in {
  flake = {
    homeModules = {
      inherit (hm) bryan bryan-with-de bryan-darwin;
    };

    # Legacy export name kept for external compat — these are Home Manager
    # modules (the name predates the split); new consumers should use
    # homeModules or flakeModules.default instead.
    nixos-modules = {
      bryan-shell = hm.shell;
      bryan-de = hm.de;
    };

    flakeModules.default = {
      flake.modules.homeManager = {
        inherit (hm) bryan bryan-with-de bryan-darwin;
      };
    };

    lib = {
      mkHomeConfigurationWithGlobals = mkWithGlobals;
      mkHomeConfiguration = {
        system,
        modules,
        globals ? defaultGlobals,
        extraSpecialArgs ? {},
      }:
        mkWithGlobals globals {inherit system modules extraSpecialArgs;};
    };
  };
}
