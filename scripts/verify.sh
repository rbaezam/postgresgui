#!/usr/bin/env bash
#
# verify.sh — Local verification: build + tests.
#
# Used by:
#   - Developers, before committing or pushing.
#   - The optional pre-push git hook (see scripts/install-hooks.sh).
#   - GitHub Actions workflow (.github/workflows/ci.yml).
#
# Usage:
#   ./scripts/verify.sh                      # build + tests
#   ./scripts/verify.sh --build-only         # build only, skip tests
#   ./scripts/verify.sh --tests-only         # tests only, skip standalone build
#   ./scripts/verify.sh --build-for-testing  # build app + compile tests, no run
#                                            # (used in CI when the runner OS is
#                                            # older than the test target's
#                                            # MACOSX_DEPLOYMENT_TARGET)
#
# Env vars:
#   TEAM_ID   Apple Developer Team ID. Defaults to 87N6GJL5N5.
#             In CI, signing is disabled (CODE_SIGNING_ALLOWED=NO).
#   CI        When set ("true"), skips signing (set automatically by GitHub Actions).

set -euo pipefail

SCHEME="PostgresGUI"
PROJECT="PostgresGUI.xcodeproj"
DESTINATION="platform=macOS"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

RUN_BUILD=1
RUN_TESTS=1
BUILD_FOR_TESTING=0
for arg in "$@"; do
  case "$arg" in
    --build-only) RUN_TESTS=0 ;;
    --tests-only) RUN_BUILD=0 ;;
    --build-for-testing) BUILD_FOR_TESTING=1; RUN_TESTS=0 ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 64 ;;
  esac
done

# Skip signing in CI; use the user's team locally.
SIGNING_ARGS=()
if [[ "${CI:-}" == "true" ]]; then
  SIGNING_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO)
  echo "▸ CI mode: code signing disabled"
else
  TEAM_ID="${TEAM_ID:-87N6GJL5N5}"
  SIGNING_ARGS=(DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic)
  echo "▸ Local mode: signing with team $TEAM_ID"
fi

# Pretty-print: prefer xcbeautify if installed, else plain output.
if command -v xcbeautify >/dev/null 2>&1; then
  PIPE=(xcbeautify --renderer terminal --quiet)
else
  PIPE=(cat)
fi

run_xcodebuild() {
  set -o pipefail
  xcodebuild "$@" 2>&1 | "${PIPE[@]}"
}

if [[ $RUN_BUILD -eq 1 ]]; then
  echo
  echo "▸ Building $SCHEME (Debug)…"
  run_xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "$DESTINATION" \
    "${SIGNING_ARGS[@]}" \
    build
fi

if [[ $BUILD_FOR_TESTING -eq 1 ]]; then
  echo
  echo "▸ Compiling tests (build-for-testing)…"
  run_xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    "${SIGNING_ARGS[@]}" \
    build-for-testing
fi

if [[ $RUN_TESTS -eq 1 ]]; then
  echo
  echo "▸ Running tests…"
  run_xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:PostgresGUITests \
    "${SIGNING_ARGS[@]}" \
    test
fi

echo
echo "✓ verify.sh OK"
