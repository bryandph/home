#!/usr/bin/env python3
"""Herdr plugin: show filesystem hierarchy in the Spaces sidebar (BPH-72).

Herdr nests only one level natively (linked worktrees under their primary).
This plugin approximates path nesting on each server it runs on:

* order: spaces are sorted depth-first by path with one atomic
  `workspace.move_block`; grouped worktrees still follow their primary.
* indentation: each space gets a `tree` workspace token holding its tree
  prefix and label, rendered by `$tree` in `ui.sidebar.spaces.rows`.

Depth counts open ancestor spaces, not directories, so intermediate
directories that are not spaces never appear. Herdr trims surrounding
whitespace from token values, so indentation uses U+2800 (braille blank,
not whitespace) instead of spaces.

Every hook run recomputes from live state, and both writes are no-ops when
nothing changed. `workspace.reordered` and metadata updates must therefore
never be hooked: they would only re-trigger this script.
"""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import socket
import sys
from typing import Any

TOKEN = "tree"
SOURCE = "plugin:bph.sidebar-tree"
BLANK = "\u2800"
INDENT_BLANK = BLANK + " "
INDENT_PIPE = "│ "
BRANCH_MID = "├ "
BRANCH_LAST = "└ "


def space_path(workspace: dict[str, Any], pane_cwds: dict[str, str]) -> str | None:
    worktree = workspace.get("worktree") or {}
    path = worktree.get("checkout_path") or pane_cwds.get(workspace["workspace_id"])
    return os.path.normpath(path) if path else None


def is_within(path: str, ancestor: str) -> bool:
    return path != ancestor and path.startswith(ancestor.rstrip("/") + "/")


def plan(
    workspaces: list[dict[str, Any]], pane_cwds: dict[str, str]
) -> tuple[list[str], dict[str, str]]:
    """Return (desired workspace order, workspace_id -> tree token)."""
    index = {w["workspace_id"]: i for i, w in enumerate(workspaces)}

    # Mirror Herdr's grouping: a repo key groups only when it has both a
    # primary and a linked worktree open. Grouped linked worktrees are drawn
    # under the primary natively, so they never take part in path nesting.
    members: dict[str, list[dict[str, Any]]] = {}
    for workspace in workspaces:
        worktree = workspace.get("worktree")
        if worktree:
            members.setdefault(worktree["repo_key"], []).append(workspace)
    grouped = {
        key
        for key, group in members.items()
        if any(m["worktree"]["is_linked_worktree"] for m in group)
        and any(not m["worktree"]["is_linked_worktree"] for m in group)
    }

    def is_grouped_child(workspace: dict[str, Any]) -> bool:
        worktree = workspace.get("worktree")
        return bool(
            worktree
            and worktree["is_linked_worktree"]
            and worktree["repo_key"] in grouped
        )

    nodes = [w for w in workspaces if not is_grouped_child(w)]
    paths = {w["workspace_id"]: space_path(w, pane_cwds) for w in workspaces}

    parent: dict[str, str | None] = {}
    for node in nodes:
        own = paths[node["workspace_id"]]
        best = None
        if own:
            for candidate in nodes:
                theirs = paths[candidate["workspace_id"]]
                if theirs and is_within(own, theirs):
                    if best is None or len(theirs) > len(paths[best]):
                        best = candidate["workspace_id"]
        parent[node["workspace_id"]] = best

    children: dict[str | None, list[str]] = {}
    for node in nodes:
        children.setdefault(parent[node["workspace_id"]], []).append(node["workspace_id"])

    def sibling_key(workspace_id: str) -> tuple[str, int]:
        return ((paths[workspace_id] or "").casefold(), index[workspace_id])

    for siblings in children.values():
        siblings.sort(key=sibling_key)

    worktree_children: dict[str, list[str]] = {}
    for key in grouped:
        primary = next(m for m in members[key] if not m["worktree"]["is_linked_worktree"])
        worktree_children[primary["workspace_id"]] = [
            m["workspace_id"] for m in members[key] if m["worktree"]["is_linked_worktree"]
        ]

    by_id = {w["workspace_id"]: w for w in workspaces}
    order: list[str] = []
    tokens: dict[str, str] = {}

    def label(workspace_id: str) -> str:
        return (by_id[workspace_id].get("label") or "").strip() or workspace_id

    def visit(workspace_id: str, depth: int, continuation: str, last: bool) -> None:
        order.append(workspace_id)
        if depth == 0:
            tokens[workspace_id] = label(workspace_id)
            below = ""
        else:
            tokens[workspace_id] = (
                continuation + (BRANCH_LAST if last else BRANCH_MID) + label(workspace_id)
            )
            below = continuation + (INDENT_BLANK if last else INDENT_PIPE)
        # Herdr draws grouped worktrees behind a fixed `   ├─ ` connector, so
        # their labels start 5 columns right of a top-level label; each depth
        # moves the primary 2 columns. Pad only once the primary would
        # otherwise reach its worktrees, to keep the narrow sidebar readable.
        for child in worktree_children.get(workspace_id, []):
            order.append(child)
            tokens[child] = BLANK * max(0, 2 * (depth - 2)) + label(child)
        nested = children.get(workspace_id, [])
        for position, child in enumerate(nested):
            visit(child, depth + 1, below, position == len(nested) - 1)

    roots = children.get(None, [])
    for root in roots:
        visit(root, 0, "", True)
    return order, tokens


