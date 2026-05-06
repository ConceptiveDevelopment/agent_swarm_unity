# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [2.0.1] - 2026-04-17

### Added
- `po-notifier.sh` — proactively reports session progress to PO when tasks close. Checks GitLab directly as source of truth (not just status.json).
- `docs-update` skill — update README, CHANGELOG, and API docs after feature merges
- `project-hygiene` skill published to code-assistant-skills group
- Engineer done file now includes `## Documentation Impact:` section
- Orchestrator triggers docs check after every 3 merges
- PO checks documentation staleness before session landing
- Orchestrator notifies PO on auto-accepted issues (was silently closing)
- PO handles `auto-accepted` task type

### Fixed
- Init messages sent inside `accept_trust()` — guaranteed after trust dialog clears
- Background init process survived launcher shell exit with `disown`
- `po-notifier.sh` queries GitLab directly instead of relying on stale status.json

## [2.0.0] - 2026-04-16

### Added
- **Native kiro-cli hooks** — 7 event-driven hooks replacing poll-based harness scripts:
  - `agent-startup.sh` (agentSpawn) — injects project context on agent initialization
  - `boundary-check.sh` (preToolUse) — **blocks** file access outside project directory
  - `validate-before-done.sh` (preToolUse) — **blocks** invalid done file writes (unpushed branch, hedging language, missing sections)
  - `task-scope-check.sh` (preToolUse) — **blocks** engineer writes to files not in task assignment
  - `drift-check-hook.sh` (stop) — injects task reminder when response drifts from assignment
  - `post-progress.sh` (stop) — posts engineer progress to GitLab issue after each turn
  - `gitlab-audit.sh` (stop) — reminds orchestrator to update GitLab on state changes
- Hooks field added to all 5 agent JSON configs
- `.kiro/scripts/hooks/` directory for all hook scripts
- "Ask Kiro to install it" section in README for AI-assisted setup
- Full file structure tree in README
- Configuration reference with required fields

### Changed
- **BREAKING:** Harness architecture — poll-based guards replaced by native event-driven hooks
- `watcher-supervisor.sh` reduced from 6 processes to 3 (watch-done, monitor, heartbeat)
- `swarm.sh` — removed init message hack (replaced by agentSpawn hook)
- README completely rewritten with hooks documentation, GitLab integration, and installation guide

### Removed
- `boundary-guard.sh` — replaced by `boundary-check.sh` preToolUse hook (archived)
- `drift-check.sh` — replaced by `drift-check-hook.sh` stop hook (archived)
- `progress-report.sh` — replaced by `post-progress.sh` stop hook (archived)
- Init message hack from `swarm.sh` — replaced by agentSpawn hook

## [1.3.0] - 2026-04-15

### Added
- **Harness hooks** — 7 reliability monitors running via `watcher-supervisor.sh`:
  - `heartbeat.sh` — detects stuck/dead agents, auto-nudges after 5min stale
  - `validate-done.sh` — evidence gate on done files (verifies push, checks hedging language)
  - `drift-check.sh` — compares agent output vs task keywords, re-anchors drifting agents
  - `boundary-guard.sh` — detects file access outside project directory
  - `audit-protocol.sh` — checks status.json consistency, agent/task alignment
  - `progress-report.sh` — posts engineer progress to GitLab every 10min
  - `watcher-supervisor.sh` — restarts crashed harness scripts with 5s backoff
- **GitLab-as-source-of-truth integration**:
  - Orchestrator rebuilds status.json from GitLab on startup (survives restarts)
  - Orchestrator posts progress comments on task assignment
  - Orchestrator posts architect briefs as GitLab issue comments
  - Engineers post "work started" comment on GitLab issue
  - Swarm state labels: `swarm::in-progress`, `swarm::qa-review`, `swarm::acceptance-review`
  - PO posts session summary as GitLab issue on landing
  - `compact-memory.sh` syncs memory to GitLab snippet after compaction
- **Multi-swarm isolation** — window names prefixed with `gitlab_project_id`, `panes.json` manifest, session-safe script routing via `swarm-env.sh`
- **New layout** — COMMAND window (PO left 2/3 + Monitor right 1/3), DEVELOPERS window (2x2 grid), max 4 devs
- `kill-swarm.sh` — project-scoped swarm teardown by pane ID
- `worktree-branch` skill — engineers create worktrees instead of checking out branches
- All agents auto-orient on startup (read config, status, memory, pending tasks)
- Auto-accept trust-all-tools confirmation dialog on launch
- Auto-send init message to trigger agent STARTUP sequences
- `dashboard.sh` — width-adaptive, shows orchestrator status peek + GitLab backlog

