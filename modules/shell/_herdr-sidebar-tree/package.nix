# The sidebar-tree plugin directory: a generated manifest whose hooks run
# sidebar_tree.py under a pinned Python. `passthru.pluginId` is the manifest
# id, for programs.herdr.plugins.
{pkgs}: let
  pluginId = "bph.sidebar-tree";
  # Herdr has no cwd-change hook, so focus changes pick up a `cd` in a
  # space's first pane. Never hook `workspace.reordered`/`workspace.moved`:
  # the plugin's own reorder emits them.
  events = [
    "workspace.created"
    "workspace.closed"
    "workspace.renamed"
    "workspace.updated"
    "workspace.focused"
    "worktree.created"
    "worktree.opened"
    "worktree.removed"
    "tab.created"
  ];
  script = pkgs.writeScript "herdr-sidebar-tree" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./sidebar_tree.py}
  '';
  command = [(toString script)];
  manifest = (pkgs.formats.toml {}).generate "herdr-plugin.toml" {
    id = pluginId;
    name = "Sidebar tree";
    version = "0.1.0";
    min_herdr_version = "0.8.0";
    description = "Nest Spaces sidebar entries by filesystem path";
    platforms = ["linux" "macos"];
    startup = [{inherit command;}];
    actions = [
      {
        id = "apply";
        title = "Re-sort sidebar tree";
        contexts = ["workspace"];
        inherit command;
      }
    ];
    events = map (on: {inherit on command;}) events;
  };
in
  pkgs.runCommand "herdr-sidebar-tree" {passthru = {inherit pluginId;};} ''
    mkdir -p "$out"
    cp ${manifest} "$out/herdr-plugin.toml"
  ''
