---
name: autoresearch
version: 3.0.0
description: |
  Autonomous experiment loop for any measurable goal on any stack or domain.
  Classifies the goal automatically — engineering (code/build/test), research
  (competitive/market/user), or docs (PRDs, personas, briefs, journey maps).
  Invokes relevant installed skills per goal type. No flags needed.
  Use when: "autoresearch", "optimize X", "improve X", "reduce X", "increase X",
  "fix failing tests", "speed up build", "improve coverage", "research competitors",
  "improve our PRD", "sharpen personas", "iterate on journey maps", "keep improving X overnight".
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - WebFetch
  - WebSearch
  - Agent
  - AskUserQuestion
  - ScheduleWakeup
---

# /autoresearch — Autonomous Optimization Loop

Give it a goal in plain English. It classifies the goal, picks the right approach,
experiments iteratively, and keeps only what improves a measurable metric.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).
Works on any stack, any domain. No flags. Goal classification is automatic.

---

## User-invocable

When the user types `/autoresearch` (with any arguments), run this skill.

## Arguments

| Invocation | Behavior |
|---|---|
| `/autoresearch <goal>` | Start or resume a loop. Goal is plain English. |
| `/autoresearch off` | Stop the loop, print session summary, preserve files |
| `/autoresearch clear` | Wipe session files and start fresh |

**Goal examples — any domain:**
- `/autoresearch reduce Android build time`
- `/autoresearch fix failing iOS unit tests`
- `/autoresearch improve RSpec test coverage above 80%`
- `/autoresearch what are the top 5 features to build for the contractor segment`
- `/autoresearch sharpen the contractor persona`
- `/autoresearch improve the onboarding PRD`
- `/autoresearch map the contractor job-to-be-done journey`

---

## Session Files

Written to the **current working directory**:

| File | Purpose |
|---|---|
| `autoresearch.md` | Living doc: goal, mode, metric, ideas backlog, history, dead ends |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value`. **Never modified by agent.** |
| `autoresearch.jsonl` | Append-only experiment log. Survives restarts. |
| `autoresearch.checks.sh` | *(optional, human-written)* Safety checks — blocks `keep` if they fail |

---

## Instructions

### Phase 0: Parse arguments and load state

```bash
_JSONL="autoresearch.jsonl"
_RUN_COUNT=0
if [ -f "$_JSONL" ]; then
  _RUN_COUNT=$(wc -l < "$_JSONL" | tr -d ' ')
