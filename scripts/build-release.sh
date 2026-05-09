#!/usr/bin/env bash
#
# build-release.sh — Reproducible Release build of PostgresGUI.
#
# Produces a signed .app at:
#   build/export/PostgresGUI.app
#
# Usage:
#   ./scripts/build-release.sh                # build only
#   ./scripts/build-release.sh --install      # build + copy to /Applications
#   ./scripts/build-release.sh --open         # build + reveal .app in Finder
#   TEAM_ID=ABCDE12345 ./scripts/build-release.sh
#
# Env vars:
#   TEAM_ID  Apple Developer Team ID used for code signing. Defaults to the
#            Personal Team configured for this machine.

set -euo pipefail

# ---------- config ----------
TEAM_ID="${TEAM_ID:-87N6GJL5N5}"
SCHEME="PostgresGUI"
PROJECT="PostgresGUI.xcodeproj"
CONFIG="Release"

# Resolve repo root (the directory above this script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/PostgresGUI.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
APP_PATH="$EXPORT_DIR/PostgresGUI.app"

INSTALL=0
REVEAL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --open|--reveal) REVEAL=1 ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 64
      ;;
  esac
done

# ---------- preflight ----------
command -v xcodebuild >/dev/null || { echo "xcodebuild not found"; exit 1; }
[[ -d "$PROJECT" ]] || { echo "$PROJECT not found in $ROOT_DIR"; exit 1; }

echo "▸ Team ID:        $TEAM_ID"
echo "▸ Scheme:         $SCHEME"
echo "▸ Configuration:  $CONFIG"
echo "▸ Output:         $APP_PATH"
echo

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ---------- export options plist (generated, never committed) ----------
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>mac-application</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

# ---------- archive ----------
echo "▸ Archiving…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  archive

# ---------- export ----------
echo "▸ Exporting…"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

[[ -d "$APP_PATH" ]] || { echo "expected $APP_PATH but it was not produced"; exit 1; }

# ---------- post ----------
echo
echo "✓ Built: $APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/  /' || true

if [[ $INSTALL -eq 1 ]]; then
  echo
  echo "▸ Installing to /Applications…"
  rm -rf "/Applications/PostgresGUI.app"
  cp -R "$APP_PATH" "/Applications/PostgresGUI.app"
  echo "✓ Installed: /Applications/PostgresGUI.app"
fi

if [[ $REVEAL -eq 1 ]]; then
  open -R "$APP_PATH"
fi
