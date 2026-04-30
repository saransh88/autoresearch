# /autoresearch

> Autonomous optimization loop for Claude Code. Give it a goal — it experiments overnight and commits only what works.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch). Works on any stack. You write one sentence. The agent handles the rest.

---

## The idea

Most optimization work follows the same loop:

1. Measure the current state
2. Try something small
3. Check if it helped
4. Keep it or undo it
5. Repeat

`/autoresearch` automates that loop. It reads your repo, figures out how to measure your goal, and runs experiments autonomously — committing improvements, reverting regressions, logging everything. You come back to a clean git history and a full audit trail.

---

## Install

```bash
mkdir -p ~/.claude/skills/autoresearch
curl -o ~/.claude/skills/autoresearch/SKILL.md \
  https://raw.githubusercontent.com/saransh88/autoresearch/main/SKILL.md
```

Or clone and symlink:

```bash
git clone https://github.com/saransh88/autoresearch.git
mkdir -p ~/.claude/skills/autoresearch
cp autoresearch/SKILL.md ~/.claude/skills/autoresearch/SKILL.md
```

Requires [Claude Code](https://claude.ai/code).

---

## Usage

From your repo root in Claude Code:

```
/autoresearch <your goal in plain English>
```

**Stop the loop:**
```
/autoresearch off
```
Prints a session summary. Files are preserved. Run again to resume.

**Reset everything:**
```
/autoresearch clear
```

---

## Goal examples

| Stack | Goal |
|-------|------|
| React / Jest | `/autoresearch improve test coverage above 80%` |
| Any (mutation) | `/autoresearch improve Stryker mutation score above 75% on src/modules/` |
| Android / Gradle | `/autoresearch reduce assembleDebug build time below 3 minutes` |
| iOS / Xcode | `/autoresearch fix all failing XCTest unit tests` |
| Ruby / RSpec | `/autoresearch improve RSpec coverage above 85% on app/services/` |
| Go | `/autoresearch fix all failing go test ./...` |
| Any CI | `/autoresearch reduce CI pipeline time below 8 minutes` |
| Any frontend | `/autoresearch reduce JS bundle size below 400kb` |
| Any backend | `/autoresearch reduce API p95 response time below 150ms` |
| TypeScript | `/autoresearch reduce TypeScript compile errors to zero` |

The goal tells the agent **what** to optimize. It figures out **how** to measure it by reading your repo — CI config, `package.json`, `build.gradle`, `Gemfile`, whatever is there.

---

## How it works

### Phase 1 — Setup (first run only)

The agent reads your repo and infers:
- **Stack** — from `package.json`, `build.gradle`, `Gemfile`, `go.mod`, etc.
- **Benchmark command** — from your CI config (`.github/workflows/`, `.circleci/`) — the command your team actually runs
- **Metric** — maps your goal to a number: `coverage_pct`, `build_ms`, `failing_tests`, `bundle_kb`, etc.
- **Files in scope** — starts conservative, expands as needed

Then writes three files in your repo root:

| File | Purpose |
|------|---------|
| `autoresearch.md` | Living doc — goal, metric, ideas backlog, history, dead ends |
| `autoresearch.sh` | Benchmark script. Outputs `METRIC name=value`. Never modified by the agent. |
| `autoresearch.jsonl` | Append-only experiment log. Survives restarts. |

Runs the baseline and logs it as run `#0`.

### Phase 2 — Main loop

```
Read context (autoresearch.md + last 10 runs)
        │
        ▼
  Pick ONE idea from backlog
  (smallest testable delta)
        │
        ▼
    Apply the change
        │
        ▼
  bash autoresearch.sh
  extract METRIC value
        │
        ▼
  Improved? ──Yes──▶  git commit  ──▶  log "kept"
      │
     No
      │
      ▼
  git checkout -- .  ──▶  log "reverted"
      │
      ▼
  Update autoresearch.md
  Check stopping conditions
        │
        ▼
  ScheduleWakeup(60) → repeat
```

### Stopping automatically

The loop stops itself when any of these are true:
- **Goal met** — numeric target in the goal (e.g. "above 80%") is reached
- **Converged** — no improvement in 5 consecutive runs
- **Backlog exhausted** — all ideas tried

### Phase 3 — Resume

If `autoresearch.md` already exists when you invoke the skill, it resumes from where it left off — restoring context from the log and continuing with the next untried idea.

---

## The experiment log

Every run is appended to `autoresearch.jsonl`:

```jsonl
{"run": 0, "commit": null, "metric": 37.23, "delta": 0, "status": "baseline", "description": "Coverage baseline. 198 failing suites (MUI mock missing).", "timestamp": "2026-04-16T00:00:00Z"}
{"run": 1, "commit": "a3f9c12", "metric": 64.16, "delta": 26.93, "status": "kept", "description": "Added moduleNameMapper for @mui/material. 2660 → 3793 passing tests.", "timestamp": "2026-04-16T01:00:00Z"}
{"run": 2, "commit": null, "metric": 64.16, "delta": 0, "status": "reverted", "description": "Tried barrel export consolidation. No coverage gain.", "timestamp": "2026-04-16T02:00:00Z"}
```

`kept` = committed. `reverted` = undone. Both are logged. The history is the value.

---

## Safety model

- **Always reverts on regression.** `git checkout -- <files>` runs immediately if the metric doesn't improve. The repo is never left in a broken state.
- **Never modifies `autoresearch.sh`.** The benchmark is stable across all runs.
- **One change per iteration.** Never batches multiple ideas.
- **Only touches files in scope.** Anything out of scope is noted as a dead end, not silently skipped.
- **Infers, doesn't guess.** Reads CI config and build files before doing anything. Uses `AskUserQuestion` only when something is genuinely ambiguous after reading the repo.

---

## Optional: safety checks

Create `autoresearch.checks.sh` in your repo root to add a backpressure gate — runs after each passing benchmark, blocks `keep` if it fails:

```bash
#!/bin/bash
# autoresearch.checks.sh — runs after each improvement
# If this exits non-zero, the change is reverted even if the metric improved

yarn lint --quiet || exit 1
yarn tsc --noEmit || exit 1
```

The agent will never modify this file.

---

## Rules the agent follows

1. **One change per iteration.** Never batch.
2. **Never modify `autoresearch.sh`.** Benchmark stability is non-negotiable.
3. **Always revert on regression.** Never leave the repo dirty.
4. **Only edit files in scope.** Out-of-scope = dead end note, not a skip.
5. **Log everything** — kept and reverted. History is the value.
6. **Infer, don't ask.** Read CI config and build files first.
7. **CI config is ground truth.** Use the command the team actually runs.
8. **Ideas must be grounded.** Every backlog item references a specific file and property found by reading the repo.
9. **Fix one test at a time** in failing-tests mode.
10. **Confidence is advisory.** Never stop an improving loop because of low confidence — report it.

---

## Requirements

- [Claude Code](https://claude.ai/code)
- `git` in `$PATH`

---

## License

MIT
