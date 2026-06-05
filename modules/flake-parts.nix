# Dendritic bootstrap. Imports `flake-parts.flakeModules.modules` (which
# adds the `flake.modules.<class>.<name>` namespace used by every feature
# module) plus the third-party flakeModules this flake consumes. flake.nix's
# outputs collapse to just `(inputs.import-tree ./modules)`.
{inputs, ...}: {
  systems = import inputs.systems;

  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
    inputs.treefmt-nix.flakeModule
  ];
}
