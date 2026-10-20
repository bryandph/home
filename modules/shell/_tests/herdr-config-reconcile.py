"""herdr-config-reconcile ownership: whole top-level keys, `ui.<table>` for
the shared `ui` section, v1 state migration, and retirement of owned paths
without touching Herdr's own settings."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

RECONCILE = Path(os.environ["RECONCILE"])


class ReconcileTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.live = self.root / "config.toml"
        self.env = dict(
            os.environ,
            HERDR_CONFIG_PATH=str(self.live),
            XDG_STATE_HOME=str(self.root / "state"),
        )

    def reconcile(self, desired: str) -> dict:
        desired_path = self.root / "desired.toml"
        desired_path.write_text(desired)
        subprocess.run(
            [sys.executable, RECONCILE, desired_path, "--shared-table", "ui"],
            env=self.env,
            check=True,
        )
        return tomllib.loads(self.live.read_text())

    def state(self) -> dict:
        (path,) = (self.root / "state" / "herdr").glob("nix-managed-config-*.json")
        return json.loads(path.read_text())

    def test_ui_tables_are_owned_without_herdr_ui_settings(self):
        self.live.write_text(
            'onboarding = false\n[ui]\nstatus_indicators = "dots"\n[ui.sound]\nenabled = true\n'
        )
        live = self.reconcile(
            '[keys]\nprefix = "ctrl+a"\n[ui.sidebar.spaces]\nrows = [["state_icon", "$tree"]]\n'
        )
        self.assertEqual(live["ui"]["sidebar"]["spaces"]["rows"], [["state_icon", "$tree"]])
        self.assertEqual(live["ui"]["status_indicators"], "dots")
        self.assertTrue(live["ui"]["sound"]["enabled"])
        self.assertFalse(live["onboarding"])
        self.assertEqual(self.state()["owned"], ["keys", "ui.sidebar"])

        live = self.reconcile('[keys]\nprefix = "ctrl+b"\n')
        self.assertNotIn("sidebar", live["ui"])
        self.assertEqual(live["ui"]["status_indicators"], "dots")
        self.assertEqual(live["keys"]["prefix"], "ctrl+b")

    def test_retiring_the_only_ui_table_drops_the_emptied_section(self):
        live = self.reconcile('[ui.sidebar.spaces]\nrows = [["workspace"]]\n')
        self.assertIn("ui", live)
        live = self.reconcile('[keys]\nprefix = "ctrl+a"\n')
        self.assertNotIn("ui", live)

    def test_version_one_state_is_read_as_top_level_paths(self):
        self.live.write_text('[keys]\nprefix = "ctrl+a"\n[terminal]\nnew_cwd = "follow"\n')
        self.reconcile('[keys]\nprefix = "ctrl+a"\n[terminal]\nnew_cwd = "follow"\n')
        (path,) = (self.root / "state" / "herdr").glob("nix-managed-config-*.json")
        path.write_text(json.dumps({"version": 1, "owned_top_level": ["keys", "terminal"]}))
        live = self.reconcile('[keys]\nprefix = "ctrl+a"\n')
        self.assertNotIn("terminal", live)
        self.assertEqual(self.state()["version"], 2)


if __name__ == "__main__":
    unittest.main()
