#!/bin/bash
# autoresearch benchmark — do not modify
# Measures: Stryker mutation score percentage
set -uo pipefail

OUTPUT=$(npx --yes -p @stryker-mutator/core@latest -p @stryker-mutator/jest-runner@latest \
  stryker run stryker.config.mjs 2>&1 || true)
printf '%s\n' "$OUTPUT"

# Extract "All files | XX.XX |" from Stryker's table output
PCT=$(printf '%s\n' "$OUTPUT" | grep 'All files' | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0")
echo "METRIC mutation_pct=$PCT"
