# Home Manager Configurations

This directory contains a separate flake for Home Manager configurations that
can be used standalone or imported by other flakes. It follows the
[dendritic pattern](https://github.com/mightyiam/dendritic): every `.nix` file
under `modules/` is a top-level flake-parts module, auto-discovered via
[import-tree](https://github.com/vic/import-tree) — there are no manual import
lists.

## Structure

```
home/
├── flake.nix                  # Inputs + import-tree ./modules (no logic)
└── modules/
    ├── flake-parts.nix        # Bootstrap: systems + third-party flakeModules
    ├── meta/                  # Identity options (meta.user.*)
    │   ├── _defaults.nix      #   single source of the operator identity
    │   ├── _hm-module.nix     #   HM-level option declarations
    │   └── options.nix        #   flake-level options + the `meta` HM feature
    ├── infrastructure/        # Plumbing
    │   ├── home-manager.nix   #   configurations.home factory -> homeConfigurations + checks
    │   ├── exports.nix        #   homeModules / flakeModules.default / lib shims
    │   ├── apps.nix           #   nix run .#<app> maintenance apps
    │   └── treefmt.nix        #   nix fmt -> treefmt -> alejandra
    ├── shell/                 # Feature modules: git, gpg, helix, k9s,
    │                          #   nix-tools, nushell, sesh, starship, tmux,
    │                          #   workmux, ghostty, packages
    ├── de/                    # Feature modules: hyprland, kitty, chromium, wofi
    ├── presets/               # Bundles: shell, de (pure imports, no gates)
    ├── profiles/              # Coarse exports: bryan, bryan-with-de, bryan-darwin
    └── configurations/        # Standalone homeConfigurations: bryan, bryan-darwin
```

Each feature module sets `flake.modules.homeManager.<name>`; composition is by
import (no `enable` gates). Files/dirs prefixed with `_` are helpers skipped by
import-tree and imported by path where needed.

## Identity (`meta.user.*`)

User identity lives in HM-level options — `meta.user.{name, email, fullname,
gpgFingerprint}` — mirroring the option names of nixspace's `modules/meta.nix`.
Defaults are the operator identity; consumers override them with ordinary
module definitions (the legacy `globals` extraSpecialArgs pass-thru is gone,
but the `lib` shims still translate it for old call sites).

## Exports

Tier-1 (classic, stable contract):

- **`homeModules.bryan`** — base Linux home (shell tools only)
- **`homeModules.bryan-with-de`** — bryan + desktop environment
- **`homeModules.bryan-darwin`** — macOS home
- **`nixos-modules.{bryan-shell, bryan-de}`** — legacy aliases for the shell/de
  bundles (they are HM modules; prefer homeModules)
- **`lib.mkHomeConfiguration{,WithGlobals}`** — compat constructors taking the
  legacy `globals` attrset

Tier-2 (dendritic consumers):

- **`flakeModules.default`** — a flake-parts module that re-exports the coarse
  profiles into the consumer's own `flake.modules.homeManager.*` tree.

## Usage in NixOS

The home modules are included via `home-manager.sharedModules` in nixspace
NixOS configurations:

- Systems with `withDE = false` (wsl, servers, most SBCs) use the `bryan` module
- Systems with `withDE = true` (panda, dell, uconsole) use the `bryan-with-de` module

## Usage in Darwin

Darwin systems use the `bryan-darwin` module which is optimized for macOS.

## Standalone Usage

```bash
# For NixOS/Linux
home-manager switch --flake ./home#bryan

# For macOS
home-manager switch --flake ./home#bryan-darwin
```

### Importing in Other Flakes

Classic consumption:

```nix
{
  inputs = {
    home-configs = {
      url = "./path/to/home";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {home-configs, ...}: {
    homeConfigurations.myuser = home-configs.lib.mkHomeConfiguration {
      system = "x86_64-linux";
      modules = [
        home-configs.homeModules.bryan
        # your additional modules
      ];
      globals = {
        user = "myuser";
        # other globals
      };
    };
  };
}
```

Dendritic consumption (flake-parts):

```nix
{
  imports = [inputs.home-configs.flakeModules.default];
  # then compose, e.g.:
  #   configurations.nixos.<host>.module.imports =
  #     [config.flake.modules.homeManager.bryan];
}
```

## Maintenance

```bash
nix fmt              # treefmt -> alejandra
nix flake check      # builds the standalone configurations as checks
nix run .#home-switch        # home-manager switch .#bryan
nix run .#home-switch-darwin # home-manager switch .#bryan-darwin
```
