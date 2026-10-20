# Checks for the Herdr sidebar tree (BPH-72): the tree planner's unit tests,
# a link of the generated plugin by the pinned Herdr (manifest, platforms,
# and event names validate without warnings), and config.toml reconciliation
# owning `ui.<table>` without Herdr's own UI settings.
{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    system,
    ...
  }: let
    herdr = inputs.herdr.packages.${system}.default;
    plugin = config.packages.herdr-sidebar-tree;
  in {
    checks.herdr-sidebar-tree = pkgs.runCommand "herdr-sidebar-tree-check" {nativeBuildInputs = [pkgs.python3 pkgs.jq herdr];} ''
      cd ${./_herdr-sidebar-tree}
      python3 -B -m unittest -v test_sidebar_tree
      cd "$TMPDIR"

      export HOME=$TMPDIR/home XDG_CONFIG_HOME=$TMPDIR/config
      mkdir -p "$HOME" "$XDG_CONFIG_HOME"
      herdr plugin link ${plugin} > linked.json
      jq -e '.result.plugin
        | .plugin_id == "${plugin.pluginId}"
          and .enabled
          and ((.warnings // []) | length == 0)
          and (.events | length > 0)' linked.json
      touch "$out"
    '';

    checks.herdr-config-reconcile =
      pkgs.runCommand "herdr-config-reconcile-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.tomlkit]))];
        RECONCILE = ./herdr-config-reconcile.py;
      } ''
        python3 -B ${./_tests/herdr-config-reconcile.py} -v
        touch "$out"
      '';
  };
}
