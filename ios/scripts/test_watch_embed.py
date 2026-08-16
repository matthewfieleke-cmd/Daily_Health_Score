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

    def test_project_yml_uses_watch_folder_only(self) -> None:
        yml = (IOS / "project.yml").read_text()
        self.assertIn("postGenCommand: python3 scripts/patch_watch_embed.py", yml)
        self.assertNotIn("mirror_watch_embed", yml)
        self.assertNotIn("postBuildScripts:", yml)
        self.assertIn("executable: DailyHealthScoreWatch", yml)


if __name__ == "__main__":
    unittest.main()
