#!/usr/bin/env python3
"""Point XcodeGen's Embed Watch Content phase at PlugIns/.

Xcode 26/27 require a companion Watch .app in PlugIns/. XcodeGen still emits
the old Watch/ destination. Keep the official phase name so iOS lists the
companion in the Watch app; only rewrite the copy destination.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PBX = Path(__file__).resolve().parent.parent / "DailyHealthScore.xcodeproj" / "project.pbxproj"
WATCH_DEST = re.compile(
    r'dstPath = "\$\(CONTENTS_FOLDER_PATH\)/Watch";\s*dstSubfolderSpec = 16;'
)
PLUGINS_DEST = 'dstPath = "";\n\t\t\tdstSubfolderSpec = 13;'


def main() -> int:
    if not PBX.exists():
        print(f"patch_watch_embed: missing {PBX}", file=sys.stderr)
        return 1
    text = PBX.read_text()
    patched, count = WATCH_DEST.subn(PLUGINS_DEST, text, count=1)
    if count == 1:
        PBX.write_text(patched)
        print("Patched Embed Watch Content to PlugIns/")
        return 0
    if 'name = "Embed Watch Content"' in text:
        print("Embed Watch Content already present; leaving destination as generated")
        return 0
    print("patch_watch_embed: Embed Watch Content phase not found", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
