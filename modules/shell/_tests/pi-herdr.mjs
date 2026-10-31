// Exercise our prompt bridge against the real pinned Herdr extension/socket.
import assert from 'node:assert/strict';
import net from 'node:net';
import {mkdtempSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {EventEmitter} from 'node:events';
const temp = mkdtempSync('/tmp/pi-herdr-');
const socket = join(temp, 'status.sock');
Object.assign(process.env, {HERDR_ENV:'1', HERDR_SOCKET_PATH:socket, HERDR_PANE_ID:'fixture-pane'});
for (const key of ['AGENTIC_STATUS_DISABLE','PI_SESSION_ID','CLAUDECODE','CODEX_THREAD_ID']) delete process.env[key];
const reports = [], labels = [];
const server = net.createServer(conn => {
  let input = '';
  conn.on('data', data => {
    input += data;
    if (!input.includes('\n')) return;
    reports.push(JSON.parse(input.split('\n')[0]));
    conn.end('{"ok":true}\n');
  });
});
await new Promise(resolve => server.listen(socket, resolve));
try {
  const {default: native} = await import(pathToFileURL(process.argv[2]));
  const {default: bridge} = await import(pathToFileURL(process.argv[3]));
  const handlers = new Map(), events = new EventEmitter();
  const pi = {events, on:(event, fn) => {
    handlers.set(event, [...(handlers.get(event) ?? []), fn]);
  }, exec:() => {throw Error('No status CLI allowed');}};
  native(pi); bridge(pi);
  let idle = false;
  const ctx = {mode:'tui', hasUI:true, isIdle:() => idle,
    ui:{setStatus:(key,value) => labels.push([key,value])},
    sessionManager:{getSessionId:() => 'fixture-session', getSessionFile:() => '/tmp/fixture-session.jsonl'}};
  const emit = async name => {for (const fn of handlers.get(name) ?? []) await fn({}, ctx);};
  const state = async expected => {
    for (let i = 0; i < 200; i++) {
      if (reports.filter(r => r.method === 'pane.report_agent').at(-1)?.params.state === expected) return;
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    assert.fail(`Missing ${expected}: ${JSON.stringify(reports)}`);
  };
  await emit('session_start'); await state('working');
  await emit('ui_prompt_start'); await emit('ui_prompt_start'); await state('blocked');
  assert.deepEqual(labels.at(-1), ['agent-prompt','Waiting for input']);
  console.log('Pi status: Waiting for input; Herdr socket: blocked');
  await emit('ui_prompt_end'); await emit('ui_prompt_end'); await state('working');
  assert.deepEqual(labels.at(-1), ['agent-prompt',undefined]);
  idle = true; await emit('agent_settled'); await state('idle');
  await emit('ui_prompt_start'); await state('blocked');
  await emit('session_shutdown'); await state('idle');
  const states = reports.filter(r => r.method === 'pane.report_agent').map(r => r.params.state);
  assert.deepEqual(states, ['working','blocked','working','idle','blocked','idle']);
  console.log(`Pinned Herdr prompt/socket integration passed: ${states.join(' -> ')}`);
} finally {
  await new Promise(resolve => server.close(resolve));
  rmSync(temp, {recursive:true, force:true});
}
