# Home Manager Configurations

This directory contains a separate flake for Home Manager configurations that can be used standalone or imported by other flakes.

## Structure

```
home/
├── flake.nix              # Main flake definition
├── flake-parts/           # Flake-parts modules for home outputs
└── bryan/
    ├── default.nix        # Base home configuration (shell only)
    ├── darwin.nix         # macOS-specific home configuration
    ├── with-de.nix        # Home configuration with desktop environment
    ├── shell/             # Shell configurations
    │   ├── default.nix    # Shell module entry point
    │   ├── ghostty.nix    # Ghostty terminal
    │   ├── git.nix        # Git configuration
    │   ├── gpg.nix        # GPG agent and keys
    │   ├── gptcommit.nix  # AI commit message generation
    │   ├── nix.nix        # Nix-related shell tools
    │   ├── nushell.nix    # Nushell configuration
    │   ├── starship.nix   # Starship prompt
    │   └── workmux.nix    # Workmux terminal multiplexer
    └── de/                # Desktop environment configurations
```

## Available Modules

The following home modules are exported:

- **`bryan`**: Base home configuration for Linux (shell tools only)
- **`bryan-with-de`**: Extended home configuration with desktop environment
- **`bryan-darwin`**: macOS-specific home configuration
- **`bryan-shell`**: Just shell configurations
- **`bryan-de`**: Just desktop environment configurations

## Usage in NixOS

The home modules are automatically included via `home-manager.sharedModules` in NixOS configurations:

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

```nix
{
  inputs = {
    home-configs = {
      url = "./path/to/home";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {home-configs, ...}: {
    # Use the modules
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

## Development

Use the development shell to work on configurations:

```bash
cd home
nix develop
```

This provides access to `home-manager` and shows available commands.
