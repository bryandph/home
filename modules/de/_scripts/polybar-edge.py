"""Own one primary-output Polybar and reveal it without reserving screen space."""
import fcntl
import os
import re
import signal
import subprocess
import sys
import time

from Xlib import X, display, error

config, polybar, message, xrandr = sys.argv[1:]
lock = open(os.path.join(os.environ["XDG_RUNTIME_DIR"], "polybar-edge.lock"), "w")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)

connection = display.Display()
root = connection.screen().root
pid_atom = connection.intern_atom("_NET_WM_PID")
child = None


def stop():
    global child
    if child is not None:
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
        child = None


def outputs():
    text = subprocess.check_output([xrandr, "--query"], text=True)
    active = []
    for line in text.splitlines():
        match = re.match(r"(\S+) connected (primary )?(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", line)
        if match:
            name, primary, width, height, x, y = match.groups()
            active.append((bool(primary), name, int(width), int(height), int(x), int(y)))
    return max(active, key=lambda output: output[0]) if active else None


def set_visible(visible):
    result = subprocess.run([message, "-p", str(child.pid), "cmd", "show" if visible else "hide"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def raise_bar():
    # Raising never changes keyboard focus. Repeat while revealed so overlays
    # and newly mapped clients cannot cover the controls.
    for window in root.query_tree().children:
        try:
            prop = window.get_full_property(pid_atom, X.AnyPropertyType)
            if prop is not None and prop.value[0] == child.pid:
                window.configure(stack_mode=X.Above)
        except error.BadWindow:
            pass
    connection.flush()


def terminate(_signal, _frame):
    raise SystemExit(0)


for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(sig, terminate)

monitor = None
visible = None
last_inside = 0
next_scan = 0
try:
    while True:
        now = time.monotonic()
        if now >= next_scan:
            selected = outputs()
            if selected != monitor or child is None or child.poll() is not None:
                stop()
                monitor = selected
                visible = None
                last_inside = 0
                if monitor:
                    child = subprocess.Popen([polybar, "-c", config, "desktop"],
                                             env={**os.environ, "MONITOR": monitor[1]})
            next_scan = now + 2
        if monitor and child and child.poll() is None:
            _, _, width, _, x, y = monitor
            pointer = root.query_pointer()
            inside = x <= pointer.root_x < x + width and y <= pointer.root_y < y + (28 if visible else 2)
            if inside or pointer.mask & (X.Button1Mask | X.Button2Mask | X.Button3Mask):
                last_inside = now
            desired = inside or (visible is True and now - last_inside < 0.6)
            if desired != visible and set_visible(desired):
                visible = desired
            if visible:
                raise_bar()
        time.sleep(0.1)
finally:
    stop()
    connection.close()
