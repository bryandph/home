import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Bridge Pi's native UI prompt span to the pinned upstream integrations.
// Neither upstream extension is modified. This includes adapter approval UI.
const herdr = @herdr@;
export default function (pi: ExtensionAPI) {
  let waiting = false;
  function enabled(ctx: ExtensionContext) {
    return ctx.mode === "tui" && ctx.hasUI &&
      process.env.WORKMUX_DISABLE_SET_WINDOW_STATUS !== "1" &&
      !process.env.PI_SESSION_ID && !process.env.CLAUDECODE && !process.env.CODEX_THREAD_ID;
  }
  pi.on("ui_prompt_start", (_event, ctx) => {
    if (!enabled(ctx) || waiting) return;
    waiting = true;
    if (herdr) pi.events.emit("herdr:blocked", {active: true, label: "Waiting for input"});
    void pi.exec("workmux", ["set-window-status", "waiting"]).catch(() => {});
  });
  function end(ctx: ExtensionContext) {
    if (!waiting) return;
    waiting = false;
    if (herdr) pi.events.emit("herdr:blocked", {active: false});
    // Idle is not proof of success (the prompt may have been cancelled).
    void pi.exec("workmux", ["set-window-status", ctx.isIdle() ? "clear" : "working"]).catch(() => {});
  }
  pi.on("ui_prompt_end", (_event, ctx) => end(ctx));
  pi.on("session_shutdown", (_event, ctx) => end(ctx));
}
