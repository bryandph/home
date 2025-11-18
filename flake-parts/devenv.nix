{
  perSystem = {
    pkgs,
    inputs',
    lib,
    ...
  }: let
    # Common packages and hooks for all development environments
    commonPackages = with pkgs; [
      statix
      nil
      nixd
      alejandra
      deadnix
      nix-inspect
      nix-melt
      home-manager
    ];

    commonHooks = {
      gptcommit.enable = true;
      statix.enable = true;
      deadnix.enable = true;
      nix-fmt = {
        enable = true;
        name = "nix fmt";
        entry = "${pkgs.nix}/bin/nix fmt";
        language = "system";
        files = "\\.(nix|flake)$";
        pass_filenames = false;
      };
    };

    # Rust-specific configuration
    rustConfig = {
      packages = with pkgs;
        [
          openssl
          pkg-config
        ]
        ++ commonPackages;

      languages.rust = {
        enable = true;
        channel = "nightly";
        components = [
          "rustc"
          "cargo"
          "clippy"
          "rustfmt"
          "rust-analyzer"
        ];
      };

      enterShell = ''
        echo "🦀 Rust development environment ready!"
        echo "Available commands:"
        echo "  cargo build    - Build the project"
        echo "  cargo test     - Run tests"
        echo "  cargo clippy   - Run clippy linter"
        echo "  cargo fmt      - Format code"
        echo "  home-manager switch --flake .#bryan  - Switch home configuration (Linux)"
        echo "  home-manager switch --flake .#bryan-darwin - Switch home configuration (macOS)"
      '';

      git-hooks.hooks =
        commonHooks
        // {
          clippy.enable = true;
          rustfmt.enable = true;
        };

      containers = pkgs.lib.mkForce {};
    };

    # Terraform-specific configuration
    terraformConfig = {
      packages = with pkgs;
        [
          # Get terraform from a specific version if available, otherwise use default
          terraform
          terranix
          tflint
          statix
          nil
          nixd
          alejandra
          deadnix
          nix-inspect
          nix-melt
          awscli2
          google-cloud-sdk
          azure-cli
          vault
          jq
        ]
        ++ commonPackages;

      languages.terraform = {
        enable = true;
      };

      enterShell = ''
        echo "🌍 Terraform development environment ready!"
        echo "Available commands:"
        echo "  terraform init      - Initialize Terraform working directory"
        echo "  terraform validate  - Validate Terraform configuration"
        echo "  terraform plan      - Generate and show execution plan"
        echo "  terraform apply     - Apply configuration changes"
        echo "  terraform destroy   - Destroy Terraform-managed infrastructure"
        echo "  terranix           - Generate terraform from nix"
        echo "  tflint             - Terraform linter"
        echo "  vault              - HashiCorp Vault CLI"
        echo "  aws                - AWS CLI"
        echo "  gcloud             - Google Cloud CLI"
        echo "  az                 - Azure CLI"
        echo ""
        echo "Terraform version: $(${pkgs.terraform}/bin/terraform version -json | ${pkgs.jq}/bin/jq -r '.terraform_version')"
        echo ""
      '';

      git-hooks.hooks =
        commonHooks
        // {
          terraform-format.enable = true;
          tflint.enable = true;
        };

      containers = pkgs.lib.mkForce {};
    };

    # Python-specific configuration
    pythonConfig = {
      packages = with pkgs;
        [
          stdenv.cc.cc
          libuv
          zlib
        ]
        ++ commonPackages;

      languages.python = {
        enable = true;
        package = pkgs.python313;
        uv = {
          enable = true;
          sync = {
            enable = true;
            allExtras = true;
            allGroups = true;
          };
        };
      };

      enterShell = ''
        echo "🐍 Python development environment ready!"
        echo "Available commands:"
        echo "  uv add <pkg>     - Add a dependency"
        echo "  uv run <script>  - Run a script"
        echo "  uv sync          - Sync dependencies"
        echo "  python -m pytest - Run tests (if pytest is installed)"
        echo "  home-manager switch --flake .#bryan  - Switch home configuration (Linux)"
        echo "  home-manager switch --flake .#bryan-darwin - Switch home configuration (macOS)"
      '';

      git-hooks.hooks =
        commonHooks
        // {
          ruff.enable = true;
          ruff-format.enable = true;
          uv-check.enable = true;
        };

      containers = pkgs.lib.mkForce {};
    };
  in {
    devenv.shells = {
      default = {
        packages = with pkgs;
          [
            flake-checker
          ]
          ++ commonPackages;

        enterShell = ''
          echo "🏠 Welcome to Bryan's Home Manager Configuration!"
          echo "Available commands:"
          echo "  home-manager switch --flake .#bryan         - Switch home configuration (Linux)"
          echo "  home-manager switch --flake .#bryan-darwin  - Switch home configuration (macOS)"
          echo "  nix fmt                                      - Format Nix files"
          echo "  nix flake check                              - Check flake configuration"
        '';

        git-hooks = {
          hooks =
            commonHooks
            // {
              flake-checker.enable = true;
              nix-follow = lib.mkIf (inputs' ? nix-auto-follow) {
                enable = true;
                name = "nix flake follows";
                entry = "${inputs'.nix-auto-follow.packages.default}/bin/auto-follow -c";
                files = "flake\\.(lock)$";
              };
            };
        };
        containers = pkgs.lib.mkForce {};
      };

      # Rust development profile
      rust = rustConfig;

      # Python development profile
      python = pythonConfig;

      # Terraform development profile
      terraform = terraformConfig;

      # Combined development profile for polyglot projects
      polyglot = lib.recursiveUpdate rustConfig {
        packages = rustConfig.packages ++ (pythonConfig.packages ++ commonPackages);

        languages = rustConfig.languages // pythonConfig.languages;

        enterShell = ''
          echo "🚀 Polyglot development environment ready!"
          echo "🦀 Rust tools available: cargo, clippy, rustfmt"
          echo "🐍 Python tools available: uv, python"
          echo "📦 Nix tools available: statix, nil, nixd, alejandra"
          echo "🏠 Home Manager tools available"
        '';

        git-hooks.hooks = rustConfig.git-hooks.hooks // pythonConfig.git-hooks.hooks;
      };

      # Infrastructure development profile (combines terraform with other tools)
      infra = lib.recursiveUpdate terraformConfig {
        packages = terraformConfig.packages ++ commonPackages;

        enterShell = ''
          echo "🏗️ Infrastructure development environment ready!"
          echo "🌍 Terraform tools available: terraform, terranix, tflint"
          echo "☁️ Cloud CLIs available: aws, gcloud, az"
          echo "🔐 Security tools available: vault"
          echo "📦 Nix tools available: statix, nil, nixd, alejandra"
          echo "🏠 Home Manager tools available"
        '';
      };
    };
  };
}
