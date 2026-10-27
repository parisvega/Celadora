# Project working instructions

<!-- BEGIN CLOUD-FIRST-WORKFLOW -->
## Cloud-first work and GitHub teamwork

Treat Paris's laptop as a place to coordinate, review and make small edits, not the default place for heavy work. Keep work quality high while limiting local storage, memory and CPU use. These rules do not weaken existing safety, privacy, ownership or approval rules; follow the stricter rule.

### Choose where to work

- Before substantial work, confirm where commands will run. Prefer an existing approved cloud workspace or remote development server with suitable access and capacity.
- Run dependency installs, builds, large tests, crawls, data processing and rendering remotely where supported. Use cloud documents and connected services directly; avoid large downloads and duplicate local copies without a clear need.
- Use Codex Cloud, Claude, Cursor or other services only when their actual tools, access, privacy rules and approved budget fit the task. A cloud model does not mean its commands run remotely.
- If remote execution is unavailable, explain the smallest setup or handoff needed. Continue safe light work, but do not silently fall back to heavy laptop work.
- Do not move overload to a production server. Prefer a separate development host. A folder or container on a production machine is not enough protection by itself.

### Use GitHub for team development

- Use the canonical repository and existing project task records. Check current work and pull requests before starting; do not duplicate an owned task.
- Give each implementation task one owner, a clear scope, its own working branch and an isolated workspace, preferably remote. Never let agents or developers write in the same checkout or branch at the same time.
- Coordinate overlapping files and shared interfaces. Keep existing repository, client, data and runtime ownership boundaries.
- Use pull requests, review and remote CI checks for integration. Follow existing approval rules for commits, pushes, PRs, merges and deployments; do not infer those permissions from a request for local edits or review. Check for deployment or other side effects before triggering workflows.
- Keep useful work and handoff notes in approved durable storage, not only in a chat or temporary workspace. Do not upload private files or publish code just to make a handoff easier.

### Protect local and remote resources

- Reuse suitable task resources without borrowing another writer's checkout. Do not create worktrees, clones, dependency copies, containers or background services for simple questions, reviews or instruction-only edits.
- Across projects, default to at most one heavy local job at a time. Check existing activity before adding more; queue or offload other work.
- Before heavy local work, check free disk space and memory pressure. Aim to keep at least 20 GB free. If resources are tight, offload or queue the work instead of adding load.
- Give temporary resources a task owner and an end condition. At handoff, record what remains, its owner and why it is retained. Use existing task records; do not create large inventories for small tasks.
- Preserve source, settings, logs, recordings, databases, unique files and recovery evidence. Do not delete system swap, clear caches blindly, stop shared processes or restart the computer as a routine workaround. Cleanup and process shutdown must follow existing approval rules.

### Keep safety and quality

- Cloud-first does not grant permission to upload private data, expose credentials, add spending, change access, deploy or modify production. Use approved destinations, least-privilege access and existing budgets.
- Keep required tests and reviews. Run them in a suitable approved environment; clearly report verification that could not run. Never claim skipped checks passed.
- At handoff, state where work ran, link the results, and identify resources still running or retained. Distinguish local edits, GitHub publication and live releases.
<!-- END CLOUD-FIRST-WORKFLOW -->
