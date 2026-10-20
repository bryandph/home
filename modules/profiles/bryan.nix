# Coarse profile export: base Linux home (Tier-1 `homeModules.bryan`).
# Deliberately does NOT set home.username/homeDirectory — in the nixspace
# parent's NixOS HM eval those come from the home-manager NixOS module; the
# standalone configuration (modules/configurations/bryan.nix) sets them
# itself.
{
  config,
  inputs,
  ...
}: {
  flake.modules.homeManager.bryan = {
    lib,
    pkgs,
    ...
  }: {
    imports = with config.flake.modules.homeManager; [
      meta
      shell
    ];

    home.stateVersion = "26.05";

    programs.herdr = {
      enable = true;
      package = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # One worktree root for every repo in the BPH layout; herdr creates
      # checkouts at <directory>/<repo>/<branch-slug>.
      extraConfig.worktrees.directory = "~/BPH/.worktrees";
    };

    services.ssh-agent.enable = lib.mkDefault true;
  };
}
