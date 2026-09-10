"""Advisory sound hook: no configuration writes and no hook decisions."""
import json
import os
import shlex
import subprocess
import sys


def allowed(harness, event, payload, env):
    if (env.get("AGENTIC_SOUNDS_DISABLE") == "1"
            or env.get("WORKMUX_DISABLE_SET_WINDOW_STATUS") == "1"
            or env.get("PI_SESSION_ID")):
        return False
    if harness != "pi" and env.get("AGENTIC_SOUNDS_INTERACTIVE") != "1":
        return False
    if payload.get("agent_id") or payload.get("agent_type"):
        return False
    # Stop is a normal completion hook; never wire Interrupt/SessionEnd to done.
    if event == "done" and (payload.get("stop_hook_active")
                            or payload.get("aborted")
                            or payload.get("stop_reason") in ("aborted", "error", "interrupted")):
        return False
    return True


def main():
    config_path, harness, event = sys.argv[1:]
    try:
        payload = {} if harness == "pi" else json.load(sys.stdin)
        if not isinstance(payload, dict) or not allowed(harness, event, payload, os.environ):
            return
        with open(config_path) as stream:
            config = json.load(stream)
        sound = config["events"].get(event)
        player = shlex.split(config["player"])
        if sound and player:
            # Preserve player arguments without interpreting sound paths as shell code.
            subprocess.Popen(player + [sound],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
    except (OSError, ValueError, KeyError):
        pass  # An unavailable player must never interfere with the agent.


if __name__ == "__main__":
    main()
    # Codex Stop requires JSON. This is advisory and carries no decision.
    print("{}")
