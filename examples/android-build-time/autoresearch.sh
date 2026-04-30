#!/bin/bash
# autoresearch benchmark — do not modify
# Measures: Android assembleDebug build time in milliseconds
set -uo pipefail

START=$(date +%s%N)
./gradlew assembleDebug 2>&1
END=$(date +%s%N)

echo "METRIC build_ms=$(( (END - START) / 1000000 ))"