fi
echo "AUTORESEARCH: $( [ -f autoresearch.md ] && echo 'resuming' || echo 'new session' ) | runs: $_RUN_COUNT"
```

- If argument is `off` → go to **Phase 5**
- If argument is `clear` → go to **Phase 6**
- If `autoresearch.md` exists → go to **Phase 4 (Resume)**
- Otherwise → go to **Phase 1 (Setup)**

---

### Phase 1: Goal classification and session setup

**Only runs when `autoresearch.md` does not exist.**

#### Step 1a — Classify the goal

Read the goal and classify it into one of three modes. Do NOT ask the user which mode — infer it:

**Engineering mode** — the goal involves code, tests, builds, or runtime metrics.

Signals: mentions of build, test, coverage, bundle, latency, response time, lint, compile,
failing tests, flakiness, deployment, startup, memory usage, or names of engineering tools
(Gradle, Jest, RSpec, Xcode, webpack, etc.)

Examples:
- "reduce Android build time"
- "fix failing iOS unit tests"
- "improve Jest coverage above 80%"
- "speed up the React test suite"
- "reduce bundle size"

**Research mode** — the goal involves gathering, synthesizing, or scoring external information
(competitors, market, users, features, positioning).

Signals: mentions of competitors, market, features to build, top N list, user research,
customer segments, pricing, sentiment, interviews, survey results, or phrases like
"what should we build", "who are our users", "how do competitors".

Examples:
- "what are the top 5 features to build for the contractor segment"
- "competitive analysis for contractor invoicing"
- "map the contractor customer segment"
- "what do competitors charge for job management"

**Docs mode** — the goal involves iterating on a text artifact: a PRD, persona, brief,
journey map, strategy doc, or any human-written document already in the repo.

Signals: mentions of persona, PRD, brief, journey map, strategy, document, spec, or
an existing file by name. Goal uses words like "sharpen", "improve", "iterate", "refine".

Examples:
- "sharpen the contractor persona"
- "improve the onboarding PRD"
- "iterate on the journey map for first invoice"
- "make the GTM brief more specific"

**If genuinely ambiguous after reading the goal:** ask once — "Is this about improving code/tests, researching external information, or iterating on a document?"

#### Step 1b — Detect installed skills relevant to this goal

Check which skills are installed. Installed skills live at `~/.claude/skills/` or are
loaded as plugins. The available skills in this environment include:

```bash
ls ~/.claude/skills/ 2>/dev/null
ls ~/.claude/plugins/cache/ 2>/dev/null | head -20
```

**Skills to invoke by mode:**

| Mode | Skills to check for and invoke |
|---|---|
| Engineering | `investigate` (for debugging failing tests), `review` (for code quality checks) |
| Research | `office-hours` (for strategic framing), any installed `pm-skills` plugin skills |
| Docs | `office-hours` (for doc quality framing) |

**pm-skills** (from `phuryn/pm-skills` or similar): if installed, these are available per domain:
- Competitive research: `competitor-analysis`, `market-segments`
- User research: `user-personas`, `interview-script`, `summarize-interview`, `customer-journey-map`
- Strategy: `prd-writer`, `jobs-to-be-done`, `gtm-strategy`
- Sentiment: `sentiment-analysis`

**How to use installed skills in the loop:**
- In Research mode: invoke the relevant pm-skill to generate a structured v1 artifact, then use autoresearch's loop to iterate and score it against a rubric
- In Docs mode: invoke pm-skills to enrich a draft, then score against the rubric
- In Engineering mode: invoke `investigate` if the root cause of a regression is unclear

Do NOT require pm-skills to be installed — if they're absent, proceed without them.

#### Step 1c — Define the metric and rubric

**Engineering mode** → use a script-extractable number (see Step 1d for templates)

**Research mode** → define a rubric score (0–10) based on coverage of required dimensions.
The rubric must be specific to the goal. Example for competitive analysis:
```
Rubric (score 0–10):
- Covers ≥5 named competitors: +2
- Includes pricing for each: +2
- Includes top 3 differentiators per competitor: +2
- Includes customer review sentiment: +2
- Identifies top feature gaps vs our product: +2
```
Score is computed by the agent reading the artifact and self-evaluating against the rubric.
The rubric lives in `autoresearch.md` under `## Rubric`.

**Docs mode** → define a rubric score (0–10) specific to the document type. Example for persona:
```
Rubric (score 0–10):
- Has a named, specific segment (not "SMB"): +1
- Includes 3+ named pain points with evidence: +2
- Includes behavioral patterns (how they work today): +2
- Includes a direct quote or verbatim: +1
- Includes decision criteria for buying: +2
- Specifies segment size or frequency: +1
- Does not use vague adjectives without evidence: +1
```

Write the rubric to `autoresearch.md` under `## Rubric`. The rubric is fixed for the session —
do not change it between iterations (that would invalidate comparisons).

#### Step 1d — Write autoresearch.sh

**Engineering mode only** — write a real executable script.

The script must:
1. Run from the repo root
2. Execute the benchmark command
3. Extract or compute the metric value
4. Print exactly one line: `METRIC <name>=<value>` (plain number, no units)

**Detect the stack first:**

```bash
ls -la
cat package.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('scripts',{}))" 2>/dev/null
ls build.gradle build.gradle.kts settings.gradle Gemfile Podfile Package.swift pyproject.toml go.mod Cargo.toml 2>/dev/null
cat .github/workflows/*.yml 2>/dev/null | head -200
cat .circleci/config.yml 2>/dev/null | head -200
```

The CI config is ground truth — use the command teams actually run, not guesses.

**Stack detection matrix:**

