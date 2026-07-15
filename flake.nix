{
  description = "Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-auto-follow = {
      url = "github:fzakaria/nix-auto-follow";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.inputs.systems.follows = "systems";
      };
    };
    # Fleet contract data (operator identity). Private repo on git.bph;
    # re-exports the mandala engine, so this is the only pin needed.
    mandala-bph = {
      url = "git+ssh://git@git.bph/bryan/mandala-bph";
      inputs.mandala.inputs.nixpkgs.follows = "nixpkgs";
    };
    # Agentic environment core (bryan/nixspace#85): shared MCP/agent
    # registry definitions. Direct pin for standalone eval (design Open
    # Question 3 resolved: same shape as mandala-bph); the parent
    # follows-dedupes it when composed. Consumption of the user-plane
    # modules lands with bryan/nixspace#86.
    agentic = {
      url = "git+ssh://git@git.bph/bryan/agentic";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        import-tree.follows = "import-tree";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    workmux = {
      url = "github:raine/workmux";
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    import-tree,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} (import-tree ./modules);
}
