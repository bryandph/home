# Coarse profile export: base Linux home (Tier-1 `homeModules.bryan`).
# Deliberately does NOT set home.username/homeDirectory — in the nixspace
# parent's NixOS HM eval those come from the home-manager NixOS module; the
# standalone configuration (modules/configurations/bryan.nix) sets them
# itself.
{config, ...}: {
  flake.modules.homeManager.bryan = {lib, ...}: {
    imports = with config.flake.modules.homeManager; [
      meta
      shell
    ];

    home.stateVersion = "26.05";

    services.ssh-agent.enable = lib.mkDefault true;
  };
}
