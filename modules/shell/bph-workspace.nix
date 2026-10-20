# The BPH tree as this user's workspace root: agentic's workspace module
# points herdr's worktree root at ~/BPH/.worktrees and makes git record
# relative worktree links. The repo list itself lives in the BPH repo.
{inputs, ...}: {
  flake.modules.homeManager.bph-workspace = {config, ...}: {
    imports = [inputs.agentic.homeModules.workspace];
    agentic.workspace.root = "${config.home.homeDirectory}/BPH";
  };
}
