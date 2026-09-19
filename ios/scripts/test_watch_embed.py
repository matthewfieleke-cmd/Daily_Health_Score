#!/usr/bin/env python3
"""Tests for Watch companion embed helpers."""
from __future__ import annotations

import plistlib
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
IOS = SCRIPTS.parent
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


class BundleIDAlignmentTests(unittest.TestCase):
    def test_watch_companion_ids_match_iphone(self) -> None:
        iphone = _plist(IOS / "DailyHealthScore" / "Info.plist")
        watch = _plist(IOS / "DailyHealthScoreWatch" / "Info.plist")
        self.assertEqual(watch["WKCompanionAppBundleIdentifier"], "com.dailyhealthscore.app.mf")
        self.assertEqual(iphone["CFBundleIdentifier"], "$(PRODUCT_BUNDLE_IDENTIFIER)")
        self.assertFalse(watch["WKWatchOnlyApp"])
        self.assertTrue(watch["WKApplication"])
        self.assertFalse(watch["WKRunsIndependentlyOfCompanionApp"])

    def test_project_yml_pins_watch_folder_and_debug_plugins_mirror(self) -> None:
        yml = (IOS / "project.yml").read_text()
        self.assertIn("postGenCommand: python3 scripts/patch_watch_embed.py", yml)
        self.assertIn("mirror_watch_for_debug_install.sh", yml)
        self.assertIn("ARCHS: arm64", yml)
        self.assertIn("ONLY_ACTIVE_ARCH: NO", yml)
        self.assertNotIn("relocate_watch_for_debug_install", yml)
        self.assertNotIn("mirror_watch_embed.sh", yml)
        self.assertNotIn("outputFiles:", yml)
        self.assertIn("executable: DailyHealthScoreWatch", yml)
        self.assertIn('CURRENT_PROJECT_VERSION: "13"', yml)


class DebugWatchMirrorTests(unittest.TestCase):
    def _run(self, env: dict) -> None:
        import subprocess

        subprocess.check_call(
            ["sh", str(SCRIPTS / "mirror_watch_for_debug_install.sh")],
            env=env,
        )

    def test_debug_copies_watch_into_plugins(self) -> None:
        import os
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            products = Path(tmp)
            contents = products / "DailyHealthScore.app"
            watch_app = contents / "Watch" / "DailyHealthScoreWatch.app"
            watch_app.mkdir(parents=True)
            (watch_app / "Info.plist").write_text("placeholder", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                {
                    "CONFIGURATION": "Debug",
                    "PLATFORM_NAME": "iphoneos",
                    "TARGET_BUILD_DIR": str(products),
                    "FULL_PRODUCT_NAME": "DailyHealthScore.app",
                }
            )
            self._run(env)
            plugin_app = contents / "PlugIns" / "DailyHealthScoreWatch.app"
            self.assertTrue(plugin_app.is_dir())
            self.assertTrue((plugin_app / "Info.plist").is_file())
            self.assertTrue(watch_app.is_dir())

    def test_debug_copies_plugins_into_watch(self) -> None:
        import os
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            products = Path(tmp)
            contents = products / "DailyHealthScore.app"
            plugin_app = contents / "PlugIns" / "DailyHealthScoreWatch.app"
            plugin_app.mkdir(parents=True)
            (plugin_app / "Info.plist").write_text("placeholder", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                {
                    "CONFIGURATION": "Debug",
                    "PLATFORM_NAME": "iphoneos",
                    "TARGET_BUILD_DIR": str(products),
                    "FULL_PRODUCT_NAME": "DailyHealthScore.app",
                }
            )
            self._run(env)
            watch_app = contents / "Watch" / "DailyHealthScoreWatch.app"
            self.assertTrue(watch_app.is_dir())
            self.assertTrue((watch_app / "Info.plist").is_file())
            self.assertTrue(plugin_app.is_dir())

    def test_release_leaves_watch_folder(self) -> None:
        import os
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            products = Path(tmp)
            contents = products / "DailyHealthScore.app"
            watch_app = contents / "Watch" / "DailyHealthScoreWatch.app"
            watch_app.mkdir(parents=True)
            env = os.environ.copy()
            env.update(
                {
                    "CONFIGURATION": "Release",
                    "PLATFORM_NAME": "iphoneos",
                    "TARGET_BUILD_DIR": str(products),
                    "FULL_PRODUCT_NAME": "DailyHealthScore.app",
                }
            )
            self._run(env)
            self.assertTrue(watch_app.is_dir())
            self.assertFalse((contents / "PlugIns").exists())


if __name__ == "__main__":
    unittest.main()
