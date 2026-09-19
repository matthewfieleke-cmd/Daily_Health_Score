#!/bin/sh
# Dual-home the companion Watch .app after Embed Watch Content (Debug only).
#
# Xcode 27's on-device installer treats a companion Watch .app as a Foundation
# extension and looks in PlugIns/. iOS Available Apps still looks in Watch/.
# Debug copies whichever side is missing so Ultra 4 / watchOS 27 can install
# from Xcode and still appear between CVS Health and ESPN.
#
# Release and Archive keep Watch/ only. A PlugIns copy in the App Store IPA
# fails validation with "should be under Watch."
#
# Adding PlugIns/ after Xcode signs the iPhone wrapper invalidates that
# signature. watchOS then shows "Unable to Install / integrity could not be
# verified." Re-seal only the iPhone wrapper (the Watch .app keeps its own
# watchOS identity).
set -eu

WATCH_APP_NAME="DailyHealthScoreWatch.app"

if [ "${CONFIGURATION:-}" != "Debug" ]; then
  echo "mirror-watch-debug: skip (${CONFIGURATION:-unset})"
  exit 0
fi

case "${PLATFORM_NAME:-}" in
  iphoneos|iphonesimulator) ;;
  *)
    echo "mirror-watch-debug: skip (platform=${PLATFORM_NAME:-unknown})"
    exit 0
    ;;
esac

APP_BUNDLE="${TARGET_BUILD_DIR:?}/${FULL_PRODUCT_NAME:?}"
SRC_WATCH="${APP_BUNDLE}/Watch/${WATCH_APP_NAME}"
SRC_PLUGINS="${APP_BUNDLE}/PlugIns/${WATCH_APP_NAME}"

copy_tree() {
  src=$1
  dest=$2
  rm -rf "${dest}"
  mkdir -p "$(dirname "${dest}")"
  if command -v ditto >/dev/null 2>&1; then
    ditto "${src}" "${dest}"
  else
    mkdir -p "${dest}"
    cp -R "${src}/." "${dest}/"
  fi
}

reseal_iphone_wrapper() {
  identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  if [ -z "${identity}" ] || [ "${identity}" = "-" ]; then
    echo "mirror-watch-debug: skip re-sign (no identity)"
    return 0
  fi
  codesign_bin="${CODESIGN:-/usr/bin/codesign}"
  if [ ! -x "${codesign_bin}" ]; then
    echo "mirror-watch-debug: skip re-sign (no codesign)"
    return 0
  fi
  # Inside-out is Xcode's rule, but the Watch .app must keep the watchOS
  # identity. Only re-seal the iPhone wrapper so CodeResources includes PlugIns/.
  "${codesign_bin}" --force --sign "${identity}" \
    --preserve-metadata=identifier,entitlements,flags \
    --generate-entitlement-der \
    "${APP_BUNDLE}"
  echo "mirror-watch-debug: re-signed iPhone wrapper after companion layout"
}

if [ ! -d "${APP_BUNDLE}" ]; then
  echo "mirror-watch-debug: missing iPhone app bundle: ${APP_BUNDLE}" >&2
  exit 1
fi

if [ -d "${SRC_WATCH}" ] && [ -d "${SRC_PLUGINS}" ]; then
  echo "mirror-watch-debug: Watch app already in Watch/ and PlugIns/"
  reseal_iphone_wrapper
  exit 0
fi

if [ -d "${SRC_WATCH}" ]; then
  copy_tree "${SRC_WATCH}" "${SRC_PLUGINS}"
  echo "mirror-watch-debug: copied Watch/ -> PlugIns/ for device install"
  reseal_iphone_wrapper
  exit 0
fi

if [ -d "${SRC_PLUGINS}" ]; then
  copy_tree "${SRC_PLUGINS}" "${SRC_WATCH}"
  echo "mirror-watch-debug: copied PlugIns/ -> Watch/ for Available Apps"
  reseal_iphone_wrapper
  exit 0
fi

echo "mirror-watch-debug: ${WATCH_APP_NAME} not found in Watch/ or PlugIns/" >&2
ls -la "${APP_BUNDLE}" >&2 || true
exit 1
