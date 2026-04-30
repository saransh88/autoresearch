# autoresearch session

## Goal
Improve RSpec coverage above 85% on app/services/

## Stack
Ruby on Rails / RSpec / SimpleCov

## Metric
- Name: coverage_pct
- Direction: higher is better
- Benchmark command: `bash autoresearch.sh`
- Baseline: 61.2%

## Target
85% coverage on app/services/

## Files in scope
New spec files only — write to `spec/services/` mirroring app/services/.
- `app/services/` — business logic, highest ROI
- Focus on services with 0–40% coverage first

## Strategy
1. Services with 0% coverage and no external dependencies — pure Ruby, fast wins
2. Services with HTTP calls — mock with WebMock/VCR
3. Services with ActiveJob — use ActiveJob::TestHelper

## Ideas backlog
1. spec/services/invoice_calculator_spec.rb — pure calculations, 0% coverage
2. spec/services/tax_rate_service_spec.rb — 0% coverage, testable with fixtures
3. spec/services/notification_service_spec.rb — mock ActionMailer
4. spec/services/payment_processor_spec.rb — mock Stripe with WebMock
5. spec/services/pdf_generator_spec.rb — test output structure, mock wkhtmltopdf

## State
- consecutive_no_improvement: 0
- best_metric: 61.2
- target: 85

## History
<!-- Agent appends after each run -->

## Dead ends
<!-- Agent notes here: what failed and why -->
