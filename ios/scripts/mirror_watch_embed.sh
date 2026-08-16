#!/bin/sh
# Dual-home the companion Watch .app after it is embedded.
#
# Xcode 26/27 may copy it to PlugIns/ (device-install validator treats it as a
# Foundation extension). iOS 27 still lists companions for Available Apps from
# Watch/. Keep both so Run-on-iPhone can install and the Watch app can appear.
set -eu

WATCH_APP_NAME="DailyHealthScoreWatch.app"

case "${PLATFORM_NAME:-}" in
  iphoneos|iphonesimulator) ;;
  *)
    echo "mirror_watch_embed: skip (platform=${PLATFORM_NAME:-unknown})"
    exit 0
    ;;
esac

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FULL_PRODUCT_NAME:-}" ]; then
  echo "mirror_watch_embed: TARGET_BUILD_DIR and FULL_PRODUCT_NAME must be set" >&2
  exit 1
fi

APP_BUNDLE="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
SRC_WATCH="${APP_BUNDLE}/Watch/${WATCH_APP_NAME}"
SRC_PLUGINS="${APP_BUNDLE}/PlugIns/${WATCH_APP_NAME}"

copy_tree() {
  src=$1
  dest=$2
  rm -rf "$dest"
  if command -v ditto >/dev/null 2>&1; then
    ditto "$src" "$dest"
  else
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
  fi
}

if [ ! -d "$APP_BUNDLE" ]; then
  echo "mirror_watch_embed: missing iPhone app bundle: $APP_BUNDLE" >&2
  exit 1
fi

if [ -d "$SRC_WATCH" ] && [ -d "$SRC_PLUGINS" ]; then
  echo "mirror_watch_embed: Watch app already in Watch/ and PlugIns/"
  exit 0
fi

if [ -d "$SRC_WATCH" ]; then
  mkdir -p "${APP_BUNDLE}/PlugIns"
  copy_tree "$SRC_WATCH" "$SRC_PLUGINS"
  echo "mirror_watch_embed: copied Watch/ -> PlugIns/"
  exit 0
fi

if [ -d "$SRC_PLUGINS" ]; then
  mkdir -p "${APP_BUNDLE}/Watch"
  copy_tree "$SRC_PLUGINS" "$SRC_WATCH"
  echo "mirror_watch_embed: copied PlugIns/ -> Watch/"
  exit 0
fi

echo "mirror_watch_embed: ${WATCH_APP_NAME} not found in Watch/ or PlugIns/" >&2
ls -la "$APP_BUNDLE" >&2 || true
exit 1
