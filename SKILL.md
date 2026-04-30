---
name: autoresearch
version: 2.1.0
description: |
  Autonomous experiment loop for any engineering optimization goal on any stack.
  Works on Android (Kotlin/Gradle), iOS (Swift/Xcodebuild), Web (React/JS/TS),
  Backend (Ruby/Rails, Node, Python, Go), or any repo with a measurable metric.
  User provides a goal in plain English — agent infers the stack, benchmark command,
  and metric automatically. Use when: "autoresearch", "optimize X", "improve X",
  "reduce X", "increase X", "fix failing tests", "speed up build", "improve coverage",
  "reduce response time", "keep improving X overnight".
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - ScheduleWakeup
---

# /autoresearch — Autonomous Optimization Loop

Give it a goal. It reads your repo, infers how to measure it, experiments overnight,
and commits only what actually improves the metric.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).
Works on any stack. Stack is inferred — never hardcoded.

---

## User-invocable

When the user types `/autoresearch` (with any arguments), run this skill.

## Arguments

| Invocation | Behavior |
|---|---|
| `/autoresearch <goal>` | Start or resume an optimization loop. Goal is plain English. |
| `/autoresearch off` | Stop the loop, print session summary, preserve files |
| `/autoresearch clear` | Wipe session files and start fresh |

**Goal examples (any stack):**
- `/autoresearch reduce Android build time`
- `/autoresearch fix failing iOS unit tests`
- `/autoresearch improve RSpec test coverage above 80%`
- `/autoresearch reduce API p95 response time`
- `/autoresearch speed up the React test suite`
- `/autoresearch reduce bundle size`

The goal tells the agent *what* to optimize. The agent figures out *how* to measure it
by reading the repo.

---

## Session Files

Written to the **current working directory** (run from your repo root):

| File | Purpose |
|---|---|
| `autoresearch.md` | Living doc: goal, metric, stack notes, ideas backlog, history, dead ends |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value`. Never modified by agent. |
| `autoresearch.jsonl` | Append-only experiment log. Survives restarts. |
| `autoresearch.checks.sh` | *(optional, human-written)* Safety checks — blocks `keep` if they fail |

---

## Instructions

### Phase 0: Parse arguments and load state

```bash
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required"; exit 1; }

_JSONL="autoresearch.jsonl"
_RUN_COUNT=0
if [ -f "$_JSONL" ]; then
  _RUN_COUNT=$(wc -l < "$_JSONL" | tr -d ' ')
