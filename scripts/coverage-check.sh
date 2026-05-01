#!/usr/bin/env bash
set -euo pipefail

THRESHOLD="${1:-80}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/ios-app/build/DerivedData/Simulator"

XCRESULT=$(find "$DERIVED_DATA" -name "*.xcresult" -maxdepth 5 2>/dev/null | sort -r | head -1)

if [[ -z "$XCRESULT" ]]; then
    echo "Error: No .xcresult bundle found in $DERIVED_DATA"
    echo "Run 'bun run ios:test' first to generate coverage data."
    exit 1
fi

COVERAGE_JSON=$(xcrun xccov view --report --json "$XCRESULT" 2>/dev/null)

if [[ -z "$COVERAGE_JSON" ]]; then
    echo "Error: Could not extract coverage data from $XCRESULT"
    exit 1
fi

LINE_COVERAGE=$(echo "$COVERAGE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
exclude_prefixes = [
    'OpenCodeNexus/OpenCodeNexusApp.swift',
    'OpenCodeNexus/RootView.swift',
    'OpenCodeNexus/Services/GhosttyTerminalSession.swift',
    'OpenCodeNexus/Services/PtyTransport.swift',
    'SourcePackages/checkouts/libghostty-spm/',
    'OpenCodeNexusTests/',
    'Views/ChatView.swift',
    'Views/ConnectView.swift',
    'Views/MessageInputView.swift',
    'Views/NewSessionView.swift',
    'Views/PermissionSheet.swift',
    'Views/QuestionSheet.swift',
    'Views/DiffSheet.swift',
    'Views/FileBrowserView.swift',
    'Views/FileViewerView.swift',
    'Views/ServerEditView.swift',
    'Views/Terminal/TerminalView.swift',
    'Views/ModelAgentPicker.swift',
]
total_lines = 0
covered_lines = 0
for target in data.get('targets', []):
    for file_data in target.get('files', []):
        path = file_data.get('path', '')
        if any(ex in path for ex in exclude_prefixes):
            continue
        total_lines += file_data.get('executableLines', 0)
        covered_lines += file_data.get('coveredLines', 0)
if total_lines == 0:
    print('0.0')
else:
    pct = (covered_lines / total_lines) * 100
    print(f'{pct:.1f}')
")

echo "Line coverage: ${LINE_COVERAGE}% (threshold: ${THRESHOLD}%)"
echo ""

echo "Files below 80% coverage:"
echo "$COVERAGE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
exclude = ['OpenCodeNexusApp.swift', 'RootView.swift', 'GhosttyTerminalSession.swift', 'PtyTransport.swift', 'SourcePackages/checkouts/', 'OpenCodeNexusTests/', 'ChatView.swift', 'ConnectView.swift', 'MessageInputView.swift', 'NewSessionView.swift', 'PermissionSheet.swift', 'QuestionSheet.swift', 'DiffSheet.swift', 'FileBrowserView.swift', 'FileViewerView.swift', 'ServerEditView.swift', 'TerminalView.swift', 'ModelAgentPicker.swift']
found = False
for target in data.get('targets', []):
    for f in target.get('files', []):
        path = f.get('path', '')
        if any(ex in path for ex in exclude):
            continue
        total = f.get('executableLines', 0)
        covered = f.get('coveredLines', 0)
        if total > 0:
            pct = (covered / total) * 100
            if pct < 80:
                found = True
                short = path.split('OpenCodeNexus/')[-1] if 'OpenCodeNexus/' in path else path
                print(f'  {short}: {pct:.1f}% ({covered}/{total})')
if not found:
    print('  None - all files at or above 80%')
"

if (( $(echo "$LINE_COVERAGE >= $THRESHOLD" | bc -l) )); then
    echo ""
    echo "PASS: Coverage meets ${THRESHOLD}% threshold."
    exit 0
else
    echo ""
    echo "FAIL: Coverage ${LINE_COVERAGE}% is below ${THRESHOLD}% threshold."
    exit 1
fi
