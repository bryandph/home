"""Check Herdr detection using the rendered HM override in a disposable HOME."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


manifest, fixtures, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="herdr-detection-") as temporary:
    home = Path(temporary)
    config = home / ".config"
    installed = config / "herdr/agent-detection/pi.toml"
    installed.parent.mkdir(parents=True)
    shutil.copyfile(manifest, installed)
    installed.chmod(0o444)
    environment = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config))
    # Isolate caches/data too, even on machines with XDG variables exported.
    environment.update(XDG_CACHE_HOME=str(home / ".cache"),
                       XDG_DATA_HOME=str(home / ".local/share"))
    for fixture, state, rule in [
        ("trust", "blocked", "trust_project_dialog"),
        ("working", "working", "working_literal"),
        ("idle", "idle", None),
    ]:
        result = subprocess.run(
            ["herdr", "agent", "explain", "--file", str(fixtures / f"{fixture}.txt"),
             "--agent", "pi", "--json"],
            env=environment, check=True, text=True, capture_output=True,
        )
        (output / f"{fixture}.json").write_text(result.stdout)
        detected = json.loads(result.stdout)
        matched = detected["matched_rule"]
        actual_rule = matched["id"] if matched else None
        print(json.dumps({"fixture": fixture, "state": detected["state"],
                          "rule": actual_rule, "warning": detected["warning"]}), flush=True)
        assert detected["manifest_source"] == str(installed), detected
        assert detected["manifest_version"] == "2026.10.1.900", detected
        assert detected["state"] == state, detected
        assert actual_rule == rule, detected
        assert detected["warning"] is None, detected
