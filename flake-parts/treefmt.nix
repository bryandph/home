{
  perSystem = {config, ...}: {
    treefmt.config = {
      inherit (config.flake-root) projectRootFile;
      programs = {
        alejandra.enable = true;
        just.enable = true;
        yamlfmt.enable = true;
      };
    };
  };
}
