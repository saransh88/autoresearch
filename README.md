# /autoresearch

> Autonomous optimization loop for Claude Code. Give it a goal — it classifies the type of work, experiments iteratively, and commits only what improves a measurable metric.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch). Works on any stack, any domain. No flags. Goal classification is automatic.

---

## The idea

Most optimization work follows the same loop:

1. Measure the current state
2. Try something small
3. Check if it helped
4. Keep it or undo it
5. Repeat

`/autoresearch` automates that loop. The agent reads your goal, classifies the type of work, picks the right approach, and runs experiments autonomously — committing improvements, reverting regressions, logging everything.

---

## Install

```bash
mkdir -p ~/.claude/skills/autoresearch
curl -o ~/.claude/skills/autoresearch/SKILL.md \
  https://raw.githubusercontent.com/saransh88/autoresearch/main/SKILL.md
```

Or clone and copy:

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

**Reset everything:**
```
/autoresearch clear
```

---

## How it classifies your goal

No flags needed. The agent reads your goal and picks one of three modes:

| Mode | What it works on | How it measures progress |
|------|-----------------|--------------------------|
| **Engineering** | Code, tests, builds, configs | Script-extractable number (`coverage_pct`, `build_ms`, `failing_tests`, `bundle_kb`) |
| **Research** | Competitors, market, features to build, user segments | Rubric score (0–10) against coverage of required dimensions |
| **Docs** | Personas, PRDs, journey maps, briefs, strategy docs | Rubric score (0–10) against specificity and evidence criteria |

The agent decides which mode applies. You never specify it.

---

## Goal examples

**Engineering:**

| Stack | Goal |
|-------|------|
| React / Jest | `/autoresearch improve test coverage above 80%` |
| Any (mutation) | `/autoresearch improve Stryker mutation score above 75%` |
| Android / Gradle | `/autoresearch reduce assembleDebug build time below 3 minutes` |
| iOS / Xcode | `/autoresearch fix all failing XCTest unit tests` |
| Ruby / RSpec | `/autoresearch improve RSpec coverage above 85% on app/services/` |
| Any frontend | `/autoresearch reduce JS bundle size below 400kb` |
| Any backend | `/autoresearch reduce API p95 response time below 150ms` |

**Research:**

| Domain | Goal |
|--------|------|
| Competitive | `/autoresearch what are the top 5 features to build for the contractor segment` |
| Market | `/autoresearch competitive analysis for contractor invoicing tools` |
| User segment | `/autoresearch map the contractor customer segment` |

**Docs:**

| Artifact | Goal |
|----------|------|
| Persona | `/autoresearch sharpen the contractor persona` |
| PRD | `/autoresearch improve the onboarding PRD` |
| Journey map | `/autoresearch iterate on the journey map for first invoice` |
| Brief | `/autoresearch make the GTM brief more specific` |

---

## How it works

### Phase 1 — Setup (first run only)

The agent reads the goal and classifies it. Then:

**Engineering mode** — reads your repo and infers:
- Stack (from `package.json`, `build.gradle`, `Gemfile`, `go.mod`, CI config, etc.)
- Benchmark command (from CI config — the command your team actually runs)
- Metric (maps goal to a number)

Then writes `autoresearch.sh` — the benchmark script that outputs `METRIC name=value`.

**Research and Docs modes** — defines a rubric instead of a script:
- Specific to the goal (competitive analysis rubric ≠ persona rubric)
- Fixed for the session — doesn't change between iterations
- Each criterion is independently scoreable (+N points)

All modes write `autoresearch.md` (living doc) and `autoresearch.jsonl` (experiment log).

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
    (edit code / search web / edit doc)
        │
        ▼
  Score / benchmark
  (run script OR evaluate against rubric)
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

The loop stops when any of these are true:
- **Goal met** — numeric target reached (e.g. "above 80%", "score 8+")
- **Converged** — no improvement in 5 consecutive runs
- **Backlog exhausted** — all ideas tried

### Skills integration

If other skills are installed (e.g. [pm-skills](https://github.com/phuryn/pm-skills)),
autoresearch invokes them rather than reinventing the wheel:

- `competitor-analysis` → used in research mode to generate v1 artifact
- `user-personas` → used in docs mode to enrich a persona draft
- `customer-journey-map` → used in docs mode for journey map iterations
- `investigate` → used in engineering mode when root cause of a regression is unclear

The loop handles the iteration and scoring. The skills handle the specialized work within each iteration.

---

## The experiment log

Every run is appended to `autoresearch.jsonl`:

```jsonl
{"run": 0, "commit": null, "metric": 3, "delta": 0, "status": "baseline", "description": "V1 competitive brief. 4 competitors, no pricing, no reviews. Rubric 3/10.", "timestamp": "2026-04-21T09:00:00Z"}
{"run": 1, "commit": "c1d2e3f", "metric": 5, "delta": 2, "status": "kept", "description": "Added pricing for all competitors, found 5th. Score 5/10.", "timestamp": "2026-04-21T09:15:00Z"}
{"run": 2, "commit": null, "metric": 5, "delta": 0, "status": "reverted", "description": "Added G2 quotes — no score gain. Reverted.", "timestamp": "2026-04-21T09:30:00Z"}
```

`kept` = committed. `reverted` = undone. Both logged. The history is the value.

---

## Session files

Written to your working directory. Add to `.gitignore` to keep them out of your repo commits (the skill repo's `.gitignore` already ignores them by default).

| File | Purpose |
|------|---------|
| `autoresearch.md` | Living doc — goal, mode, metric/rubric, ideas backlog, history, dead ends |
| `autoresearch.sh` | Benchmark script (engineering mode). Outputs `METRIC name=value`. Never modified by the agent. |
| `autoresearch.jsonl` | Append-only experiment log. Survives restarts. |
| `autoresearch.checks.sh` | *(optional)* Safety checks — blocks `keep` if they fail |

---

## Optional: safety checks

Create `autoresearch.checks.sh` to add a backpressure gate:

```bash
#!/bin/bash
# runs after each passing benchmark — blocks keep if it fails
yarn lint --quiet || exit 1
yarn tsc --noEmit || exit 1
```

---

## Examples

| Example | Mode | Baseline → Best |
|---------|------|-----------------|
| `examples/android-build-time/` | Engineering | 247s → 171s build time |
| `examples/jest-coverage/` | Engineering | 38.4% → 80.5% coverage |
| `examples/rspec-coverage/` | Engineering | 61.2% → 76.4% coverage |
| `examples/stryker-mutation/` | Engineering | 57.6% → 85.25% mutation score |
| `examples/competitor-research/` | Research | Rubric 3/10 → 8/10 |
| `examples/persona-iteration/` | Docs | Rubric 2/10 → 8/10 |

---

## Requirements

- [Claude Code](https://claude.ai/code)
- `git` in `$PATH`
- For research mode: web access (Claude Code's `WebFetch`/`WebSearch` tools)

---

## License

MIT
