# Herdr Spaces sidebar as a filesystem tree (BPH-72). The plugin
# (_herdr-sidebar-tree/sidebar_tree.py) sorts spaces depth-first by path and
# reports each one's tree-prefixed label as the `tree` workspace token; the
# Space rows render `$tree` in place of the built-in `workspace` name.
#
# Tokens are per server: a machine shown in the sidebar without this plugin
# renders its spaces without names, so every profile running Herdr composes
# this feature through the shell preset.
{
  perSystem = {pkgs, ...}: {
    packages.herdr-sidebar-tree = import ./_herdr-sidebar-tree/package.nix {inherit pkgs;};
  };

  flake.modules.homeManager.herdr-sidebar-tree = {pkgs, ...}: let
    plugin = import ./_herdr-sidebar-tree/package.nix {inherit pkgs;};
  in {
    programs.herdr = {
      plugins.${plugin.pluginId} = plugin;
      extraConfig.ui.sidebar.spaces.rows = [
        ["state_icon" "$tree"]
        ["branch" "git_status"]
      ];
    };
  };
}
