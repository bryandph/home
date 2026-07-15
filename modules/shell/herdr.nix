# Vendored `programs.herdr` HM module (options + implementation) — kept as
# a path import (dedup-safe): the nixspace parent enables it per-host
# (wsl, macbookpro) with its own pkgs.herdr, while this flake's standalone
# configurations enable it with the herdr flake input's package.
{
  flake.modules.homeManager.herdr = ./_herdr-module.nix;
}
