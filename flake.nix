{
  description = "Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-root.url = "github:srid/flake-root";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    stylix = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-auto-follow = {
      url = "github:fzakaria/nix-auto-follow";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.inputs.systems.follows = "systems";
      };
    };
  };

  outputs = inputs @ {flake-parts, ...}: let
    # Global configuration - can be overridden when importing this flake
    defaultGlobals = {
      user = "bryan";
      fullname = "Bryan Prather-Huff";
      email = "bryan@pratherhuff.com";
      gpg_thumbprint = "6ADCBDDF44590F83";
      sshPublicKey = builtins.readFile (
        builtins.fetchurl {
          url = "https://github.com/bryandph.keys";
          sha256 = "198i0v7zwk8ziqlyx001rrw2rpfnsna3v4n7gz3scf2s28d0zana";
        }
      );
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      imports = [
        inputs.flake-root.flakeModule
        inputs.home-manager.flakeModules.home-manager
        ./flake-parts
      ];

      _module.args = {
        globals = defaultGlobals;
      };

      flake = {
        # Home modules that can be imported by other flakes
        homeModules = {
          bryan = ./bryan;
          bryan-with-de = ./bryan/with-de.nix;
          bryan-darwin = ./bryan/darwin.nix;

          # Individual component modules
          bryan-shell = ./bryan/shell;
          bryan-de = ./bryan/de;
        };

        # Function to create home configurations (for use by importing flakes)
        lib = {
          # Function to create home configurations with custom globals
          mkHomeConfiguration = {
            system,
            modules,
            globals ? defaultGlobals,
            extraSpecialArgs ? {},
          }:
            inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              extraSpecialArgs =
                {
                  inherit globals;
                }
                // extraSpecialArgs;
              modules =
                modules
                ++ [
                  inputs.sops-nix.homeManagerModules.sops
                ];
            };

          # Helper to create configurations with different globals
          mkHomeConfigurationWithGlobals = globals: {
            system,
            modules,
            extraSpecialArgs ? {},
          }:
            inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              extraSpecialArgs =
                {
                  inherit globals;
                }
                // extraSpecialArgs
                // {globals = defaultGlobals // globals;};
              modules =
                modules
                ++ [
                  inputs.sops-nix.homeManagerModules.sops
                ];
            };
        };

        # Standalone home configurations
        homeConfigurations = {
          # NixOS home configuration
          "${defaultGlobals.user}" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
            extraSpecialArgs = {
              inherit (defaultGlobals) user;
              globals = defaultGlobals;
            };
            modules = [
              ./bryan
              inputs.sops-nix.homeManagerModules.sops
              inputs.stylix.homeModules.stylix
            ];
          };

          # Darwin home configuration
          "${defaultGlobals.user}-darwin" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nix-darwin.legacyPackages.aarch64-darwin;
            extraSpecialArgs = {
              inherit (defaultGlobals) user;
              globals = defaultGlobals;
            };
            modules = [
              ./bryan/darwin.nix
              inputs.sops-nix.homeManagerModules.sops
              inputs.stylix.homeModules.stylix
            ];
          };
        };
      };
    };
}
