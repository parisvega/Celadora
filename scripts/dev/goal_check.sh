#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

QA_JSON="$ROOT_DIR/docs/reports/qa_latest.json"
QA_BROWSER_OBJECTIVE_JSON="$ROOT_DIR/docs/reports/qa_browser_objective_latest.json"
REPORT_MD="$ROOT_DIR/docs/reports/goals_status_latest.md"

if [ ! -f "$QA_JSON" ]; then
  echo "qa_latest.json not found; running QA agent first..."
  scripts/qa/run_qa_agent.sh
fi

status_mark() {
  if [ "$1" = "true" ]; then
    printf "PASS"
  else
    printf "CHECK"
  fi
}

moon_count_ok="$(jq -r 'length == 8' data/moons.json)"
dust_count_ok="$(jq -r '[.[] | select(.id|startswith("dust_"))] | length == 8' data/items.json)"
required_location_ok="$(jq -r 'map(.id) | (index("enoks_kingdom_ridge") != null and index("makunas_shore") != null and index("greegion_ruins") != null)' data/locations.json)"
qa_all_pass="$(jq -r '.summary.failed == 0' "$QA_JSON")"
terminal_flow_pass="$(jq -r '[.checks[] | select(.id=="ruins_terminal_can_be_primed")][0].ok // false' "$QA_JSON")"
world_state_pass="$(jq -r '[.checks[] | select(.id=="save_load_world_flag_roundtrip")][0].ok // false' "$QA_JSON")"
dust_identity_pass="$(jq -r '([.checks[] | select(.id=="dust_colors_match_moons")][0].ok // false) and ([.checks[] | select(.id=="dust_shapes_are_unique")][0].ok // false) and ([.checks[] | select(.id=="dust_glow_spectrum_full_range")][0].ok // false)' "$QA_JSON")"
browser_objective_pass="false"
if [ -f "$QA_BROWSER_OBJECTIVE_JSON" ]; then
  browser_objective_pass="$(jq -r '.ok == true and (.payload.ok == true)' "$QA_BROWSER_OBJECTIVE_JSON")"
fi

cat > "$REPORT_MD" <<EOF
# Celadora v0.1 Goal Status

- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- QA source: \`docs/reports/qa_latest.json\`

## Non-Negotiable Goals
- [$(status_mark "$qa_all_pass")] Playable vertical slice stability gate (headless QA all checks).
- [$(status_mark "$moon_count_ok")] Eight moons defined in data.
- [$(status_mark "$dust_count_ok")] Eight moon dust types defined in data.
- [$(status_mark "$dust_identity_pass")] Moon-dust identity (moon color + unique shape + glow spectrum) validated.
- [$(status_mark "$required_location_ok")] Required lore locations present.
- [$(status_mark "$terminal_flow_pass")] Ruins terminal boss-hook progression can be primed in runtime.
- [$(status_mark "$world_state_pass")] World-state progression survives save/load.
- [$(status_mark "$browser_objective_pass")] Browser objective-flow automation verifies full objective completion path.

## Notes
- \`PASS\` indicates automated verification is in place and currently passing.
- \`CHECK\` indicates the goal may still be met but needs additional implementation or new automated coverage.
EOF

echo "Goal report written: $REPORT_MD"
