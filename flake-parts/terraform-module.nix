{config, ...}: {
  # Export terraform devenv as a flake module for other flakes to use
  flake.flakeModules.terraform-devenv = {
    perSystem = {system, ...}: {
      # Re-export the terraform devenv shell from this flake
      devenv.shells.default = config.devenv.shells.terraform;
    };
  };
}
