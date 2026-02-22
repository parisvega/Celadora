# Celadora QA Combined Latest

- Generated: 2026-02-22T21:24:40Z
- Build tested: `http://127.0.0.1:8060/?v=1771795231&qa=visibility`

## Headless QA Agent (offline, repeatable)
- Runner: `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/qa/run_qa_agent.sh`
- Latest headless report: `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_latest.md`
- Latest headless JSON: `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_latest.json`
- Result: PASS (11/11)

## Browser QA (Playwright MCP evidence)
- Evidence screenshot: `/var/folders/m3/2rmjddws1jj9nm97jmjbm2kh0000gn/T/playwright-mcp-output/1771741901894/page-2026-02-22T21-21-04-378Z.png`
- Browser metrics JSON: `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_browser_latest.json`

Checks:
- PASS `world_not_black`
  - full_non_black_ratio `0.4431`
- PASS `arms_visible_in_first_person`
  - lower_center_non_black_ratio `0.9501`
  - lower_center_mean_brightness `0.5259`
- PASS `movement_changes_frame`
  - changed_ratio `0.2767`
- INCONCLUSIVE `swing_visual_change_via_browser_input`
  - changed_ratio `0.0068`
  - pointer-lock warning in automation session limits click/swing confidence.

## Conclusion
- Arms/hands/tool are now clearly visible in first-person browser preview.
- The QA agent pipeline is in place and writes reports to `/docs/reports`.
