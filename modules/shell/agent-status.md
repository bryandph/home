Agent status and sounds are separate Home Manager modules. Hosts opt into
`agentic.statusHooks.enable` and `agentic.statusSounds.enable` independently.
Each has `harnesses.{claude,codex,pi}` switches; Claude defaults on, Codex/Pi off.
The status module also supports OpenCode. Host enablement and mutable launcher
configuration belong to the consuming flake.

Status resources now come from `agentic.statusHooks.herdrSrc`, defaulting to
`programs.herdr.package.src`. Native Claude/Codex shell scripts, the OpenCode
plugin, and Pi extension are delivered from the pinned Herdr source without
patches or an imperative integration installer. Claude's lifecycle hook lets
Herdr follow its transcript. Codex reports session/working/idle through the
native script; a separate PermissionRequest bridge reports blocked. Herdr must
be enabled. Missing resources fail assertions at evaluation time.

For Pi, enable `agentic.statusHooks.harnesses.pi`. The native Herdr extension
tracks TUI working/idle state and listens for `herdr:blocked`. The adjacent
`status-prompts.ts` extension translates native UI prompt spans (including
adapter approvals) into that event, and displays **Waiting for input** in Pi's
status area even outside Herdr. Closing/cancelling a prompt clears that label
and lets Herdr restore working/idle; it never claims successful completion.
Duplicate prompt starts/ends are coalesced. Shutdown releases a pending block.
RPC/JSON/print and nested sessions do not report prompts. Set
`AGENTIC_STATUS_DISABLE=1` to suppress the local prompt/approval bridges.

Sound configuration uses one `agentic.statusSounds.events` mapping and one
`player` for all harnesses. Player arguments use shell-style quoting without
shell operators/expansion; sound paths are passed as one literal argument.
Playback is detached and output discarded. An unavailable player is advisory.

| Event | Claude Code | Codex | Pi |
| --- | --- | --- | --- |
| session-start | SessionStart (startup/resume/clear) | SessionStart (startup/resume/clear) | session_start except reload |
| working | UserPromptSubmit | UserPromptSubmit | agent_start, once per unsettled run |
| waiting | Notification permission_prompt/elicitation_dialog | PermissionRequest | ui_prompt_start |
| done | Stop | Stop | agent_settled, idle, successful final assistant stop |

Claude uses separate generated status and sound plugins; Pi uses separate
extensions. No module owns mutable settings, authentication, trust or sessions.
Claude settings/marketplaces must remain empty to preserve writability.
The parent Codex launcher concatenates hook groups per event and reconciles
its owned projection while retaining user hooks and writable files:

```nix
lib.zipAttrsWith (_event: groups: lib.concatLists groups) [
  config.agentic.statusHooks.codexHooks
  config.agentic.statusSounds.codexHooks
]
```

Claude/Codex launchers set `AGENTIC_SOUNDS_INTERACTIVE=1` only for interactive
root launches and unset it for nested/headless launches. All sound harnesses
honor `AGENTIC_SOUNDS_DISABLE=1`, `AGENTIC_STATUS_DISABLE=1`, and inherited
`PI_SESSION_ID`; Pi also rejects `CLAUDECODE`/`CODEX_THREAD_ID` and requires
`ctx.mode === "tui"` plus `hasUI`. Hooks cannot infer interactivity from piped
stdin. Launchers must suppress children without recognizable parent markers.

Pi done sounds ignore per-turn/low-level completion, aborted signals, failed
or cancelled compaction, unsuccessful assistant stops, queued continuations,
and shutdown. Claude/Codex Stop is normal completion, not Interrupt/SessionEnd;
aborted/error/subagent payloads are silent. Another Stop hook may still request
continuation. Waiting covers native UI methods only, not arbitrary terminal
prompts or event-bus notifications. Codex PermissionRequest may precede an
automatic approval and does not cover every elicitation UI.

Run `nix build --no-link .#checks.aarch64-darwin.agent-status-sounds` for
composition, mutable-file ownership, literal filename handling, suppression,
and Pi lifecycle/prompt fixtures using a recording sound player. The tests
use the actual pinned Herdr resource, not a substitute source fixture. They
do not replace manual workstation prompt visibility and audible playback
verification. No Home Manager or Darwin switch is needed to exercise the
extensions directly from their generated store files.
