Agent status and sounds are separate Home Manager modules. Hosts opt into
`agentic.statusHooks.enable` and `agentic.statusSounds.enable` independently.
Each has `harnesses.{claude,codex,pi}` switches; Claude defaults on, Codex/Pi off.
Host enablement and launcher reconciliation belong to the consuming flake.

For Pi status, enable `agentic.statusHooks.harnesses.pi`. Workmux's resource
comes from `agentic.statusHooks.workmuxSrc` (the configured package source by
default). With Herdr enabled, its extension comes from
`programs.herdr.package.src/src/integration/assets/pi/herdr-agent-state.ts`.
Both resources are delivered verbatim beside each other under
`~/.pi/agent/extensions/`; no integration installer runs. Packages must expose
these pinned resources. Herdr integration v8 (as shipped in 0.9.0) limits
reporting to TUI mode; older v7 also reports RPC sessions. The module does not
patch upstream behavior. The separate `status-prompts.ts` extension translates
native Pi UI prompt spans into workmux waiting/working/clear and upstream
`herdr:blocked` events. Closing a prompt while idle clears status, never claims
successful completion.

Sound configuration uses one `agentic.statusSounds.events` mapping and one
`player` for all harnesses. Player arguments accept shell-style quoting, but
shell operators/expansion are not supported. Sound paths are passed as one
literal argument; playback is detached and player output is discarded.

| Abstract event | Claude Code | Codex | Pi 0.85.1 |
| --- | --- | --- | --- |
| `session-start` | SessionStart (startup/resume/clear) | SessionStart (startup/resume/clear) | session_start except reload |
| `working` | UserPromptSubmit | UserPromptSubmit | agent_start, once per unsettled run |
| `waiting` | Notification permission_prompt/elicitation_dialog | PermissionRequest | ui_prompt_start |
| `done` | Stop | Stop | agent_settled, idle, successful final assistant stop |

Claude uses a generated plugin. Pi uses `status-sounds.ts` beside the status
extensions. Neither owns settings, authentication, trust, or session files.
Claude settings/marketplaces must remain empty in the HM module to preserve
Claude's mutable settings file.

The parent Codex launcher consumes **`agentic.statusSounds.codexHooks`**:
an event-to-hook-groups attrset, exactly like `agentic.statusHooks.codexHooks`.
It is `{}` when sounds or their Codex switch are disabled. Compose by
concatenating groups for each event, not by overwriting event keys:

```nix
lib.zipAttrsWith (_event: groups: lib.concatLists groups) [
  config.agentic.statusHooks.codexHooks
  config.agentic.statusSounds.codexHooks
]
```

The parent reconciler must manage removal of its previous sound projection
when disabled while retaining user hooks, status groups, and writable files.
Existing hook trust remains tool-owned; changed hooks may need review through
Codex's normal hook UI. See the [Codex hook contract](https://learn.chatgpt.com/docs/hooks).

Claude/Codex launchers must set **`AGENTIC_SOUNDS_INTERACTIVE=1`** only for
interactive root launches and unset it for nested/headless launches. Hooks
receive piped stdin, so they cannot infer interactivity from stdin. All sound
harnesses honor `AGENTIC_SOUNDS_DISABLE=1`,
`WORKMUX_DISABLE_SET_WINDOW_STATUS=1`, and an inherited `PI_SESSION_ID`.
Pi additionally requires `ctx.mode === "tui"` and rejects inherited
`CLAUDECODE`/`CODEX_THREAD_ID` markers. Launchers must still suppress children
whose environment lacks a recognizable parent marker.

Pi sounds ignore per-turn/low-level completion, aborted signals, failed or
cancelled compaction, unsuccessful assistant stops, queued continuations, and
shutdown. Claude/Codex done is their normal Stop hook, never Interrupt or
SessionEnd; payloads marked aborted/interrupted/error or belonging to subagents
are silent. Stop hooks run alongside other hooks, so they cannot know whether
another hook will subsequently request continuation.

Waiting is limited to available events. Pi native UI methods coalesce
nested/overlapping prompts, including adapter approvals using those methods;
custom terminal prompts and arbitrary event-bus notifications are not covered.
Codex PermissionRequest does not cover every elicitation or input UI, and may
fire before another hook resolves an approval automatically. No synthetic
waiting event is claimed for those unsupported cases.

The extensions target the installed `@earendil-works/pi-coding-agent` 0.85.1
API: `docs/extensions.md` (complete), `docs/settings.md`, `docs/packages.md`,
`docs/environment-variables.md`, and the notify, permission-gate, and event-bus
examples.

Run the focused fixtures on a supported local system:

```sh
nix build --no-link .#checks.aarch64-darwin.agent-status-sounds
```

They execute generated Claude/Codex hook commands with a recording player,
check literal filename handling and suppression, exercise Pi lifecycle/prompt
sequences, and evaluate independent composition and mutable-file ownership.
Workmux delivery uses a minimal source fixture because the standalone home
pin predates its Pi/Codex resources. Validate the consuming flake's configured
package sources as part of pin/host integration. These tests do not replace
live workstation audio and approval-dialog verification.