fi
echo "AUTORESEARCH: $( [ -f autoresearch.md ] && echo 'resuming' || echo 'new session' ) | runs: $_RUN_COUNT"
```

- If argument is `off` → go to **Phase 5**
- If argument is `clear` → go to **Phase 6**
- Otherwise the argument is the user's **goal** → go to **Phase 1** (new) or **Phase 2** (resume)

---

### Phase 1: Stack detection and session setup

**Only runs when `autoresearch.md` does not exist.** If it exists, skip to Phase 2.

#### Step 1a — Detect the stack

Read the repo to understand what you're working with. Look for these signals in order:

```bash
# Root-level indicators
ls -la
cat package.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('scripts',{}))" 2>/dev/null
ls build.gradle build.gradle.kts settings.gradle Gemfile Podfile Package.swift pyproject.toml go.mod Cargo.toml 2>/dev/null
ls .github/workflows/ .circleci/ 2>/dev/null
```

Then read the CI config — it's the most reliable source of truth for how to run things:

```bash
# GitHub Actions
cat .github/workflows/*.yml 2>/dev/null | head -200
# CircleCI
cat .circleci/config.yml 2>/dev/null | head -200
```

The CI config tells you the canonical command teams actually use. Prefer it over guessing.

**Stack detection matrix:**

| Signal found | Stack | Likely test command | Likely build command |
|---|---|---|---|
| `build.gradle` / `build.gradle.kts` | Android/Kotlin | `./gradlew test` or `./gradlew connectedAndroidTest` | `./gradlew assembleDebug` |
| `Package.swift` or `*.xcworkspace` / `*.xcodeproj` | iOS/Swift | `xcodebuild test -scheme <X>` | `xcodebuild build -scheme <X>` |
| `Gemfile` + `spec/` or `test/` | Ruby/Rails | `bundle exec rspec` or `bundle exec rake test` | N/A (or `bundle exec rake assets:precompile`) |
| `package.json` with jest/vitest | JS/TS (Web/Node) | `npm test` / `yarn test` / `npx vitest run` | `npm run build` / `yarn build` |
| `pyproject.toml` or `setup.py` | Python | `pytest` or `python -m pytest` | N/A |
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |

Always verify the command exists before writing `autoresearch.sh` — run it mentally against
the directory structure.

#### Step 1b — Map the goal to a metric

The user's goal is plain English. Map it to a concrete, extractable metric:

| Goal keywords | Metric | Direction | How to extract |
|---|---|---|---|
| "build time", "compile time", "speed up build" | `build_ms` | ↓ lower | Time the build command |
| "test speed", "test time", "run faster", "slow tests" | `test_ms` | ↓ lower | Time the test command |
| "failing tests", "fix tests", "broken tests", "flaky" | `failing_tests` | ↓ lower | Parse test runner output for failure count |
| "coverage", "test coverage" | `coverage_pct` | ↑ higher | Parse coverage report for % |
| "response time", "API latency", "p95", "p99" | `p95_ms` | ↓ lower | Run load test or curl loop, parse result |
| "bundle size", "asset size", "JS size" | `bundle_kb` | ↓ lower | `du -sk dist/` or build output |
| "lint errors", "linting" | `lint_errors` | ↓ lower | Parse linter output for error count |
| "memory", "memory usage" | `memory_mb` | ↓ lower | Parse runtime output |
| "startup time", "boot time", "cold start" | `startup_ms` | ↓ lower | Time to first ready signal |

If the goal doesn't map cleanly, ask once:
> "What should I measure to know we're making progress? What command produces a number that goes up or down?"

#### Step 1c — Write autoresearch.sh

Write a benchmark script that is **specific to this repo and stack**. The script must:
1. Run from the repo root
2. Execute the benchmark command
3. Extract or compute the metric value
4. Print exactly one line: `METRIC <name>=<value>` where value is a plain number

**Templates by goal type:**

**Build time / test time:**
```bash
#!/bin/bash
# autoresearch benchmark — do not modify
set -uo pipefail
START=$(date +%s%N)
<the exact command from CI config or package.json> 2>&1
END=$(date +%s%N)
echo "METRIC <metric_name>=$(( (END - START) / 1000000 ))"
```

**Failing tests — generic (works for any runner):**
```bash
#!/bin/bash
# autoresearch benchmark — do not modify — counts failing tests
set -uo pipefail
OUTPUT=$(<test command> 2>&1 || true)
printf '%s\n' "$OUTPUT"

# Extract failure count — adapt pattern to actual runner output
COUNT=$(printf '%s\n' "$OUTPUT" | grep -oE '[0-9]+ (failure|failed|error)' | head -1 | grep -oE '^[0-9]+' || echo "0")
echo "METRIC failing_tests=$COUNT"
```

**Adapt the failure grep pattern to the actual test runner:**
- RSpec: `grep -oE '[0-9]+ failure'`
- Gradle/JUnit: `grep -oE 'Tests run: [0-9]+, Failures: [0-9]+' | grep -oE 'Failures: [0-9]+' | grep -oE '[0-9]+'`
- Jest/Vitest: `grep -oE '[0-9]+ failed'`
- Swift/XCTest: `grep -oE 'with [0-9]+ failure'`
- pytest: `grep -oE '[0-9]+ failed'`
- Go test: `grep -c '^--- FAIL'`

**Coverage (generic):**
```bash
#!/bin/bash
# autoresearch benchmark — do not modify — measures coverage %
set -uo pipefail
OUTPUT=$(<test-with-coverage command> 2>&1 || true)
printf '%s\n' "$OUTPUT"

# Extract coverage % — adapt to runner
PCT=$(printf '%s\n' "$OUTPUT" | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -1 | tr -d '%' || echo "0")
echo "METRIC coverage_pct=$PCT"
```

**API response time:**
```bash
#!/bin/bash
# autoresearch benchmark — do not modify — measures p95 response time
set -uo pipefail
# Run N requests and compute p95
TIMES=()
for i in $(seq 1 20); do
  MS=$(curl -s -o /dev/null -w "%{time_total}" <endpoint_url> | awk '{printf "%.0f", $1*1000}')
  TIMES+=($MS)
done
P95=$(printf '%s\n' "${TIMES[@]}" | sort -n | awk 'BEGIN{c=0} {a[c++]=$1} END{print a[int(c*0.95)]}')
echo "METRIC p95_ms=$P95"
```

**Bundle size:**
```bash
#!/bin/bash
# autoresearch benchmark — do not modify — measures bundle size
set -uo pipefail
<build command> 2>&1
KB=$(du -sk <dist directory> | cut -f1)
echo "METRIC bundle_kb=$KB"
```

#### Step 1d — Write autoresearch.md

```markdown
# autoresearch session

## Goal
<user's plain-English goal>

## Stack
<detected stack: e.g. "Android / Kotlin / Gradle" or "Ruby on Rails / RSpec">

## Metric
- Name: <metric_name>
- Direction: <lower|higher> is better
- Benchmark command: `<the command in autoresearch.sh>`

## Files in scope
<specific list — start conservative, expand as needed>

## Ideas backlog
<generated from Step 1e>

## History
<!-- Agent appends after each run: Run N — what was tried — result -->

## Dead ends
<!-- Agent notes here: what failed and why -->
```

#### Step 1e — Generate a stack-specific ideas backlog

Read the repo's config files, CI config, and any existing relevant files before writing ideas.
Ideas must be **specific to what you found in this repo** — not generic advice.

For each idea, note:
- The specific file to change
- The specific property/value to change
- Why it's expected to help

**Ideas by goal type and stack:**

**Android build time (`build.gradle` / `build.gradle.kts`):**
- Enable Gradle build cache: `org.gradle.caching=true` in `gradle.properties`
- Enable parallel builds: `org.gradle.parallel=true`
- Enable configuration cache: `org.gradle.configuration-cache=true`
- Increase heap: `org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC`
- Check for `clean` in CI command — remove it if present (invalidates cache every run)
- Disable unused Gradle modules/tasks
- Enable incremental compilation if not set

**iOS build time (`Xcodebuild`):**
- Enable parallel builds in scheme settings
- Reduce `SWIFT_COMPILATION_MODE` from `wholemodule` to `incremental` for debug
- Enable build caching with `ccache` or `xcodebuild -derived-data-path`
- Disable unused targets in the scheme
- Check for unnecessary copy phases

**Ruby/RSpec test speed:**
- Add `--fail-fast` for local runs
- Use `DatabaseCleaner` strategy: `truncation` → `transaction` (faster rollback)
- Parallelize with `parallel_tests` gem
- Use `FactoryBot.build_stubbed` instead of `create` where persistence not needed
- Reduce `let` chains that trigger unnecessary DB queries
- Profile slow specs: `bundle exec rspec --profile 10`

**JS/TS test speed (Jest/Vitest):**
- Set `--maxWorkers=50%` (default can oversaturate CPU)
- Use `--testPathPattern` to scope locally
- Switch `transform` from Babel to SWC/esbuild (10-20x faster transforms)
- Mock heavy imports at module level with `jest.mock()`
- Disable coverage during speed optimization runs

**Go test speed:**
- Add `-parallel N` flag
- Use `-count=1` to disable test caching (for accurate benchmarks), or remove `-count=1` to enable it
- Use `t.Parallel()` in test functions
- Profile with `-cpuprofile` to find bottlenecks

**API response time (any backend):**
- Add database query indexes for slow endpoints
- Enable response caching (Redis, Memcached) for read-heavy routes
- Reduce N+1 queries (use eager loading)
- Move slow operations to background jobs
- Enable HTTP keep-alive / connection pooling

**Test coverage:**
- Find files with 0% coverage and add basic smoke tests
- Add tests for uncovered error/edge case branches
- Use coverage report to identify the highest-ROI files (most uncovered lines)

#### Step 1f — Run baseline

```bash
chmod +x autoresearch.sh
bash autoresearch.sh
```

Log run #0 with `"status": "baseline"` to `autoresearch.jsonl`. Then continue to Phase 2.

---

### Phase 2: Main Loop

The autonomous core. Runs until a stopping condition is met or the user types `/autoresearch off`.

#### Stopping conditions (checked at the start of each iteration)

**1. Goal achieved**
Parse the goal for a numeric target (e.g. "above 80%", "below 500ms", "zero failures").
If present, compare against the current best metric. If the target is met → go to **Phase 5 (Off)** automatically, printing:
```
GOAL ACHIEVED: <metric> = <value> (target was <target>). Stopping.
```

**2. No improvement for N consecutive runs (convergence)**
Default N = 5. After each run, count how many consecutive runs had `delta <= 0`.
If that count reaches N → go to **Phase 5** automatically, printing:
```
CONVERGED: No improvement in last 5 runs. Best <metric>: <value>. Stopping.
```

**3. Backlog exhausted**
After picking an idea in Step 2, if there are no untried ideas left in the backlog (all moved to History or Dead ends) → go to **Phase 5** automatically, printing:
```
BACKLOG EXHAUSTED: All ideas tried. Best <metric>: <value>. Stopping.
```

Track consecutive-no-improvement count in `autoresearch.md` under a `## State` section updated each iteration:
```markdown
## State
- consecutive_no_improvement: 0
- best_metric: <value>
- target: <parsed from goal, or "none">
```

**Each iteration:**

**Step 1 — Load context**
Read `autoresearch.md` (goal, metric, backlog, history, dead ends) and the last 10 lines
of `autoresearch.jsonl`. Compute: baseline, best-so-far, run count, confidence.

**Step 2 — Pick ONE idea**
Choose the single highest-confidence untried idea from the backlog:
- Smallest possible change (not a refactor)
- Clear causal link to the metric
- Only touches files listed in "Files in scope"
- Not tried before (check History and Dead ends)

**Step 3 — Apply it**
Make the minimum viable diff. If editing a config file, change one property.

**Step 4 — Run the benchmark**
```bash
bash autoresearch.sh 2>&1
```
Extract the number from `METRIC name=<value>`.

**Step 5 — Run checks (if present)**
```bash
[ -f autoresearch.checks.sh ] && bash autoresearch.checks.sh 2>&1
```
If checks fail → treat as regression regardless of metric.

**Step 6 — Keep or revert**

For "lower is better": `delta = baseline - new_value`
For "higher is better": `delta = new_value - baseline`

**Improved (delta > 0) AND checks passed:**
```bash
git add <changed files>
git commit -m "autoresearch: <description> [<metric>: <old> → <new>]"
```

**Flat or regressed:**
```bash
git checkout -- <changed files>
```

**Step 7 — Log**
```json
{"run": N, "commit": "<sha|null>", "metric": <value>, "delta": <delta>, "status": "<kept|reverted>", "description": "<what was tried>", "timestamp": "<ISO8601>"}
```

**Step 8 — Update autoresearch.md**
Move tried idea to History. Add dead end note if reverted. Add new ideas if discovered.

**Step 9 — Print progress**
```
[Run N] <metric>: <prev> → <new> (<±pct>%) — <kept|reverted> | Best: <best> | Conf: <score>x
```
Confidence (after 3+ runs): `best_delta / stddev(all_metrics)`.
≥2.0× = likely real · 1–2× = marginal · <1× = within noise.

Update the `## State` block in `autoresearch.md`:
- Increment `consecutive_no_improvement` if delta ≤ 0, reset to 0 if delta > 0
- Update `best_metric` if this run improved it

**Step 10 — Check stopping conditions, then reschedule**

Before scheduling the next run, evaluate all three stopping conditions in order:
1. If a numeric target was parsed and `best_metric` meets it → go to **Phase 5**
2. If `consecutive_no_improvement >= 5` → go to **Phase 5**
3. If no untried ideas remain in the backlog → go to **Phase 5**

If none apply:
```
ScheduleWakeup(60)
```

---

### Phase 3: Failing tests mode

When the goal is about fixing failing/broken tests, each iteration targets ONE test:

1. Run benchmark → parse failing test names from output
2. Pick the first failing test (or most frequently failing)
3. Read the test file to understand the assertion
4. Read the source file / fixture it depends on
5. Apply the minimal fix — wrong expected value, drifted selector, missing await,
   stale fixture data, wrong mock, import path change
6. Re-run benchmark → check if `failing_tests` decreased
7. If yes → `git commit`. If no → `git checkout --` and mark as dead end.

**Parser patterns by runner (adapt to what you find in the repo):**
- RSpec: lines matching `rspec ./<path>:<line>`
- Gradle/JUnit: lines matching `FAILED` or `<testcase ... status="failed">`
- Jest/Vitest: lines matching `✕` or `FAIL <path>`
- XCTest: lines matching `Test Case '...' failed`
- pytest: lines matching `FAILED <path>::<name>`
- Go: lines starting with `--- FAIL:`

---

### Phase 4: Resume

If `autoresearch.md` exists when skill is invoked:
1. Read `autoresearch.md` and `autoresearch.jsonl` to restore context
2. Print: `Resuming: <N> runs completed, best <metric>: <value>`
3. Continue from next untried idea → Phase 2

---

### Phase 5: Off

1. Cancel pending `ScheduleWakeup`
2. Print session summary:
```bash
python3 -c "
import json
lines = [json.loads(l) for l in open('autoresearch.jsonl') if l.strip()]
baseline = next((l for l in lines if l.get('status')=='baseline'), None)
kept = [l for l in lines if l.get('status')=='kept']
reverted = [l for l in lines if l.get('status')=='reverted']
print(f'Runs: {len(lines)-1} | Kept: {len(kept)} | Reverted: {len(reverted)}')
if baseline and kept:
    direction = 1  # change if metric is higher-is-better
    best = max(kept, key=lambda x: direction * x.get('delta', 0))
    pct = abs(best['delta']) / baseline['metric'] * 100
    print(f\"Baseline: {baseline['metric']} → Best: {best['metric']} ({pct:.1f}% improvement)\")
"
```
3. Say: `Files preserved. Run /autoresearch to resume.`

---

### Phase 6: Clear

1. Ask user to confirm (destructive)
2. If confirmed: `rm -f autoresearch.jsonl autoresearch.md autoresearch.sh autoresearch.checks.sh`

---

## Implementation Rules

1. **One change per iteration.** Never batch.
2. **Never modify `autoresearch.sh`.** Benchmark stability is non-negotiable.
3. **Always revert on regression.** Never leave the repo dirty.
4. **Only edit files in scope.** If a file not in scope is needed, note it in dead ends.
5. **Log everything** — kept and reverted. History is the value.
6. **Infer, don't ask.** Read CI config, package.json, build files before asking the user anything.
   Use `AskUserQuestion` only when a critical value is genuinely ambiguous after reading the repo.
7. **The CI config is ground truth.** The command teams actually use is in `.github/workflows/` or `.circleci/config.yml`. Use that — not guesses.
8. **Ideas must be grounded.** Every idea in the backlog must reference a specific file and property found by reading the repo. No generic advice.
9. **Fix one test at a time** in failing-tests mode. Don't batch fixes across multiple tests.
10. **Confidence is advisory.** Never stop an improving loop because of low confidence — report it.
