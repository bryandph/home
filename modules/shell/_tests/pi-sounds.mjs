import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const { default: extension } = await import(pathToFileURL(process.argv[2]));
for (const key of ['AGENTIC_SOUNDS_DISABLE', 'WORKMUX_DISABLE_SET_WINDOW_STATUS', 'PI_SESSION_ID', 'CLAUDECODE', 'CODEX_THREAD_ID']) delete process.env[key];
function fixture(mode = 'tui') {
  const handlers = new Map(), played = [];
  const ctx = {mode, hasUI: ['tui','rpc'].includes(mode), isIdle: () => true, hasPendingMessages: () => false};
  extension({on: (name, fn) => handlers.set(name, fn), exec: async (_cmd, args) => {played.push(args[1]);}});
  return {ctx, played, handlers, emit: (name, data = {}) => handlers.get(name)?.(data, ctx)};
}
function finish(f, reason = 'stop') {
  f.emit('message_end', {message: {role: 'assistant', stopReason: reason}});
  f.emit('agent_settled');
}
let f = fixture();
f.emit('session_start', {reason: 'startup'});
f.emit('agent_start');
f.emit('turn_end'); f.emit('agent_end');
assert.deepEqual(f.played, ['session-start','working']);
f.emit('ui_prompt_start');
f.emit('ui_prompt_end');
finish(f);
f.emit('agent_settled');
assert.deepEqual(f.played, ['session-start','working','waiting','done']);
assert.equal(f.handlers.has('agent_end'), false);
f.emit('session_start', {reason: 'reload'});
assert.equal(f.played.length, 4);
for (const reason of ['aborted','error','toolUse','length', undefined]) {
  f = fixture(); f.emit('agent_start'); finish(f, reason === undefined ? 'unknown' : reason);
  assert.deepEqual(f.played, ['working']);
}
f = fixture(); const controller = new AbortController(); f.ctx.signal = controller.signal;
f.emit('agent_start'); f.emit('turn_end'); controller.abort(); f.ctx.signal = undefined;
finish(f); assert.deepEqual(f.played, ['working']);
f = fixture(); f.emit('agent_start'); f.emit('session_compact_failed', {aborted:true}); finish(f); assert.deepEqual(f.played,['working']);
f = fixture(); f.emit('session_compact_failed', {aborted:true}); f.emit('agent_start'); finish(f); assert.deepEqual(f.played,['working','done']);
// Retry/compaction and queued follow-ups are a single working span.
f = fixture(); f.emit('agent_start'); f.emit('message_end', {message: {role:'assistant',stopReason:'error'}});
f.emit('agent_end'); f.emit('agent_start');
f.ctx.hasPendingMessages = () => true; finish(f); assert.deepEqual(f.played,['working']);
f.ctx.hasPendingMessages = () => false; f.ctx.isIdle = () => false; f.emit('agent_settled');
assert.deepEqual(f.played,['working']);
f.ctx.isIdle = () => true; f.emit('agent_settled'); assert.deepEqual(f.played,['working','done']);
f = fixture(); f.emit('agent_start'); f.emit('session_shutdown'); finish(f); assert.deepEqual(f.played,['working']);
for (const mode of ['print','json','rpc']) {
  f = fixture(mode); f.emit('session_start', {reason:'startup'}); f.emit('agent_start'); f.emit('ui_prompt_start'); finish(f);
  assert.deepEqual(f.played,[]);
}
for (const key of ['AGENTIC_SOUNDS_DISABLE','WORKMUX_DISABLE_SET_WINDOW_STATUS','PI_SESSION_ID','CLAUDECODE','CODEX_THREAD_ID']) {
  process.env[key] = '1'; f = fixture(); f.emit('session_start', {reason:'startup'}); f.emit('agent_start'); f.emit('ui_prompt_start'); finish(f);
  assert.deepEqual(f.played,[]); delete process.env[key];
}
console.log('Pi sound lifecycle fixtures passed');