| Signal found | Stack | Likely test command | Likely build command |
|---|---|---|---|
| `build.gradle` / `build.gradle.kts` | Android/Kotlin | `./gradlew test` | `./gradlew assembleDebug` |
| `Package.swift` / `*.xcworkspace` | iOS/Swift | `xcodebuild test -scheme <X>` | `xcodebuild build -scheme <X>` |
| `Gemfile` + `spec/` | Ruby/Rails | `bundle exec rspec` | `bundle exec rake assets:precompile` |
| `package.json` with jest/vitest | JS/TS | `npm test` / `yarn test` | `npm run build` / `yarn build` |
| `pyproject.toml` / `setup.py` | Python | `pytest` | N/A |
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |

**Templates by metric type:**

Build time / test time:
```bash
#!/bin/bash
# autoresearch benchmark — do not modify
set -uo pipefail
START=$(date +%s%N)
<exact command from CI config> 2>&1
END=$(date +%s%N)
echo "METRIC <metric_name>=$(( (END - START) / 1000000 ))"
```

Failing tests:
```bash
#!/bin/bash
# autoresearch benchmark — do not modify
set -uo pipefail
OUTPUT=$(<test command> 2>&1 || true)
printf '%s\n' "$OUTPUT"
COUNT=$(printf '%s\n' "$OUTPUT" | grep -oE '[0-9]+ (failure|failed|error)' | head -1 | grep -oE '^[0-9]+' || echo "0")
echo "METRIC failing_tests=$COUNT"
```

Coverage:
```bash
#!/bin/bash
# autoresearch benchmark — do not modify
set -uo pipefail
OUTPUT=$(<test-with-coverage command> 2>&1 || true)
printf '%s\n' "$OUTPUT"
PCT=$(printf '%s\n' "$OUTPUT" | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -1 | tr -d '%' || echo "0")
echo "METRIC coverage_pct=$PCT"
```

Bundle size:
```bash
#!/bin/bash
# autoresearch benchmark — do not modify
set -uo pipefail
<build command> 2>&1
KB=$(du -sk <dist directory> | cut -f1)
echo "METRIC bundle_kb=$KB"
```

**Research and Docs modes** — write a scoring script instead:

```bash
#!/bin/bash
# autoresearch benchmark — do not modify — evaluates artifact against rubric
set -uo pipefail
# Agent reads the artifact file and scores it against the rubric in autoresearch.md
# Score is printed as METRIC rubric_score=<0-10>
echo "METRIC rubric_score=__AGENT_SCORES_THIS__"
```

For research and docs modes, `autoresearch.sh` is a placeholder. The actual scoring
happens when the agent reads the artifact and self-evaluates against the rubric in
`autoresearch.md`. The agent then prints the score as if the script ran it.

#### Step 1e — Write autoresearch.md

```markdown
# autoresearch session

## Goal
<user's plain-English goal>

## Mode
<engineering | research | docs>

## Stack / Domain
<for engineering: detected stack e.g. "Android / Kotlin / Gradle">
<for research: the topic domain e.g. "Contractor segment / competitive analysis">
<for docs: the artifact type e.g. "Contractor persona / user research doc">

## Metric
- Name: <metric_name or "rubric_score">
- Direction: <lower|higher> is better
- Benchmark: <command or "agent self-evaluation against rubric">

## Rubric
<for research and docs modes — the scoring rubric defined in Step 1c>
<for engineering — omit this section>

## Files in scope
<for engineering: specific source/test/config files>
<for research: web sources, competitor URLs, research docs to synthesize>
<for docs: the specific document file to iterate on>

## Ideas backlog
<generated from Step 1f>

## State
- consecutive_no_improvement: 0
- best_metric: <baseline value>
- target: <parsed from goal, or "none">

## History
<!-- Agent appends after each run: Run N — what was tried — result -->

## Dead ends
<!-- Agent notes here: what failed and why -->
```

#### Step 1f — Generate mode-specific ideas backlog

**Engineering mode** — read the repo's config files and CI config, generate grounded ideas:

Each idea must reference a specific file, property, and expected impact.
No generic advice — only ideas grounded in what exists in this repo.

Android build time ideas (grounded in `gradle.properties` and `build.gradle`):
- Enable Gradle build cache: `org.gradle.caching=true`
- Enable parallel builds: `org.gradle.parallel=true`
- Enable configuration cache: `org.gradle.configuration-cache=true`
- Increase heap: `org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC`
- Remove `clean` from CI command if present

