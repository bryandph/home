{
  description = "Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    systems.url = "github:nix-systems/default";
    
    # Optional: Keep stylix for consistent theming
    stylix = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    systems,
    stylix,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs (import systems);
    
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
      hashedPassword = "$6$Wj94imiW4A7WusuF$gfdED9RXUbodgwJvNiTC5gWH6l4jKk1sIiNxFN72jY/KA/5fncMdkFcGowCbWaqs9l4Wtup/4ppRDpR7tQxr/1";
      walletAddress = "4AGMcHcEQov124yn5wTTgXDxDwqjyyLEzaMjYJLbH4Ms7DiWirinYj4QhV3YiEXVr88VAnPNropphanP3ffGrTVZBpsKYHZ";
    };
    
    # Function to create home configurations with custom globals
    mkHomeConfiguration = {
      system,
      modules,
      globals ? defaultGlobals,
      extraSpecialArgs ? {},
    }: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit globals;
      } // extraSpecialArgs;
      modules = modules ++ [
        sops-nix.homeManagerModules.sops
      ];
    };
    
  in {
    # Standalone home configurations
    homeConfigurations = {
      # NixOS home configuration
      "${defaultGlobals.user}" = mkHomeConfiguration {
        system = "x86_64-linux";
        modules = [
          ./bryan
        ];
      };
      
      # Darwin home configuration  
      "${defaultGlobals.user}-darwin" = mkHomeConfiguration {
        system = "aarch64-darwin";
        modules = [
          ./bryan/darwin.nix
        ];
      };
    };
    
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
      inherit mkHomeConfiguration;
      
      # Helper to create configurations with different globals
      mkHomeConfigurationWithGlobals = globals: {
        system,
        modules,
        extraSpecialArgs ? {},
      }: mkHomeConfiguration {
        inherit system modules extraSpecialArgs;
        globals = defaultGlobals // globals;
      };
    };
    
    # Development shell for working on home configurations
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          home-manager
        ];
        shellHook = ''
          echo "Home Manager development shell"
          echo "Available commands:"
          echo "  home-manager switch --flake .#${defaultGlobals.user}"
          echo "  home-manager switch --flake .#${defaultGlobals.user}-darwin"
        '';
      };
    });
    
    # Formatter for the home configurations
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}