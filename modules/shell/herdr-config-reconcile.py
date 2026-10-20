#!/usr/bin/env python3
"""Reconcile Nix-owned Herdr settings into its writable config.

Ownership is tracked per dotted path. Most top-level keys are owned whole;
keys named with --shared-table (Herdr writes `ui.sound`, `ui.toast`, and
`ui.status_indicators` itself) are owned one level down, so Nix can declare
`ui.sidebar` without replacing Herdr's runtime UI settings.
"""

from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

import tomlkit


STATE_VERSION = 2


def herdr_config_path() -> Path:
    if "HERDR_CONFIG_PATH" in os.environ:
        return Path(os.environ["HERDR_CONFIG_PATH"])
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config_home / "herdr" / "config.toml"


def state_path(config_path: Path) -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    identity = hashlib.sha256(os.fsencode(config_path.absolute())).hexdigest()[:16]
    return state_home / "herdr" / f"nix-managed-config-{identity}.json"


def read_toml(path: Path, *, missing_ok: bool):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return tomlkit.load(handle)
    except FileNotFoundError:
        if missing_ok and not path.is_symlink():
            return tomlkit.document()
        raise


def read_owned_paths(path: Path) -> set[str]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            state = json.load(handle)
    except FileNotFoundError:
        return set()

    if not isinstance(state, dict) or state.get("version") not in (1, STATE_VERSION):
        raise ValueError(f"invalid reconciliation state in {path}")
    # Version 1 recorded top-level keys, which are valid one-segment paths.
    keys = state.get("owned_top_level" if state["version"] == 1 else "owned")
    if not isinstance(keys, list) or not all(isinstance(key, str) for key in keys):
        raise ValueError(f"invalid owned path list in {path}")
    return set(keys)


def owned_paths(desired, shared_tables: set[str]) -> set[str]:
    paths = set()
    for key, value in desired.items():
        if key in shared_tables:
            if not isinstance(value, dict):
                raise ValueError(f"shared table {key!r} must be a table in the desired config")
            paths.update(f"{key}.{child}" for child in value)
        else:
            paths.add(key)
    return paths


def lookup(document, path: str):
    node = document
    for segment in path.split("."):
        node = node[segment]
    return node


def remove_path(document, path: str) -> None:
    *parents, leaf = path.split(".")
    chain = [document]
    for segment in parents:
        node = chain[-1].get(segment)
        if not isinstance(node, dict):
            return
        chain.append(node)
    chain[-1].pop(leaf, None)
    # Drop tables the removal emptied, but never the document itself.
    for depth in range(len(parents), 0, -1):
        if chain[depth]:
            break
        chain[depth - 1].pop(parents[depth - 1], None)


def set_path(document, path: str, value) -> None:
    *parents, leaf = path.split(".")
    node = document
    for segment in parents:
        if segment not in node:
            node[segment] = tomlkit.table()
        node = node[segment]
        if not isinstance(node, dict):
            raise ValueError(f"live config key {segment!r} is not a table")
    node[leaf] = value


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", text=True
    )
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def reconcile(desired_path: Path, shared_tables: set[str]) -> None:
    desired = read_toml(desired_path, missing_ok=False)
    desired_paths = owned_paths(desired, shared_tables)
    live_path = herdr_config_path()
    managed_state_path = state_path(live_path)

    live_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = live_path.with_name(f".{live_path.name}.nix-lock")
    lock_descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        os.fchmod(lock_descriptor, 0o600)
        with os.fdopen(lock_descriptor, "r+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)

            live = read_toml(live_path, missing_ok=True)
            previously_owned = read_owned_paths(managed_state_path)

            for path in sorted(previously_owned - desired_paths):
                remove_path(live, path)
            for path in sorted(desired_paths):
                set_path(live, path, copy.deepcopy(lookup(desired, path)))

            rendered = tomlkit.dumps(live)
            existing = None
            if live_path.exists() or live_path.is_symlink():
                existing = live_path.read_text(encoding="utf-8")
            if live_path.is_symlink() or rendered != existing:
                atomic_write(live_path, rendered)
            else:
                os.chmod(live_path, 0o600)

            rendered_state = json.dumps(
                {
                    "version": STATE_VERSION,
                    "owned": sorted(desired_paths),
                },
                indent=2,
            ) + "\n"
            existing_state = (
                managed_state_path.read_text(encoding="utf-8")
                if managed_state_path.exists()
                else None
            )
            if rendered_state != existing_state:
                atomic_write(managed_state_path, rendered_state)
            else:
                os.chmod(managed_state_path, 0o600)
    finally:
        try:
            os.close(lock_descriptor)
        except OSError:
            # os.fdopen owns and normally closes the descriptor.
            pass


def main() -> int:
    parser = argparse.ArgumentParser(prog="herdr-config-reconcile")
    parser.add_argument("desired", type=Path)
    parser.add_argument("--shared-table", action="append", default=[])
    args = parser.parse_args()

    live_path = herdr_config_path()
    try:
        reconcile(args.desired, set(args.shared_table))
    except Exception as error:
        print(f"herdr config reconciliation failed for {live_path}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
