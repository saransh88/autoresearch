# autoresearch session

## Goal
Improve Stryker mutation score above 75% on src/modules/ Redux reducers

## Stack
React / JavaScript / Jest / Stryker Mutator v9

## Metric
- Name: mutation_pct
- Direction: higher is better
- Benchmark command: `bash autoresearch.sh`
- Baseline: 57.6%

## Target
75% mutation score

## Files in scope
Test files only — write to `src/tests/modules/` mirroring source.
Source files under mutation (never edited): `src/modules/*/reducer.js`

## What mutation score means
Statement coverage tells you which lines ran. Mutation score tells you
whether the tests actually catch bugs. Stryker introduces small code changes
(mutants) and checks if your tests fail. If tests still pass with a bug
present — that's a surviving mutant and a gap in your assertions.

## Ideas backlog

### Category: StringLiteral survivors (action type names)
1. Add `expect(result.type).toBe('app/module/action/fulfilled')` to all thunk success tests
   — kills StringLiteral mutants that blank out the Redux action type string

### Category: EqualityOperator survivors (errors boundary)
2. Add `{ data: { errors: [] } }` test per thunk and assert it resolves (not rejects)
   — kills `errors.length > 0` → `>= 0` mutants

### Category: OptionalChaining survivors (error paths)
3. Add `mockRejectedValue({ response: null })` tests per thunk
   — kills `error?.response.data` mutants (removes ?. before .data)
   — IMPORTANT: assert the payload value, not just result.type
     - modules using `|| error` fallback → `expect(result.payload).toHaveProperty('response')`
     - modules with no fallback → `expect(result.payload).toBeUndefined()`

4. Add `mockRejectedValue({ response: { data: null } })` tests per thunk
   — kills `error?.response?.data.error` mutants (removes ?. before .error)

### Category: ArrowFunction survivors (reducer pending handlers)
5. Add reducer tests that dispatch the pending action and assert state resets to initialState
   — kills `() => initialState` → `() => undefined` mutants

### Category: ObjectLiteral survivors (gateway call arguments)
6. Upgrade `.toHaveBeenCalled()` to `.toHaveBeenCalledWith(userId, expectedPayload)`
   — kills mutants that replace the data object passed to the gateway

## State
- consecutive_no_improvement: 0
- best_metric: 85.25
- target: 75

## History
- Run 1: Added result.type assertions to all thunks — 57.6% → 58.78% (+1.18pp) — kept
- Run 2: toHaveBeenCalledWith + empty errors[] tests — 58.78% → 62.76% (+3.98pp) — kept
- Run 3: {data:null} graceful handling tests — 62.76% → 65.57% (+2.81pp) — kept
- Run 4: reducer tests (pending state, field mapping) — 65.57% → 67.45% (+1.88pp) — kept
- Run 5: taxes/socialLinks reducer tests — 67.45% → 69.56% (+2.11pp) — kept
- Run 6: attachments reducer — 69.56% → 70.49% (+0.93pp) — kept
- Run 7: reviews reducer — 70.49% → 70.96% (+0.47pp) — kept
- Run 8: null meta.arg tests, v9 error format — 70.96% → 72.60% (+1.64pp) — kept
- Run 9: {response:null} tests all modules — 72.60% → 73.54% (+0.94pp) — kept
- Run 10: v9 error blocks for deleteTax — 73.54% → 74.94% (+1.40pp) — kept
- Run 11: comprehensive null data/response batch — 74.94% → 77.99% (+3.05pp) — kept
- Run 12: type-only assertions on null response — 77.99% → 77.99% (0pp) — reverted
- Run 13: investigation: confirmed type alone insufficient — reverted
- Run 14: fixed payload assertions per error-path matrix — 77.99% → 80.33% (+2.34pp) — kept
- Run 15: {response:{data:null}} + reducer boundary tests — 80.33% → 85.25% (+4.92pp) — kept ✓ GOAL MET

## Dead ends
- Type-only assertions on null response tests (runs 12–13): asserting only `result.type`
  when mocking `{ response: null }` does not distinguish the mutant from the original —
  both produce a rejected action with the same type. Must assert the payload value.
  Key insight: the correct assertion depends on the error-path pattern in the thunk:
    - `|| error` fallback → payload = error object → toHaveProperty('response')
    - no fallback → payload = undefined → toBeUndefined()
    - parseGatewayError fallback → payload = string → typeof === 'string'
