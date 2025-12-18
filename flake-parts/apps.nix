{globals, ...}: {
  perSystem = {pkgs, ...}: let
    # Reusable script components
    scripts = {
      fmt = ''
        set -euo pipefail
        ${pkgs.nix}/bin/nix fmt
      '';

      gitCommitPush = ''
        set -euo pipefail
        ${pkgs.git}/bin/git add .

        # Only commit if there are changes
        # Exit code 1 means "nothing to commit", which is fine
        if ! ${pkgs.git}/bin/git diff-index --quiet HEAD -- 2>/dev/null; then
          ${pkgs.git}/bin/git commit -a
          ${pkgs.git}/bin/git push
        else
          echo "No changes to commit, skipping commit and push"
        fi
      '';

      flakeCheck = ''
        set -euo pipefail
        ${pkgs.nix}/bin/nix flake check --impure --all-systems --log-format internal-json 2>&1 | ${pkgs.nix-output-monitor}/bin/nom --json
      '';

      homeSwitch = user: ''
        set -euo pipefail
        ${pkgs.home-manager}/bin/home-manager switch --flake .#${user}
      '';

      # Composed scripts
      commit = ''
        ${scripts.fmt}
        ${scripts.gitCommitPush}
      '';
    };

    # Helper to create script apps with error handling
    mkApp = script: description: {
      type = "app";
      program = toString (
        pkgs.writeShellScript "app" ''
          set -euo pipefail
          ${script}
        ''
      );
      meta.description = description;
    };
  in {
    apps = {
      # Basic operations
      fmt = mkApp scripts.fmt "Format code with nix fmt";
      commit = mkApp scripts.commit "Format, commit and push changes to git";
      check = mkApp scripts.flakeCheck "Check flake configuration";

      # Update flake inputs
      update = mkApp ''
        ${pkgs.nix}/bin/nix flake update
      '' "Update flake inputs";

      # Home Manager operations
      home-switch = mkApp (scripts.homeSwitch globals.user) "Switch home configuration for ${globals.user}";

      home-switch-darwin = mkApp (scripts.homeSwitch "${globals.user}-darwin") "Switch home configuration for ${globals.user} on Darwin";

      # Combined operations (format, commit, then switch)
      home-deploy = mkApp ''
        ${scripts.commit}
        ${scripts.homeSwitch globals.user}
      '' "Format, commit and switch home configuration for ${globals.user}";

      home-deploy-darwin = mkApp ''
        ${scripts.commit}
        ${scripts.homeSwitch "${globals.user}-darwin"}
      '' "Format, commit and switch home configuration for ${globals.user} on Darwin";

      # Development shell launchers
      dev-rust = mkApp ''
        ${pkgs.nix}/bin/nix develop .#rust --impure
      '' "Enter Rust development environment";

      dev-python = mkApp ''
        ${pkgs.nix}/bin/nix develop .#python --impure
      '' "Enter Python development environment";

      dev-polyglot = mkApp ''
        ${pkgs.nix}/bin/nix develop .#polyglot --impure
      '' "Enter polyglot (Rust + Python) development environment";

      dev-terraform = mkApp ''
        ${pkgs.nix}/bin/nix develop .#terraform --impure
      '' "Enter Terraform development environment";

      dev-infra = mkApp ''
        ${pkgs.nix}/bin/nix develop .#infra --impure
      '' "Enter Infrastructure (Terraform + tools) development environment";
    };
  };
}