JS/TS test speed ideas:
- Set `--maxWorkers=50%`
- Switch transform from Babel to SWC/esbuild
- Mock heavy imports at module level

Test coverage ideas:
- Find files with 0% coverage, add smoke tests
- Add error/edge case branches
- Use coverage report to rank highest-ROI files

**Research mode** — generate a list of research angles to investigate:

Each idea = one specific question to answer or one source to investigate:
1. Name and describe each direct competitor found via web search
2. Compare pricing models (per-seat, per-job, flat monthly)
3. Extract top-rated features from competitor app store reviews
4. Find common complaints in competitor reviews (feature gaps)
5. Identify which competitors target our specific segment
6. Check if pm-skills `competitor-analysis` skill is installed → invoke it for v1

If pm-skills are installed, the first idea is always: invoke the relevant pm-skill to
generate a structured v1 artifact, then score it against the rubric.

**Docs mode** — generate a list of specific improvements to make to the document:

Each idea = one targeted edit with a hypothesis about which rubric dimension it improves:
1. Add segment size estimate (improves "specifies segment size" rubric criterion)
2. Add a direct quote from user research (improves "includes verbatim quote" criterion)
3. Replace vague adjectives with specific behaviors (improves "behavioral patterns" criterion)
4. Add decision criteria section (improves "decision criteria for buying" criterion)

If pm-skills are installed, the first idea is: invoke the relevant pm-skill to enrich
the draft (e.g. `user-personas`, `customer-journey-map`), then re-score.

#### Step 1g — Run baseline

**Engineering mode:**
```bash
chmod +x autoresearch.sh
bash autoresearch.sh
```
Extract `METRIC name=value`. Log run #0 as `"status": "baseline"`.

**Research mode:**
- If pm-skills `competitor-analysis` or equivalent is installed: invoke it now to produce v1
- Otherwise: run a web search to gather raw data, write a v1 artifact to a file
- Score the v1 artifact against the rubric
- Log run #0 as `"status": "baseline"` with the rubric score

**Docs mode:**
- Read the existing document
- Score it against the rubric
- Log run #0 as `"status": "baseline"` with the rubric score
- If no document exists yet and pm-skills are available, invoke the relevant skill to create v1 first

Then continue to Phase 2.

---

### Phase 2: Main Loop

The autonomous core. Runs until a stopping condition is met or the user types `/autoresearch off`.

#### Stopping conditions (checked at the start of each iteration)

**1. Goal achieved**
Parse the goal for a numeric target ("above 80%", "below 500ms", "zero failures", "score 8+").
If met → go to Phase 5, printing: `GOAL ACHIEVED: <metric> = <value>. Stopping.`

**2. No improvement for 5 consecutive runs**
If `consecutive_no_improvement >= 5` → go to Phase 5, printing:
`CONVERGED: No improvement in last 5 runs. Best: <value>. Stopping.`

**3. Backlog exhausted**
If no untried ideas remain → go to Phase 5, printing:
`BACKLOG EXHAUSTED: All ideas tried. Best: <value>. Stopping.`

**Each iteration:**

**Step 1 — Load context**
Read `autoresearch.md` (goal, mode, metric, rubric, backlog, history, dead ends) and
last 10 lines of `autoresearch.jsonl`. Compute: baseline, best-so-far, run count.

**Step 2 — Pick ONE idea**
Choose the single highest-confidence untried idea:
- Smallest possible change
- Clear causal link to the metric or a specific rubric criterion
- Only touches files in scope
- Not tried before

**Step 3 — Apply it**

**Engineering mode:** make the minimum viable diff to the target file.

**Research mode:** run a web search or fetch a specific URL, synthesize findings into
the research artifact. One new angle per iteration (one new competitor, one new dimension,
one new data source). If a relevant pm-skill is installed, invoke it for this iteration's
focus area rather than doing raw search.

**Docs mode:** make one targeted edit to the document. One paragraph, one section, one
added piece of evidence. If a relevant pm-skill is installed that can enrich this specific
dimension (e.g. `user-personas` to add behavioral patterns), invoke it and incorporate output.

**Step 4 — Score / benchmark**

