#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="QuietDeck"
PRODUCT_NAME="Cove"
BUNDLE_ID="com.astralworkslabs.QuietDeck"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_ARCHIVE="$DIST_DIR/$APP_NAME.app.zip"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
SOURCE_PLIST="$ROOT_DIR/Sources/QuietDeck/Support/Info.plist"
SOURCE_ICON="$ROOT_DIR/Sources/QuietDeck/Support/CoveIcon.icns"
SIGNING_IDENTITY="${QUIET_DECK_SIGNING_IDENTITY:-}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..40}; do
  if ! pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.05
done
if pgrep -x "$APP_NAME" >/dev/null; then
  echo "Cove did not stop cleanly. Quit it from the menu bar and try again." >&2
  exit 1
fi

cd "$ROOT_DIR"
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quietdeck-stage.XXXXXX")"
ARCHIVE_VERIFY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quietdeck-archive-verify.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT" "$ARCHIVE_VERIFY_ROOT"' EXIT
STAGED_APP_BUNDLE="$STAGING_ROOT/$APP_NAME.app"
STAGED_APP_CONTENTS="$STAGED_APP_BUNDLE/Contents"
STAGED_APP_MACOS="$STAGED_APP_CONTENTS/MacOS"
STAGED_APP_RESOURCES="$STAGED_APP_CONTENTS/Resources"
STAGED_APP_BINARY="$STAGED_APP_MACOS/$APP_NAME"

mkdir -p "$STAGED_APP_MACOS" "$STAGED_APP_RESOURCES"
cp "$BUILD_BINARY" "$STAGED_APP_BINARY"
cp "$SOURCE_PLIST" "$STAGED_APP_CONTENTS/Info.plist"
cp "$SOURCE_ICON" "$STAGED_APP_RESOURCES/CoveIcon.icns"
chmod +x "$STAGED_APP_BINARY"
/usr/bin/xattr -cr "$STAGED_APP_BUNDLE"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$({
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null || true
  } | /usr/bin/sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | /usr/bin/head -n 1)"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="-"
fi

/usr/bin/codesign \
  --force \
  --deep \
  --sign "$SIGNING_IDENTITY" \
  --identifier "$BUNDLE_ID" \
  --timestamp=none \
  "$STAGED_APP_BUNDLE" >/dev/null
/usr/bin/codesign --verify --deep --strict "$STAGED_APP_BUNDLE"

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE"
/usr/bin/ditto --norsrc "$STAGED_APP_BUNDLE" "$APP_BUNDLE"
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
rm -f "$APP_ARCHIVE"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP_BUNDLE" "$APP_ARCHIVE"
/usr/bin/ditto -x -k "$APP_ARCHIVE" "$ARCHIVE_VERIFY_ROOT"
/usr/bin/codesign --verify --deep --strict "$ARCHIVE_VERIFY_ROOT/$APP_NAME.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$APP_BUNDLE" >/dev/null 2>&1 || true
echo "Signed Cove with: $SIGNING_IDENTITY"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --preview|preview)
    /usr/bin/open -n "$APP_BUNDLE" --args --preview
    ;;
  --request-access|request-access)
    /usr/bin/open -n "$APP_BUNDLE" --args --request-access
    ;;
  --request-screen-recording|request-screen-recording)
    /usr/bin/open -n "$APP_BUNDLE" --args --request-screen-recording
    ;;
  --diagnose-menu-items|diagnose-menu-items)
    /usr/bin/open -n "$APP_BUNDLE" --args --diagnose-menu-items
    ;;
  --show-menu-items|show-menu-items)
    /usr/bin/open -n "$APP_BUNDLE" --args --show-menu-items
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    PROCESS_COUNT="$(pgrep -x "$APP_NAME" | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
    [[ "$PROCESS_COUNT" == "1" ]]
    ;;
  *)
    echo "usage: $0 [run|--preview|--request-access|--request-screen-recording|--diagnose-menu-items|--show-menu-items|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
