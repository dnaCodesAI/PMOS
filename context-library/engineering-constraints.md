# Engineering constraints — #abc-bank-prd-review

Captured from Touch Infinity Slack channel `#abc-bank-prd-review`.

## Sairam — Jun 27, 2026

> I want to avoid data migration at all costs

## Sairam — May 15, 2026

> Core banking API rate limit is 50 req/min per customer session — hard limit, can't change before Q3. Any real-time goal tracking feature will need async processing and local state management.

## PRD implications

- No schema migration or backfill — derive pace from existing fields only; degrade gracefully if legacy data incomplete
- 50 req/min core banking ceiling until Q3 — no live balance API on goal detail load
- Snapshot store + async refresh (15 min active / hourly idle)
- Client-side pace recompute; manual refresh only explicit core API touch
- Stale threshold 30 minutes (not 24 hours)
- Stalled status from snapshot deposit signal, not live poll
