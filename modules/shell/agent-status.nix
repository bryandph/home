# Agent status plane: cross-harness workmux status hooks + composable
# notification sounds (bryan/nixspace#86). Kept as path imports (dedup-safe)
# and options-only — hosts opt in via `agentic.statusHooks.enable` /
# `agentic.statusSounds.enable`.
{
  flake.modules.homeManager.agent-status-hooks = ./_agent-status-module.nix;
  flake.modules.homeManager.agent-status-sounds = ./_status-sounds-module.nix;
}
