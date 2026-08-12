#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuietDeck"
PRODUCT_NAME="Cove"
BUNDLE_ID="com.astralworkslabs.QuietDeck"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PLIST="$ROOT_DIR/Sources/QuietDeck/Support/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Sources/QuietDeck/Support/Cove.entitlements"
OUTPUT_DIR="$ROOT_DIR/outputs"
NOTARY_PROFILE="${COVE_NOTARY_PROFILE:-CoveNotary}"
TEAM_ID="${COVE_TEAM_ID:-XKW9265RG8}"
SKIP_NOTARY_SUBMIT="${COVE_SKIP_NOTARY_SUBMIT:-0}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_PLIST")"
OUTPUT_ARCHIVE="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION.app.zip"

DEVELOPER_ID_IDENTITY="${COVE_DEVELOPER_ID_IDENTITY:-}"
if [[ -z "$DEVELOPER_ID_IDENTITY" ]]; then
  DEVELOPER_ID_IDENTITY="$({
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null || true
  } | /usr/bin/sed -n "s/.*\"\(Developer ID Application:.*($TEAM_ID)\)\".*/\1/p" | /usr/bin/head -n 1)"
fi
if [[ -z "$DEVELOPER_ID_IDENTITY" ]]; then
  echo "No Developer ID Application identity found for team $TEAM_ID." >&2
  exit 1
fi

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cove-notarize.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT
STAGED_APP="$STAGING_ROOT/$APP_NAME.app"
STAGED_CONTENTS="$STAGED_APP/Contents"
STAGED_MACOS="$STAGED_CONTENTS/MacOS"
SUBMISSION_ARCHIVE="$STAGING_ROOT/$PRODUCT_NAME-$VERSION-submission.zip"
VERIFY_ROOT="$STAGING_ROOT/verify"

cd "$ROOT_DIR"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

mkdir -p "$STAGED_MACOS" "$OUTPUT_DIR" "$VERIFY_ROOT"
cp "$BUILD_BINARY" "$STAGED_MACOS/$APP_NAME"
cp "$SOURCE_PLIST" "$STAGED_CONTENTS/Info.plist"
chmod +x "$STAGED_MACOS/$APP_NAME"
/usr/bin/xattr -cr "$STAGED_APP"

sign_app() {
  /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=http://timestamp.apple.com/ts01 \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$STAGED_APP" &
  local sign_pid=$!
  for _ in {1..60}; do
    if ! kill -0 "$sign_pid" 2>/dev/null; then
      wait "$sign_pid"
      return $?
    fi
    sleep 1
  done
  kill "$sign_pid" 2>/dev/null || true
  wait "$sign_pid" 2>/dev/null || true
  return 124
}

signed=0
for attempt in 1 2 3; do
  if sign_app; then
    signed=1
    break
  fi
  if [[ "$attempt" -lt 3 ]]; then
    echo "Secure timestamp signing attempt $attempt failed; retrying..." >&2
    /usr/bin/xattr -cr "$STAGED_APP"
    sleep $((attempt * 3))
  fi
done
if [[ "$signed" != "1" ]]; then
  echo "Developer ID signing could not obtain an Apple secure timestamp." >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
/usr/bin/ditto --norsrc -c -k --keepParent "$STAGED_APP" "$SUBMISSION_ARCHIVE"

if [[ "$SKIP_NOTARY_SUBMIT" != "1" ]]; then
  /usr/bin/xcrun notarytool submit "$SUBMISSION_ARCHIVE" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
fi

stapled=0
for attempt in 1 2 3 4 5; do
  if /usr/bin/xcrun stapler staple "$STAGED_APP"; then
    stapled=1
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    echo "Stapling attempt $attempt failed; retrying Apple ticket delivery..." >&2
    sleep $((attempt * 5))
  fi
done
if [[ "$stapled" != "1" ]]; then
  echo "Apple accepted the app, but its notarization ticket could not be stapled." >&2
  exit 1
fi

/usr/bin/xcrun stapler validate "$STAGED_APP"
/usr/sbin/spctl --assess --type execute --verbose=4 "$STAGED_APP"

/usr/bin/ditto --norsrc -c -k --keepParent "$STAGED_APP" "$OUTPUT_ARCHIVE"
/usr/bin/ditto -x -k "$OUTPUT_ARCHIVE" "$VERIFY_ROOT"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFY_ROOT/$APP_NAME.app"
/usr/bin/xcrun stapler validate "$VERIFY_ROOT/$APP_NAME.app"
/usr/sbin/spctl --assess --type execute --verbose=4 "$VERIFY_ROOT/$APP_NAME.app"

echo "Notarized Cove release: $OUTPUT_ARCHIVE"
