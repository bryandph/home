import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

bundle = json.loads(Path(sys.argv[1]).read_text())
claude = json.loads((Path(bundle['plugin']) / '.claude-plugin/plugin.json').read_text())['hooks']
codex = bundle['codex']
assert set(claude) == {'SessionStart', 'UserPromptSubmit', 'Notification', 'Stop'}
assert set(codex) == {'SessionStart', 'UserPromptSubmit', 'PermissionRequest', 'Stop'}
assert claude['Notification'][0]['matcher'] == 'permission_prompt|elicitation_dialog'
assert len(bundle['composed']['SessionStart']) == 3  # workmux + Herdr + sounds
assert len(bundle['composed']['Stop']) == 2
assert len(bundle['composed']['PermissionRequest']) == 2
assert bundle['statusOnly'] == bundle['status']
assert bundle['soundsOnly'] == codex
assert bundle['disabled'] == {}
with tempfile.TemporaryDirectory() as temp:
    log = Path(temp) / 'played.jsonl'
    env = {'PATH': os.environ['PATH'], 'SOUND_TEST_LOG': str(log), 'AGENTIC_SOUNDS_INTERACTIVE': '1'}
    count = 0
    def run(hooks, event, payload=None, overrides=None, audible=True):
        global count
        data = {'hook_event_name':event, **(payload or {})}
        command = hooks[event][0]['hooks'][0]['command']
        result = subprocess.run(command, shell=True, input=json.dumps(data), text=True, capture_output=True, env={**env, **(overrides or {})}, check=True)
        assert json.loads(result.stdout) == {}, result
        if audible:
            count += 1
            for _ in range(100):
                if log.exists() and len(log.read_text().splitlines()) >= count: break
                time.sleep(.01)
        else:
            time.sleep(.05)
        lines = log.read_text().splitlines() if log.exists() else []
        assert len(lines) == count, (event, payload, overrides, lines)
        assert all(json.loads(line) == [bundle['sound']] for line in lines)
    for hooks in [claude, codex]:
        for event in hooks: run(hooks, event)
        for variable in ['AGENTIC_SOUNDS_DISABLE','WORKMUX_DISABLE_SET_WINDOW_STATUS','PI_SESSION_ID']:
            run(hooks, 'Stop', overrides={variable:'1'}, audible=False)
        run(hooks, 'Stop', overrides={'AGENTIC_SOUNDS_INTERACTIVE':'0'}, audible=False)
        for payload in [{'agent_id':'child'}, {'agent_type':'worker'}, {'aborted':True}, {'stop_reason':'error'}, {'stop_hook_active':True}]:
            run(hooks, 'Stop', payload, audible=False)
print('Hook execution/composition fixtures passed')