class Herdr:
    """Raw socket client; the server closes each connection after one reply."""

    def __init__(self, socket_path: str) -> None:
        self.socket_path = socket_path
        self.sequence = 0

    def call(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        self.sequence += 1
        request = {"id": f"sidebar-tree-{self.sequence}", "method": method, "params": params}
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.connect(self.socket_path)
            connection.sendall(json.dumps(request).encode() + b"\n")
            with connection.makefile("rb") as reader:
                response = json.loads(reader.readline())
        if "error" in response:
            raise RuntimeError(f"{method}: {response['error']}")
        return response["result"]


def first_pane_cwds(panes: list[dict[str, Any]]) -> dict[str, str]:
    cwds: dict[str, str] = {}
    for pane in panes:
        cwd = pane.get("cwd") or pane.get("foreground_cwd")
        if cwd:
            cwds.setdefault(pane["workspace_id"], cwd)
    return cwds


def apply(herdr: Herdr) -> None:
    workspaces = herdr.call("workspace.list", {})["workspaces"]
    if not workspaces:
        return
    panes = herdr.call("pane.list", {})["panes"]
    order, tokens = plan(workspaces, first_pane_cwds(panes))

    if order != [w["workspace_id"] for w in workspaces]:
        herdr.call("workspace.move_block", {"workspace_ids": order})
    for workspace in workspaces:
        wanted = tokens.get(workspace["workspace_id"])
        if (workspace.get("tokens") or {}).get(TOKEN) != wanted:
            herdr.call(
                "workspace.report_metadata",
                {
                    "workspace_id": workspace["workspace_id"],
                    "source": SOURCE,
                    "tokens": {TOKEN: wanted},
                },
            )


def main() -> int:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        print("sidebar-tree: HERDR_SOCKET_PATH is not set", file=sys.stderr)
        return 1
    state = Path(os.environ.get("HERDR_PLUGIN_STATE_DIR") or "/tmp")
    state.mkdir(parents=True, exist_ok=True)

    # Hooks fire in bursts (one worktree create emits several events). The
    # first run takes the lock; later runs only mark the state dirty and exit,
    # and the holder repeats until no run arrived during its pass. The
    # recheck after unlocking catches a run that marked dirty just before.
    dirty = state / "dirty"
    dirty.touch()
    herdr = None
    while dirty.exists():
        with open(state / "lock", "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return 0
            herdr = herdr or Herdr(socket_path)
            while dirty.exists():
                dirty.unlink()
                apply(herdr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
