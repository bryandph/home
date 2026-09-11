"""Remove decorations from a lone tiled client; leave floating overlays alone."""
import fcntl
import os

import i3ipc

lock = open(os.path.join(os.environ["XDG_RUNTIME_DIR"], "i3-single-window.lock"), "w")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)


def tiled_windows(node):
    if node.window:
        yield node
    for child in node.nodes:
        yield from tiled_windows(child)


def update(connection, _event=None):
    commands = []
    for workspace in connection.get_tree().workspaces():
        if workspace.name == "__i3_scratch":
            continue
        windows = list(tiled_windows(workspace))
        style, width = ("none", 0) if len(windows) == 1 else ("normal", 2)
        for window in windows:
            if window.border != style or window.current_border_width != width:
                commands.append(f"[con_id={window.id}] border {style} {width}")
    if commands:
        connection.command("; ".join(commands))


connection = i3ipc.Connection(auto_reconnect=True)
connection.on("window", update)
connection.on("workspace", update)
connection.on("binding", update)
update(connection)
connection.main()
