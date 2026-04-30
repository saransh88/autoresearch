# autoresearch session

## Goal
Reduce Gradle assembleDebug build time below 3 minutes

## Stack
Android / Kotlin / Gradle

## Metric
- Name: build_ms
- Direction: lower is better
- Benchmark command: `bash autoresearch.sh`

## Files in scope
- `gradle.properties`
- `build.gradle` (root)
- `app/build.gradle`

## State
- consecutive_no_improvement: 0
- best_metric: 247000
- target: 180000

## Ideas backlog
1. Enable Gradle build cache: `org.gradle.caching=true` in gradle.properties
2. Enable parallel builds: `org.gradle.parallel=true` in gradle.properties
3. Enable configuration cache: `org.gradle.configuration-cache=true`
4. Increase heap: `org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC`
5. Remove `clean` from the CI assemble command if present

## History
- Run 1: Added `org.gradle.caching=true` — build_ms: 247000 → 198000 (−49s) — kept
- Run 2: Added `org.gradle.parallel=true` — build_ms: 198000 → 171000 (−27s) — kept ✓ GOAL MET

## Dead ends
<!-- none yet -->