**Engineering mode:**
```bash
bash autoresearch.sh 2>&1
```
Extract number from `METRIC name=<value>`.

**Research and Docs modes:**
Read the current version of the artifact. Evaluate it against each rubric criterion in
`autoresearch.md`. Assign a score for each criterion and sum them. Print:
```
Rubric evaluation:
  Covers ≥5 named competitors: 2/2 ✓
  Includes pricing: 1/2 (missing 2 competitors)
  ...
  Total: 7/10
METRIC rubric_score=7
```

**Step 5 — Run checks (if present)**
```bash
[ -f autoresearch.checks.sh ] && bash autoresearch.checks.sh 2>&1
```
If checks fail → treat as regression.

**Step 6 — Keep or revert**

For "lower is better": `delta = baseline - new_value`
For "higher is better": `delta = new_value - baseline`

**Improved (delta > 0):**
```bash
git add <changed files>
git commit -m "autoresearch: <description> [<metric>: <old> → <new>]"
```

**Flat or regressed:**
```bash
git checkout -- <changed files>
```

For research/docs modes: if the artifact file got worse or flat, restore the previous
version from git.

**Step 7 — Log**
```json
{"run": N, "commit": "<sha|null>", "metric": <value>, "delta": <delta>, "status": "<kept|reverted>", "description": "<what was tried>", "timestamp": "<ISO8601>"}
```

**Step 8 — Update autoresearch.md**
Move tried idea to History. Add dead end note if reverted. Add new ideas if discovered.

**Step 9 — Print progress**
```
[Run N] <metric>: <prev> → <new> (<±delta>) — <kept|reverted> | Best: <best>
```

Update `## State` block:
- Increment `consecutive_no_improvement` if delta ≤ 0, reset to 0 if delta > 0
- Update `best_metric` if improved

**Step 10 — Check stopping conditions, then reschedule**

Evaluate stopping conditions in order. If none apply:
```
ScheduleWakeup(60)
```

---

### Phase 3: Failing tests mode (engineering sub-mode)

When the goal is about fixing failing/broken tests, each iteration targets ONE test:

1. Run benchmark → parse failing test names from output
2. Pick the first failing test (or most frequently failing)
3. Read the test file to understand the assertion
4. Read the source file / fixture it depends on
5. Apply the minimal fix (wrong expected value, stale mock, missing await, drifted selector)
6. Re-run benchmark → check if `failing_tests` decreased
7. If yes → `git commit`. If no → `git checkout --` and mark as dead end.

**Parser patterns by runner:**
- RSpec: lines matching `rspec ./<path>:<line>`
- Gradle/JUnit: lines matching `FAILED`
- Jest/Vitest: lines matching `✕` or `FAIL <path>`
- XCTest: lines matching `Test Case '...' failed`
- pytest: lines matching `FAILED <path>::<name>`
- Go: lines starting with `--- FAIL:`

---

### Phase 4: Resume

If `autoresearch.md` exists when skill is invoked:
1. Read `autoresearch.md` and `autoresearch.jsonl` to restore context
2. Print: `Resuming: <N> runs | mode: <mode> | best <metric>: <value>`
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
    best = max(kept, key=lambda x: x.get('delta', 0))
    pct = abs(best['delta']) / max(baseline['metric'], 1) * 100
    print(f\"Baseline: {baseline['metric']} -> Best: {best['metric']} ({pct:.1f}% improvement)\")
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
6. **Infer, don't ask.** Read CI config, package.json, build files, and the goal itself before asking anything.
   Use `AskUserQuestion` only when a critical value is genuinely ambiguous after reading the context.
7. **The CI config is ground truth** for engineering mode. Use the command teams actually run.
8. **Ideas must be grounded.** For engineering: reference a specific file and property. For research: reference a specific source or angle. For docs: reference a specific rubric criterion.
9. **Fix one test at a time** in failing-tests mode.
10. **Confidence is advisory.** Never stop an improving loop because of low confidence.
11. **Invoke skills, don't re-invent them.** If a relevant skill (investigate, pm-skills, office-hours) is installed and covers this iteration's focus area, invoke it rather than doing the work manually.
12. **Classify automatically.** Never ask the user to pass a flag or specify the mode. Read the goal and classify.
