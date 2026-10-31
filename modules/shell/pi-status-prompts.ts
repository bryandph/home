import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Bridge native UI prompt spans (including adapter approvals) to Herdr's
// pinned integration. Its blocked counter restores working/idle on close.
export default function (pi: ExtensionAPI) {
  let waiting = false;
  function enabled(ctx: ExtensionContext) {
    return ctx.mode === "tui" && ctx.hasUI &&
      process.env.AGENTIC_STATUS_DISABLE !== "1" &&
      !process.env.PI_SESSION_ID && !process.env.CLAUDECODE && !process.env.CODEX_THREAD_ID;
  }
  pi.on("ui_prompt_start", (_event, ctx) => {
    if (!enabled(ctx) || waiting) return;
    waiting = true;
    ctx.ui.setStatus("agent-prompt", "Waiting for input");
    pi.events.emit("herdr:blocked", {active: true, label: "Waiting for input"});
  });
  function end(ctx: ExtensionContext) {
    if (!waiting) return;
    waiting = false;
    ctx.ui.setStatus("agent-prompt", undefined);
    // Herdr restores working/idle; closing a prompt is not proof of success.
    pi.events.emit("herdr:blocked", {active: false});
  }
  pi.on("ui_prompt_end", (_event, ctx) => end(ctx));
  pi.on("session_shutdown", (_event, ctx) => end(ctx));
}
