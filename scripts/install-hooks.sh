#!/usr/bin/env bash
#
# install-hooks.sh — Installs optional git hooks for this repo.
#
# Currently:
#   pre-push  Runs scripts/verify.sh before every `git push`. If any test
#             fails or the build breaks, the push is aborted.
#
# Usage:
#   ./scripts/install-hooks.sh           # install
#   ./scripts/install-hooks.sh uninstall # remove the hook
#
# Skip the hook for a one-off push with `git push --no-verify`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_PATH="$ROOT_DIR/.git/hooks/pre-push"

[[ -d "$ROOT_DIR/.git" ]] || { echo "not in a git repo: $ROOT_DIR"; exit 1; }

case "${1:-install}" in
  uninstall)
    rm -f "$HOOK_PATH"
    echo "✓ removed pre-push hook"
    ;;
  install)
    cat > "$HOOK_PATH" <<'HOOK'
#!/usr/bin/env bash
# Installed by scripts/install-hooks.sh — runs verify.sh before push.
# Skip with: git push --no-verify
set -e
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/scripts/verify.sh"
HOOK
    chmod +x "$HOOK_PATH"
    echo "✓ pre-push hook installed at $HOOK_PATH"
    echo "  Skip a single push with: git push --no-verify"
    ;;
  *)
    echo "unknown arg: $1" >&2
    exit 64
    ;;
esac
