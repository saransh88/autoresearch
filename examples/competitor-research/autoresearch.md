# autoresearch session

## Goal
Identify top 5 features to build for the contractor invoicing segment based on competitor gaps

## Mode
research

## Domain
Contractor invoicing / field service software — competitive analysis

## Metric
- Name: rubric_score
- Direction: higher is better
- Benchmark: agent self-evaluation against rubric

## Rubric
Rubric (score 0–10):
- Covers ≥5 named direct competitors with brief description: +2
- Includes pricing model for each (free/paid/per-seat/per-job): +2
- Lists top 3 differentiators per competitor (from their own marketing or reviews): +2
- Identifies feature gaps vs our product based on competitor reviews: +2
- Ranks the top 5 features to build with evidence for each: +2

## Files in scope
- competitor-analysis.md (artifact written by agent, iterated each run)

## Ideas backlog
1. [DONE] Use pm-skills competitor-analysis to generate v1 from web search — establishes named competitors + baseline pricing
2. [DONE] Fetch App Store / Google Play reviews for top 3 competitors — extract recurring praise and complaints
3. Search G2/Capterra reviews for "wished it had" and "missing" keywords per competitor
4. Find pricing pages directly — extract exact tier pricing and seat limits
5. Identify which competitors serve our segment (contractors <50 employees) vs enterprise
6. Map feature matrix: invoicing, scheduling, quoting, payments, mobile, integrations

## State
- consecutive_no_improvement: 0
- best_metric: 7
- target: 8

## History
- Run 0 (baseline): Generated v1 from web search — 4 competitors named, no pricing, no reviews — score 3/10
- Run 1: Added pricing for all 4 competitors + found 5th competitor — score 5/10 (+2) — kept
- Run 2: Fetched App Store reviews for top 3 — extracted top complaints — score 7/10 (+2) — kept
- Run 3: Added G2 "missing features" quotes per competitor — score 7/10 (0) — reverted
- Run 4: Tightened feature gap analysis, ranked top 5 features with evidence — score 8/10 (+1) — kept ✓ GOAL MET

## Dead ends
- Run 3: G2 quotes added volume but not specificity — rubric "ranks top 5 with evidence" criterion not met
  because the quotes were vague. Need to synthesize into a ranked list, not just append quotes.
