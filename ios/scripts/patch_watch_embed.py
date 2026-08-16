#!/usr/bin/env python3
"""Keep XcodeGen's Embed Watch Content phase pointed at Watch/.

iOS 27 lists companion Watch apps from Watch/ inside the iPhone .app.
XcodeGen (and a previous workaround) may emit PlugIns/ instead. PlugIns is
still filled at build time by mirror_watch_embed.sh for the device installer.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PBX = Path(__file__).resolve().parent.parent / "DailyHealthScore.xcodeproj" / "project.pbxproj"
WATCH_DEST = 'dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";\n\t\t\tdstSubfolderSpec = 16;'
DEST_RE = re.compile(r'dstPath = "[^"]*";\s*dstSubfolderSpec = \d+;')
WATCH_DEST_RE = re.compile(
    r'dstPath = "\$\(CONTENTS_FOLDER_PATH\)/Watch";\s*dstSubfolderSpec = 16;'
)


def patch_text(text: str) -> tuple[str, str]:
    """Return (new_text, status) where status is 'watch', 'patched', or 'missing'."""
    marker = 'name = "Embed Watch Content"'
    idx = text.find(marker)
    if idx < 0:
        return text, "missing"

    window_start = max(0, idx - 1200)
    window = text[window_start:idx]
    if WATCH_DEST_RE.search(window):
        return text, "watch"

    new_window, count = DEST_RE.subn(WATCH_DEST, window, count=1)
    if count != 1:
        return text, "missing"
    return text[:window_start] + new_window + text[idx:], "patched"


def main() -> int:
    if not PBX.exists():
        print(f"patch_watch_embed: missing {PBX}", file=sys.stderr)
        return 1
    text = PBX.read_text()
    patched, status = patch_text(text)
    if status == "watch":
        print("Embed Watch Content already uses Watch/")
        return 0
    if status == "patched":
        PBX.write_text(patched)
        print("Restored Embed Watch Content destination to Watch/")
        return 0
    print("patch_watch_embed: Embed Watch Content phase not found", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
