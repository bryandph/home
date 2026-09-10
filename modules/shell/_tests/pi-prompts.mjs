import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const {default: extension} = await import(pathToFileURL(process.argv[2]));
for (const key of ['WORKMUX_DISABLE_SET_WINDOW_STATUS','PI_SESSION_ID','CLAUDECODE','CODEX_THREAD_ID']) delete process.env[key];
const handlers = new Map(), states = [], blocked = [];
const ctx = {mode:'tui', hasUI:true, isIdle:() => false};
extension({on:(event, fn) => handlers.set(event, fn), events:{emit:(name,data) => blocked.push([name,data.active])}, exec:async (_cmd,args) => states.push(args[1])});
const emit = name => handlers.get(name)?.({},ctx);
emit('ui_prompt_start'); emit('ui_prompt_start'); emit('ui_prompt_end'); emit('ui_prompt_end');
assert.deepEqual(states,['waiting','working']);
assert.deepEqual(blocked,[['herdr:blocked',true],['herdr:blocked',false]]);
ctx.isIdle = () => true; emit('ui_prompt_start'); emit('ui_prompt_end');
assert.deepEqual(states.slice(-2),['waiting','clear']); // Cancellation cannot imply done.
emit('ui_prompt_start'); emit('session_shutdown');
assert.deepEqual(blocked.slice(-2),[['herdr:blocked',true],['herdr:blocked',false]]);
const count = states.length;
for (const mode of ['rpc','print','json']) {ctx.mode=mode; emit('ui_prompt_start'); emit('ui_prompt_end');}
ctx.mode='tui';
for (const key of ['WORKMUX_DISABLE_SET_WINDOW_STATUS','PI_SESSION_ID','CLAUDECODE','CODEX_THREAD_ID']) {
  process.env[key]='1'; emit('ui_prompt_start'); emit('ui_prompt_end'); delete process.env[key];
}
assert.equal(states.length,count);
console.log('Pi prompt bridge fixtures passed');