### Changed
- `watch-done.sh` — validates done files before notifying orchestrator, auto-compacts memory every 5 tasks, re-anchors orchestrator every 3 tasks
- `monitor.sh` — 60s startup grace period (doesn't exit before agent windows exist)
- Engineer prompt: must use worktree-branch skill, never checkout in main worktree
- Max developers reduced from 5 to 4 (fits 2x2 grid)
- `swarm.sh` — per-window remain-on-exit via pane ID, absolute PANES_FILE path

### Fixed
- 8 communication wiring issues (orphan protocols, missing handlers for backlog-updated/session-end/clarification-complete)
- Orchestrator explicitly reads done-product-owner.md for acceptance verdict
- PO signals clarification-complete back to orchestrator
- Brief filenames changed from `brief-#NNN.md` to `brief-NNN.md` (shell safety)
- Git write tools added to orchestrator and PO allowedTools
- Architect/QA explicit done file paths in prompts
- Duplicate crash detection removed from watch-done.sh
- watch-done.sh skips done-orchestrator.md self-notification
- watch-done.sh uses absolute paths in notifications (prevents cross-project confusion)
- tmux colon in window names breaking set-option target parser
- Pane ID capture in 2x2 grid using `split-window -P -F`

## [1.2.0] - 2026-04-14

### Added
- `WATCHERS` tmux window — dedicated window for `watch-done.sh` and `monitor.sh` instead of fragile background processes
- 300ms delay between text and Enter in all `tmux send-keys` calls to fix TUI input race condition
- `ship` skill — standardized commit, push, and verify workflow for all agents shipping code to GitLab
- Ship skill added to all 5 agents (engineer, architect, principal-qa, orchestrator, product-owner)

### Changed
- All agents launched with `-a` (`--trust-all-tools`) — eliminates permission prompt blocking
- `monitor.sh` stripped of permission-approval logic — now only handles crash detection and done-file reporting
- `swarm.sh` watchers moved from background processes (`&`) to dedicated WATCHERS tmux window
- Orchestrator prompt updated to reflect that `monitor.sh` and `watch-done.sh` run in WATCHERS window

### Fixed
- Agents no longer stall on permission prompts waiting for manual approval
- `tmux send-keys` messages no longer silently fail to submit due to TUI input buffering race condition
- Background watchers no longer die when Product Owner shell changes

## [1.1.0] - 2026-04-13

### Added
- `dashboard.sh` — live tmux dashboard showing agents, tasks, and GitLab issues with configurable refresh interval (default 10s)
- MONITOR window auto-launched by `swarm.sh` alongside other agent windows

### Changed
- `swarm.sh` now creates a MONITOR window running `dashboard.sh` as part of the standard swarm launch

## [1.0.0] - 2026-04-13

### Added
- **Product Owner agent** — human-facing agent that owns vision, writes requirements, prioritizes backlog, does acceptance review
- **Context Brief skill** — architect generates pre-task context with file roles, dependencies, blast radius, API contracts
- **Pre-Merge Review skill** — QA reviews developer branch diff, verifies acceptance criteria, gives PASS/FAIL verdict
- **Product Ownership skill** — requirements gathering, batch mode, session scope tracking, proactive reporting
- `compact-memory.sh` — archives old memory entries, keeps last N to prevent context drift
- `query-status.sh` — queries status.json for ready tasks, blocked tasks, agent status, dependencies
- `watch-done.sh` — watches for done files and notifies orchestrator automatically, detects agent crashes
- `status.json` — structured task state with dependencies, priorities, agent assignments
- `vision.md` — project purpose, goals, success criteria maintained by Product Owner
- Orchestrator self-serves from GitLab backlog when idle — no per-issue PO nudge needed
- Auto-accept for trivial issues (chore/docs/dependency at P3+) — reduces human interrupts
- Session scope tracking — PO tracks session goals, reports progress proactively
- Batch mode — PO accepts roadmaps/lists and creates multiple issues at once
- Session summary on "land the plane" — enables multi-day continuity
- Crash detection in monitor.sh and watch-done.sh — notifies orchestrator on agent failure
- `build_command` and `test_command` in config.json — project-level defaults for task files
- Dependency tracking with blocked_by/blocks fields in status.json
- Revision cycle — max 2 QA fail rounds before human escalation

### Changed
- **BREAKING:** Product Owner is now the default tmux window; orchestrator runs as an agent window
- **BREAKING:** Orchestrator receives work from PO via task files instead of being the human-facing session
- Architect expanded from one-shot auditor to continuous advisor (5 task types: context brief, impact analysis, architecture review, post-merge validation, task decomposition)
- Principal QA expanded from one-shot auditor to continuous quality gate (6 task types: pre-merge review, post-merge regression, test coverage, cross-agent consistency, deep QA, acceptance verification)
- Engineer now reads architect's context brief, handles QA revision cycles, self-identifies via AGENT_NUMBER env var, checks memory.md before starting
- All skills rewritten to Agent Skills spec: proper trigger descriptions, Output templates, Gotchas, Constraints sections
- Skills no longer contradict agent prompts — issue creation consistently routed through orchestrator
- Landing protocol differentiates commit format by agent role (only engineers use `Closes #NNN`)
- Done file format now includes Acceptance Criteria Self-Check and API Contracts Preserved sections
- `swarm.sh` validates config before launch, keeps windows open on agent exit, launches background watchers
- `monitor.sh` matches on window name (not process name), detects crashes
- Orchestrator triage routes clarification to PO (not human directly)
- All scripts updated to recognize PRODUCT-OWNER and ORCHESTRATOR windows

### Fixed
- `compact-memory.sh` archives only dropped entries (not all entries causing duplicates)
- `compact-memory.sh` uses timestamped pattern `^## YYYY-` to avoid matching structural headers
- `query-status.sh` passes file path via sys.argv (not shell interpolation into Python)
- `query-status.sh` validates required arguments, reports unknown agents/issues
- `agents.sh` window-to-filename mapping works correctly for all agent types
- `swarm.sh` passes AGENT_NUMBER env var so engineers know their N
- `swarm.sh` uses remain-on-exit so windows survive agent crashes
- `swarm.sh` pre-flight validates gitlab_project_id before launching
- `monitor.sh` no longer filters on kiro-cli process name (missed agents during builds)
