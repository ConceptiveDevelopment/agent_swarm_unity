# Agent Swarm 🐝

Multi-agent AI orchestration system for autonomous software development. Built with [Kiro CLI](https://kiro.dev) + tmux.

Drop a task list, watch AI agents build in parallel.

## Prerequisites

- **Kiro CLI 2.0+** — [kiro.dev/downloads](https://kiro.dev/downloads/)
- **tmux** — `brew install tmux` (macOS) or `apt install tmux` (Linux)
- **GitHub CLI (gh)** — `brew install gh` — authenticated with `gh auth login`
- **Linear** — API key set as `LINEAR_API_KEY` environment variable
- **Notion** (optional) — API key set as `NOTION_API_KEY` for documentation sync
- **Python 3** — for dashboard, status scripts, and hook JSON parsing
- **Git 2.5+** — worktree support required

## Quick Start

### Ask Kiro to install it

Open Kiro CLI in your project directory and say:

```
Install the agent swarm from https://github.com/ConceptiveDevelopment/agent_swarm.git
Clone it, then copy .kiro/agents/, .kiro/skills/, .kiro/swarm/, and .kiro/scripts/
into this project. Then edit .kiro/swarm/config.json with my project's GitHub repo
and Linear team/project IDs.
```

### Or install manually

```bash
# 1. Clone
git clone https://github.com/ConceptiveDevelopment/agent_swarm.git
cd agent_swarm

# 2. Copy into your project
cp -r .kiro/agents/ /path/to/your/project/.kiro/agents/
cp -r .kiro/skills/ /path/to/your/project/.kiro/skills/
cp -r .kiro/swarm/ /path/to/your/project/.kiro/swarm/
cp -r .kiro/scripts/ /path/to/your/project/.kiro/scripts/

# 3. Edit config
vi /path/to/your/project/.kiro/swarm/config.json
# Set: project_name, github_repo, linear_team_id, linear_project_id, build_command, test_command

# 4. Launch
cd /path/to/your/project
bash .kiro/scripts/swarm.sh
```

### Configuration

Edit `.kiro/swarm/config.json`:

```json
{
  "project_name": "your-project",
  "git_remote": "origin",
  "issue_tracker": "linear",
  "linear_api_key_env": "LINEAR_API_KEY",
  "linear_team_id": "your-team-uuid",
  "linear_project_id": "your-project-uuid",
  "source_code": "github",
  "github_repo": "YourOrg/your-repo",
  "documentation": "notion",
  "notion_api_key_env": "NOTION_API_KEY",
  "max_developers": 4,
  "branch_prefix": "feature/",
  "commit_format": "feat(<scope>): <description> — Implements <TICKET-ID>",
  "build_command": "npm run build",
  "test_command": "npm test",
  "auto_accept_labels": ["chore", "docs", "dependency"],
  "auto_accept_max_priority": 3
}
```

Required fields: `project_name`, `github_repo`, `linear_team_id`.

### Launch & Teardown

```bash
# Launch with 4 developers (default)
bash .kiro/scripts/swarm.sh

# Launch with 2 developers
bash .kiro/scripts/swarm.sh 2

# Kill the swarm (project-scoped, safe with multiple swarms)
bash .kiro/scripts/kill-swarm.sh
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  COMMAND WINDOW                                          │
│  ┌──────────────────────────────┬───────────────────┐    │
│  │ HUMAN ↔ PRODUCT-OWNER       │ MONITOR            │    │
│  │ • Translates goals → issues  │ • Live dashboard   │    │
│  │ • Prioritizes backlog        │ • Agent status     │    │
│  │ • Acceptance review          │ • Task progress    │    │
│  │ (2/3 width)                  │ (1/3 width)        │    │
│  └──────────────────────────────┴───────────────────┘    │
├──────────────────────────────────────────────────────────┤
│                    ORCHESTRATOR                           │
│  • Receives issues from PO, coordinates execution        │
│  • Consults architect + QA before/after each task         │
│  • Manages branches, merges, status tracking              │
├──────────────────────┬───────────────────────────────────┤
│      ARCHITECT       │         PRINCIPAL-QA              │
│  briefs, impact,     │  pre-merge, regression,           │
│  validate, decompose │  coverage, consistency            │
├──────────┬───────────┼───────────┬───────────────────────┤
│  DEV-1   │  DEV-2    │  DEV-3    │  DEV-4               │
│  code    │  code     │  code     │  code                │
│  build   │  build    │  build    │  build               │
│  push    │  push     │  push     │  push                │
├──────────┴───────────┴───────────┴───────────────────────┤
│                      WATCHERS                            │
│  Supervisor: crash detection, done-file watch, heartbeat │
└──────────────────────────────────────────────────────────┘
              ↕ .kiro/swarm/ filesystem + native hooks ↕
```

## Agents

| Agent | Role | Window |
|-------|------|--------|
| `product-owner` | Human-facing — requirements, priorities, acceptance review | COMMAND (left pane) |
| `orchestrator` | Coordinates all agents, manages execution, updates Linear | Own window |
| `architect` | Structural advisor — context briefs, impact analysis, post-merge checks | Own window |
| `principal-qa` | QA gate — pre-merge review, regression checks, acceptance verification | Own window |
| `engineer` | Implements features on isolated branches using worktrees | DEVELOPERS (2x2 grid) |

## How It Works

### Communication Protocol

Agents communicate through files in `.kiro/swarm/`:

| File | Writer | Reader | Purpose |
|------|--------|--------|---------|
| `task-<agent>.md` | Sender | Receiver | Task assignment with full context |
| `done-<agent>.md` | Agent | Orchestrator | Completion report + discovered issues |
| `brief-<ID>.md` | Architect | Orchestrator → Developer | Context brief for a task |
| `status.json` | Orchestrator | Scripts, dashboard | Structured task/agent state |
| `status.md` | Orchestrator | All agents | Human-readable board |
| `memory.md` | All agents | All agents | Append-only shared findings (compacted every 5 tasks) |
| `vision.md` | Product Owner | All agents | Project purpose, goals, non-goals |
| `config.json` | Human | All agents | Project config |
| `panes.json` | swarm.sh | Scripts | Tmux pane ID manifest for session-safe routing |

### Integration Stack

- **Linear** is the source of truth for issues. The orchestrator tracks state in Linear and locally in `status.json`.
- **GitHub** hosts the code. PRs are created via `gh pr create` and merged via `gh pr merge`.
- **Notion** (optional) holds documentation. Agents can read/write Notion pages via API.
- **Commits** reference Linear tickets: `feat(scope): description — Implements PROJ-42`

### Reliability: Native Hooks + External Watchers

**Native kiro-cli hooks** run inside each agent's process:

| Hook | Event | Agents | What it does |
|------|-------|--------|-------------|
| `agent-startup.sh` | `agentSpawn` | All | Injects project context on startup |
| `boundary-check.sh` | `preToolUse` | All | **Blocks** file access outside project directory |
| `validate-before-done.sh` | `preToolUse` | Engineers | **Blocks** done file write if branch not pushed |
| `task-scope-check.sh` | `preToolUse` | Engineers | **Blocks** writes to files not in task assignment |
| `drift-check-hook.sh` | `stop` | Engineers | Injects task reminder if response drifts |

**External watchers** run in the WATCHERS window (auto-restart on crash):

| Watcher | Interval | What it does |
|---------|----------|-------------|
| `watch-done.sh` | 5s | Detects done files, validates, notifies orchestrator |
| `monitor.sh` | 5s | Detects agent crashes, notifies orchestrator |
| `heartbeat.sh` | 60s | Detects stuck agents, nudges them |
| `task-watcher.sh` | 10s | Catches undelivered task files, nudges idle agents |
| `po-notifier.sh` | 30s | Notifies PO when issues close |

## Multi-Swarm Isolation

Multiple swarms can run simultaneously in different tmux sessions:

- **Window namespacing** — All tmux windows prefixed with project name (e.g. `myproject:ORCHESTRATOR`)
- **Pane manifest** — `panes.json` maps logical agent names to tmux pane IDs per project
- **Session scoping** — Scripts only see windows in their own namespace

## Skills

| Skill | Description |
|-------|-------------|
| `worktree-branch` | Create isolated git worktree for a new branch |
| `ship` | Standardized commit + push + verify workflow |
| `agent-lifecycle` | Standard lifecycle: task → execute → land the plane → report → idle |
| `product-ownership` | Requirements gathering, backlog prioritization, acceptance review |
| `context-brief` | Pre-task context: file roles, dependencies, blast radius, API contracts |
| `pre-merge-review` | Review developer branch diff, verify acceptance criteria, PASS/FAIL verdict |
| `deep-qa-review` | Risk-prioritized per-file checklist, 3-level bug analysis |
| `architecture-review` | Full audit: dependency graph, orphans, circular deps, complexity hotspots |
| `project-hygiene` | Audit git, issues, docs, ensure everything is in sync |
| `release-checklist` | Version, changelog, tag, push, update docs |
| `docs-update` | Keep README, CHANGELOG, and API docs current after merges |

## Rules

1. Human talks to Product Owner only — PO talks to orchestrator
2. No two developers work on the same file
3. Each developer works on a separate git branch (via worktree, never checkout in main)
4. Orchestrator merges all branches to main
5. Task files contain full context (saves tokens)
6. Max 4 developer agents at once (2x2 grid)
7. Agents never fix code outside their assigned ticket (enforced by `task-scope-check.sh`)
8. Agents must push before writing done files (enforced by `validate-before-done.sh`)
9. Agents report discovered issues in done files — only the orchestrator creates Linear issues
10. Memory is compacted every 5 completed tasks
11. Tasks with open blockers are never assigned
12. Product Owner does final acceptance review before issues are closed
13. Linear is the source of truth — all state changes must be reflected there

## License

MIT
