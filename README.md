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
    ├── de/                    # Feature modules: hyprland, i3, shared keymap, rofi, bars
    ├── presets/               # Bundles: shell, de-hyprland, de-i3, desktop-i3
    ├── profiles/              # Coarse exports: bryan, bryan-with-de, bryan-with-i3, bryan-darwin
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
- **`homeModules.bryan-with-de`** — bryan + Hyprland (stable export)
- **`homeModules.bryan-with-i3`** — bryan + i3
- **`homeModules.desktop-i3`** — reusable i3 session without operator identity, browser or idle policy
- **`homeModules.{de-hyprland,de-i3}`** — desktop presets without the shell profile
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

- Systems with `de = null` (wsl, servers, most SBCs) use the `bryan` module
- Systems with `de = "hyprland"` (panda, dell, uconsole) use the `bryan-with-de` module

The parent `desktops` registry pairs system and home modules. Set
`configurations.nixos.<host>.de = "i3"` or `"hyprland"`; no additional
session bundle imports are required. Blackbox composes `desktop-i3` separately
with its appliance account and always-on policy.

### Shared desktop bindings

The modifier is **SUPER** (changed from ALT). Both sessions use:

| Binding | Action |
| --- | --- |
| SUPER+Return / d / e / Tab | Terminal / applications / files / windows |
| SUPER+q / f | Close / fullscreen |
| SUPER+arrows or h/j/k/l | Focus in a direction |
| SUPER+Shift+arrows or h/j/k/l | Move in a direction |
| SUPER+1–9 / SUPER+Shift+1–9 | Switch workspace / move window |
| SUPER+space / SUPER+Shift+space | Toggle split layout / floating |
| SUPER+r, then arrows, Escape or Return | Resize, then leave resize mode |
| SUPER+Shift+x / SUPER+Shift+e | Lock / exit session |

Override `de.keymap.mod`, `de.keymap.commands.<name>`, `de.keymap.bindings`
or `de.keymap.resizeBindings` through normal Home Manager options. The same
semantic list drives both renderers. Rofi provides the UI on both sessions;
the Hyprland window picker enumerates native Wayland clients through IPC.
The Hyprland preset still expects the consumer's hyprshell Home Manager module,
as before; nixspace supplies it in the system bundle.

On i3, a lone tiled window has no window-manager title bar or gaps. Opening
another tiled window restores normal title bars; floating overlays do not count.
Browser tabs and navigation remain visible. Polybar overlays the primary output
without reserving space: move the pointer to its top edge to reveal it, and move
away to hide it after 600ms. Its workspace, audio and tray controls remain usable.

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
