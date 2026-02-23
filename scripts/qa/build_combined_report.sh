#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
HEADLESS_JSON="$ROOT_DIR/docs/reports/qa_latest.json"
BROWSER_JSON="$ROOT_DIR/docs/reports/qa_browser_objective_latest.json"
GOAL_MD="$ROOT_DIR/docs/reports/goals_status_latest.md"
OUT_MD="$ROOT_DIR/docs/reports/qa_combined_latest.md"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

headless_status="UNKNOWN"
headless_passed="0"
headless_total="0"

browser_status="unknown"
browser_completed="0"
browser_objectives="0"
browser_viewmodel="false"

goals_pass="0"
goals_other="0"

if command -v jq >/dev/null 2>&1 && [ -f "$HEADLESS_JSON" ]; then
	headless_total="$(jq -r '.summary.total // 0' "$HEADLESS_JSON" 2>/dev/null || echo "0")"
	headless_passed="$(jq -r '.summary.passed // 0' "$HEADLESS_JSON" 2>/dev/null || echo "0")"
	headless_failed="$(jq -r '.summary.failed // 0' "$HEADLESS_JSON" 2>/dev/null || echo "0")"
	if [ "${headless_failed:-0}" = "0" ] && [ "${headless_total:-0}" != "0" ]; then
		headless_status="PASS"
	else
		headless_status="FAIL"
	fi
fi

if command -v jq >/dev/null 2>&1 && [ -f "$BROWSER_JSON" ]; then
	browser_status="$(jq -r '.status // "unknown"' "$BROWSER_JSON" 2>/dev/null || echo "unknown")"
	browser_completed="$(jq -r '.payload.completed // 0' "$BROWSER_JSON" 2>/dev/null || echo "0")"
	browser_objectives="$(jq -r '.payload.objective_count // 0' "$BROWSER_JSON" 2>/dev/null || echo "0")"
	browser_viewmodel="$(jq -r '.viewmodel.ok // .payload.viewmodel.ok // false' "$BROWSER_JSON" 2>/dev/null || echo "false")"
fi

if [ -f "$GOAL_MD" ]; then
	goals_pass="$(grep -c '\[PASS\]' "$GOAL_MD" || true)"
	goals_other="$(grep -E -c '\[(CHECK|FAIL)\]' "$GOAL_MD" || true)"
fi

mkdir -p "$(dirname "$OUT_MD")"
cat >"$OUT_MD" <<EOF
# Celadora QA Combined Latest

- Generated: ${timestamp}

## Headless QA
- Source: \`$HEADLESS_JSON\`
- Result: ${headless_status} (${headless_passed}/${headless_total} passed)

## Browser Objective QA
- Source: \`$BROWSER_JSON\`
- Status: ${browser_status}
- Objective progression: ${browser_completed}/${browser_objectives}
- Viewmodel visible gate: ${browser_viewmodel}

## Goal Audit Snapshot
- Source: \`$GOAL_MD\`
- PASS lines: ${goals_pass}
- CHECK/FAIL lines: ${goals_other}
EOF

echo "Combined QA report written: $OUT_MD"
