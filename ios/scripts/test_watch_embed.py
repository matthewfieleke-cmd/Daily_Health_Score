#!/usr/bin/env python3
"""Tests for Watch companion embed helpers."""
from __future__ import annotations

import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
IOS = SCRIPTS.parent
MIRROR = SCRIPTS / "mirror_watch_embed.sh"

import sys

sys.path.insert(0, str(SCRIPTS))
from patch_watch_embed import patch_text  # noqa: E402


def _plist(path: Path) -> dict:
    with path.open("rb") as handle:
        return plistlib.load(handle)


class PatchWatchEmbedTests(unittest.TestCase):
    def test_leaves_watch_destination_alone(self) -> None:
        pbx = """
		ABC123ABC123ABC123ABC123 /* Embed Watch Content */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
			dstSubfolderSpec = 16;
			files = (
				DEF /* DailyHealthScoreWatch.app in Embed Watch Content */,
			);
			name = "Embed Watch Content";
			runOnlyForDeploymentPostprocessing = 0;
		};
"""
        text, status = patch_text(pbx)
        self.assertEqual(status, "watch")
        self.assertEqual(text, pbx)

    def test_restores_plugins_destination_to_watch(self) -> None:
        pbx = """
		ABC123ABC123ABC123ABC123 /* Embed Watch Content */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				DEF /* DailyHealthScoreWatch.app in Embed Watch Content */,
			);
			name = "Embed Watch Content";
			runOnlyForDeploymentPostprocessing = 0;
		};
"""
        text, status = patch_text(pbx)
        self.assertEqual(status, "patched")
        self.assertIn('dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";', text)
        self.assertIn("dstSubfolderSpec = 16;", text)
        self.assertNotIn("dstSubfolderSpec = 13;", text)

    def test_missing_phase(self) -> None:
        text, status = patch_text("isa = PBXNativeTarget;\n")
        self.assertEqual(status, "missing")
        self.assertEqual(text, "isa = PBXNativeTarget;\n")


class MirrorWatchEmbedTests(unittest.TestCase):
    def _run(
        self,
        bundle: Path,
        *,
        platform: str = "iphoneos",
        extra_env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "PLATFORM_NAME": platform,
                "TARGET_BUILD_DIR": str(bundle.parent),
                "FULL_PRODUCT_NAME": bundle.name,
            }
        )
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["sh", str(MIRROR)],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def _make_watch_app(self, parent: Path) -> None:
        app = parent / "DailyHealthScoreWatch.app"
        app.mkdir(parents=True)
        (app / "Info.plist").write_text("watch\n")

    def test_mirrors_plugins_into_watch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "DailyHealthScore.app"
            self._make_watch_app(bundle / "PlugIns")
            result = self._run(bundle)
            self.assertEqual(result.returncode, 0, result.stderr)
            watch_info = bundle / "Watch" / "DailyHealthScoreWatch.app" / "Info.plist"
            self.assertTrue(watch_info.is_file())
            self.assertEqual(watch_info.read_text(), "watch\n")
            self.assertIn("PlugIns/ -> Watch/", result.stdout)

    def test_mirrors_watch_into_plugins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "DailyHealthScore.app"
            self._make_watch_app(bundle / "Watch")
            result = self._run(bundle)
            self.assertEqual(result.returncode, 0, result.stderr)
            plugins_info = bundle / "PlugIns" / "DailyHealthScoreWatch.app" / "Info.plist"
            self.assertTrue(plugins_info.is_file())
            self.assertIn("Watch/ -> PlugIns/", result.stdout)

    def test_skips_non_iphone_platform(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "DailyHealthScore.app"
            bundle.mkdir()
            result = self._run(bundle, platform="watchos")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("skip", result.stdout)

    def test_fails_when_watch_app_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "DailyHealthScore.app"
            bundle.mkdir()
            result = self._run(bundle)
            self.assertEqual(result.returncode, 1)
            self.assertIn("not found", result.stderr)


class BundleIDAlignmentTests(unittest.TestCase):
    def test_watch_companion_ids_match_iphone(self) -> None:
        iphone = _plist(IOS / "DailyHealthScore" / "Info.plist")
        watch = _plist(IOS / "DailyHealthScoreWatch" / "Info.plist")
        self.assertEqual(watch["WKCompanionAppBundleIdentifier"], "com.dailyhealthscore.app.mf")
        self.assertEqual(iphone["CFBundleIdentifier"], "$(PRODUCT_BUNDLE_IDENTIFIER)")
        self.assertFalse(watch["WKWatchOnlyApp"])
        self.assertTrue(watch["WKApplication"])
        self.assertFalse(watch["WKRunsIndependentlyOfCompanionApp"])

    def test_project_yml_keeps_watch_embed_and_scheme(self) -> None:
        yml = (IOS / "project.yml").read_text()
        self.assertIn("postGenCommand: python3 scripts/patch_watch_embed.py", yml)
        self.assertIn("scripts/mirror_watch_embed.sh", yml)
        self.assertIn("DailyHealthScoreWatch:", yml)
        self.assertIn("executable: DailyHealthScoreWatch", yml)
        self.assertNotIn("Patched Embed Watch Content to PlugIns", yml)


if __name__ == "__main__":
    unittest.main()
