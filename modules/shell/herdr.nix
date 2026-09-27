# Vendored `programs.herdr` HM module (options + implementation) — kept as
# a path import (dedup-safe). The reusable Bryan profiles enable it with this
# flake's Herdr input so parent hosts do not need per-host declarations.
{
  flake.modules.homeManager.herdr = ./_herdr-module.nix;
}
