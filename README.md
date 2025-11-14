# Home Manager Configurations

This directory contains a separate flake for Home Manager configurations that can be used standalone or imported by other flakes.

## Structure

- `flake.nix` - Main flake definition
- `bryan/` - User-specific configurations
  - `default.nix` - Base configuration
  - `darwin.nix` - macOS-specific configuration
  - `with-de.nix` - Desktop environment configuration
  - `shell/` - Shell configurations
  - `de/` - Desktop environment configurations

## Usage

### Standalone Usage

You can use these configurations directly:

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

## Available Modules

- `bryan` - Base configuration
- `bryan-with-de` - Configuration with desktop environment
- `bryan-darwin` - macOS-specific configuration
- `bryan-shell` - Just shell configurations
- `bryan-de` - Just desktop environment configurations

## Development

Use the development shell to work on configurations:

```bash
cd home
nix develop
```

This provides access to `home-manager` and shows available commands.# Home Manager Configurations

This directory contains all Home Manager configurations, separated from NixOS/Darwin system configurations.

## Structure

```
home/
└── bryan/
    ├── default.nix        # Base home configuration (shell only)
    ├── darwin.nix         # macOS-specific home configuration
    ├── with-de.nix        # Home configuration with desktop environment
    ├── shell/             # Shell configurations (nushell, git, gpg, etc.)
    └── de/                # Desktop environment configurations (hyprland, kitty, etc.)
```

## Modules

The following home modules are exported in `flake-parts/home.nix`:

- **`bryan`**: Base home configuration for Linux (shell tools only)
- **`bryan-with-de`**: Extended home configuration with desktop environment
- **`bryan-darwin`**: macOS-specific home configuration

## Usage in NixOS

The home modules are automatically included via `home-manager.sharedModules` in NixOS configurations:

- Systems with `de = false` (wsl, orangepi5pro) use the `bryan` module
- Systems with `de = true` (panda) use the `bryan-with-de` module

## Usage in Darwin

Darwin systems use the `bryan-darwin` module which is optimized for macOS.

## Standalone Usage

You can also build home configurations standalone:

```bash
# Linux home configuration
nix build .#homeConfigurations.bryan.activationPackage

# macOS home configuration
nix build .#homeConfigurations.bryan-darwin.activationPackage
```
