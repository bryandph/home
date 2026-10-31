"""Run the real Codex blocked bridge against a bounded local socket."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading

with tempfile.TemporaryDirectory(prefix="status-", dir="/tmp") as temp:
    endpoint = str(Path(temp) / "hook.sock")
    reports = []
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(endpoint)
        server.listen()
        server.settimeout(5)

        def receive():
            conn, _ = server.accept()
            with conn:
                reports.append(json.loads(conn.recv(65536)))
                conn.sendall(b'{"ok":true}\n')

        env = {"PATH": os.environ["PATH"], "HERDR_ENV": "1",
               "HERDR_SOCKET_PATH": endpoint, "HERDR_PANE_ID": "fixture-pane"}
        def run(payload=None, overrides=None):
            result = subprocess.run([sys.executable, sys.argv[1]],
                                    input=json.dumps(payload or {}), text=True,
                                    capture_output=True, check=True,
                                    env={**env, **(overrides or {})})
            assert json.loads(result.stdout) == {}
        listener = threading.Thread(target=receive)
        listener.start()
        run({"session_id": "root"}, {"CODEX_THREAD_ID": "root"})
        listener.join(6)
        assert not listener.is_alive()
        params = reports[0]["params"]
        assert params["state"] == "blocked" and params["agent_session_id"] == "root"
        assert params["source"] == "herdr:codex"
        for overrides in [{"HERDR_ENV": "0"}, {"AGENTIC_STATUS_DISABLE": "1"},
                          {"CODEX_THREAD_ID": "parent"}]:
            run({"session_id": "child"}, overrides)
        for payload in [{"agent_id": "child"}, {"agent_type": "worker"}, ["invalid"]]:
            run(payload)
        server.settimeout(.05)
        try:
            server.accept()
            raise AssertionError("Suppressed hook reported a state")
        except TimeoutError:
            pass
print("Codex Herdr blocked bridge and suppression fixtures passed")
