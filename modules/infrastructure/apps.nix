# Maintenance apps (`nix run .#<app>`) — INFRASTRUCTURE. The dev-* shell
# launcher apps from the pre-dendritic flake were dropped: they pointed at
# devShells this flake has never defined, so they could not work.
{config, ...}: {
  perSystem = {pkgs, ...}: let
    user = config.meta.user.name;

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

      homeSwitch = name: ''
        set -euo pipefail
        ${pkgs.home-manager}/bin/home-manager switch --flake .#${name}
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
      home-switch = mkApp (scripts.homeSwitch user) "Switch home configuration for ${user}";

      home-switch-darwin = mkApp (scripts.homeSwitch "${user}-darwin") "Switch home configuration for ${user} on Darwin";

      # Combined operations (format, commit, then switch)
      home-deploy = mkApp ''
        ${scripts.commit}
        ${scripts.homeSwitch user}
      '' "Format, commit and switch home configuration for ${user}";

      home-deploy-darwin = mkApp ''
        ${scripts.commit}
        ${scripts.homeSwitch "${user}-darwin"}
      '' "Format, commit and switch home configuration for ${user} on Darwin";
    };
  };
}
