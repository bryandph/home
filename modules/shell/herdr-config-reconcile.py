#!/usr/bin/env python3
"""Reconcile Nix-owned top-level Herdr settings into its writable config."""

from __future__ import annotations

import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

import tomlkit


STATE_VERSION = 1


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


def read_owned_keys(path: Path) -> set[str]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            state = json.load(handle)
    except FileNotFoundError:
        return set()

    if not isinstance(state, dict) or state.get("version") != STATE_VERSION:
        raise ValueError(f"invalid reconciliation state in {path}")
    keys = state.get("owned_top_level")
    if not isinstance(keys, list) or not all(isinstance(key, str) for key in keys):
        raise ValueError(f"invalid owned_top_level list in {path}")
    return set(keys)


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


def reconcile(desired_path: Path) -> None:
    desired = read_toml(desired_path, missing_ok=False)
    desired_keys = set(desired.keys())
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
            previously_owned = read_owned_keys(managed_state_path)

            for key in previously_owned - desired_keys:
                live.pop(key, None)
            for key in desired_keys:
                live[key] = copy.deepcopy(desired[key])

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
                    "owned_top_level": sorted(desired_keys),
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
    if len(sys.argv) != 2:
        print("usage: herdr-config-reconcile DESIRED_TOML", file=sys.stderr)
        return 2

    live_path = herdr_config_path()
    try:
        reconcile(Path(sys.argv[1]))
    except Exception as error:
        print(f"herdr config reconciliation failed for {live_path}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
