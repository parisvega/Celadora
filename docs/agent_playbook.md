# Celadora UX/DX/AX Playbook

This playbook is optimized for human developers and AI agents collaborating on rapid iterations.

## UX Priorities (Player-facing)
1. World is visible and controllable within 5 seconds of load.
2. HUD always communicates objectives, world status, controls, and interaction target.
3. Recovery path exists for broken local state (`F9` reset progress).
4. Core loop remains clear: mine -> collect -> craft -> fight -> explore markers.

## DX Priorities (Builder-facing)
1. One-command Web export.
2. One-command local preview server start/stop.
3. One-command smoke validation before sharing a build.
4. Stable service seams: gameplay features should route through `GameServices`.

## AX Priorities (Agent-facing)
1. Make minimal, scoped edits and run smoke checks after each batch.
2. Prefer data-driven changes in `/data` for balancing.
3. Preserve interface contracts in `/scripts/services`.
4. Use this checklist for each PR/iteration.

## Agent Iteration Checklist
- [ ] Run `scripts/dev/smoke_check.sh`
- [ ] If gameplay/UI changed, run `scripts/dev/export_web.sh`
- [ ] Start preview with `scripts/dev/run_web_preview.sh 8060`
- [ ] Verify objective row + world status target + interaction hint + world visibility in browser
- [ ] Verify objective checklist panel (`O`) and target HP/integrity status near crosshair
- [ ] Verify Dream status transitions (`Dormant` -> `ETA`/`Present`) and seed drop loop at night
- [ ] Verify compass bearings + marker beacon visibility + debug overlay (`F3`)
- [ ] Verify dev time skip (`F8`) and event log count updates in debug overlay
- [ ] Update docs/README if behavior or controls changed

## Fast Commands
- Full preview loop:
  - `scripts/dev/quick_preview.sh 8060`
- Export Web:
  - `scripts/dev/export_web.sh`
- Run preview:
  - `scripts/dev/run_web_preview.sh 8060`
- Stop preview:
  - `scripts/dev/stop_web_preview.sh`
- Smoke check:
  - `scripts/dev/smoke_check.sh`

## Current UX Safety Nets
- Web renderer compatibility mode for browser stability.
- Safe spawn correction on load.
- Local progress reset hotkey (`F9`).
- Bottom HUD objective/status strips and contextual interaction hint.

## Current DX Safety Nets
- Runtime JSON contract validation via `DataService`.
- `scripts/dev/smoke_check.sh` guards required IDs + scene/script references.
