# Vendored `programs.workmux` HM module (options + implementation) — kept as
# a path import (dedup-safe) and options-only: the nixspace parent enables it
# per-host (wsl, macbookpro) with its own pkgs.workmux, while this flake's
# standalone configurations enable it with the workmux flake input's package.
{
  flake.modules.homeManager.workmux = ./_workmux-module.nix;
}
