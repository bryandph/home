import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Substituted by Nix; the same runner/config is used by Claude and Codex.
const runner = "@runner@";

export default function (pi: ExtensionAPI) {
  let active = false;
  let cancelled = false;
  let latestStop: string | undefined;
  const signals = new Set<AbortSignal>();

  function play(event: string, ctx: ExtensionContext) {
    if (ctx.mode !== "tui" || !ctx.hasUI ||
        process.env.AGENTIC_SOUNDS_DISABLE === "1" ||
        process.env.WORKMUX_DISABLE_SET_WINDOW_STATUS === "1" ||
        process.env.PI_SESSION_ID || process.env.CLAUDECODE || process.env.CODEX_THREAD_ID) return;
    void pi.exec(runner, ["pi", event]).catch(() => {});
  }

  pi.on("session_start", (event, ctx) => {
    active = false;
    cancelled = false;
    latestStop = undefined;
    signals.clear();
    if (event.reason !== "reload") play("session-start", ctx);
  });
  pi.on("agent_start", (_event, ctx) => {
    if (!active) play("working", ctx);
    active = true;
    latestStop = undefined;
    if (ctx.signal) signals.add(ctx.signal);
  });
  pi.on("message_end", (event, ctx) => {
    if (ctx.signal) signals.add(ctx.signal);
    if (event.message.role === "assistant") latestStop = event.message.stopReason;
  });
  pi.on("turn_end", (_event, ctx) => {
    if (ctx.signal) signals.add(ctx.signal);
  });
  pi.on("session_compact_failed", (event) => {
    if (active && event.aborted) cancelled = true;
  });
  pi.on("ui_prompt_start", (_event, ctx) => play("waiting", ctx));
  pi.on("agent_settled", (_event, ctx) => {
    if (!ctx.isIdle() || ctx.hasPendingMessages()) return;
    // A settled agent may have been cancelled, or ended with an API error.
    // Require a successful final assistant message; never use turn_end/agent_end.
    if (active && !cancelled && latestStop === "stop" &&
        ![...signals].some(signal => signal.aborted)) play("done", ctx);
    active = false;
    cancelled = false;
    latestStop = undefined;
    signals.clear();
  });
  pi.on("session_shutdown", () => {
    active = false;
    cancelled = false;
    latestStop = undefined;
    signals.clear();
  });
}
