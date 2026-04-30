#!/bin/bash
# autoresearch benchmark — do not modify
# Measures: Jest statement coverage percentage
set -uo pipefail

OUTPUT=$(yarn test --coverage --coverageReporters=text-summary --watchAll=false 2>&1 || true)
printf '%s\n' "$OUTPUT"

PCT=$(printf '%s\n' "$OUTPUT" | grep 'Statements' | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0")
echo "METRIC coverage_pct=$PCT"
