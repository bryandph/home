# Formatter entry point — `nix fmt` routes through treefmt -> alejandra
# (single formatting pipeline; never invoke alejandra/nixfmt directly).
# The treefmt-nix flakeModule wires perSystem.formatter automatically.
{
  perSystem.treefmt = {
    projectRootFile = "flake.nix";
    programs.alejandra.enable = true;
  };
}
