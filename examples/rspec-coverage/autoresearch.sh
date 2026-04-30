#!/bin/bash
# autoresearch benchmark — do not modify
# Measures: RSpec coverage percentage via SimpleCov
set -uo pipefail

OUTPUT=$(bundle exec rspec spec/services/ --format progress 2>&1 || true)
printf '%s\n' "$OUTPUT"

PCT=$(printf '%s\n' "$OUTPUT" | grep 'covered' | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0")
echo "METRIC coverage_pct=$PCT"
