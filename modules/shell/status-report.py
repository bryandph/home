"""Advisory Codex PermissionRequest bridge to Herdr's native blocked state."""
import json
import os
import socket
import sys
import time


def main():
    env = os.environ
    if (env.get("HERDR_ENV") != "1"
            or env.get("AGENTIC_STATUS_DISABLE") == "1"
            or not env.get("HERDR_SOCKET_PATH") or not env.get("HERDR_PANE_ID")):
        return
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict) or payload.get("agent_id") or payload.get("agent_type"):
        return
    session = payload.get("session_id")
    inherited = env.get("CODEX_THREAD_ID")
    if inherited and inherited != session:
        return
    params = {"pane_id": env["HERDR_PANE_ID"], "source": "herdr:codex",
              "agent": "codex", "seq": time.time_ns(), "state": "blocked",
              "message": "Waiting for approval"}
    if isinstance(session, str) and session:
        params["agent_session_id"] = session
    request = {"id": f"herdr:codex:waiting:{time.time_ns()}",
               "method": "pane.report_agent", "params": params}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(.5)
        sock.connect(env["HERDR_SOCKET_PATH"])
        sock.sendall((json.dumps(request) + "\n").encode())
        sock.recv(4096)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError):
        pass  # Status must never interfere with the harness.
    print("{}")
