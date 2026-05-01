#!/usr/bin/env bash
set -euo pipefail

HOOK_PATH="$(git rev-parse --git-dir)/hooks/pre-commit"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

cat > "$HOOK_PATH" << HOOK
#!/usr/bin/env bash
set -euo pipefail

SWIFT_CHANGED=\$(git diff --cached --name-only --diff-filter=ACMR | grep -c '\.swift\$' || true)
if [[ "\$SWIFT_CHANGED" -eq 0 ]]; then
    exit 0
fi

echo "Swift files changed — running tests with coverage..."
cd "$PROJECT_ROOT"
bun run ios:test 2>&1 | tail -5

echo ""
bash "$PROJECT_ROOT/scripts/coverage-check.sh" 80
HOOK

chmod +x "$HOOK_PATH"
echo "Installed pre-commit hook to $HOOK_PATH"
