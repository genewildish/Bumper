---
id: TASK-002
status: available
claimed_by: null
claimed_at: null
---

# TASK-002: Add DebtStore persistence and reload regression tests

## What to build
Add focused unit tests for `DebtStore` persistence behavior so state survives app restarts and remains compatible with the current JSON format. Cover add/remove/bump flows and settings persistence using an isolated temporary `storageURL`.

## Acceptance criteria
- [ ] A new test file verifies that debts and settings persist to disk and restore correctly when a new `DebtStore` is initialized with the same `storageURL`.
- [ ] Tests verify persistence for at least:
  - [ ] adding a debt
  - [ ] removing a debt
  - [ ] bumping a debt (including a payout-triggering bump path)
- [ ] Tests verify current fallback behavior for missing/invalid state data (no crash; defaults/seed behavior preserved).
- [ ] Existing `PayoutProcessorTests` continue to pass.

## Context
- `TASK-001` introduced a payout execution boundary; this task hardens persistence guarantees around that domain behavior.
- `DebtStore` is the app state hub and writes `PersistedState` JSON with ISO8601 dates.
- Keep persistence format backward compatible unless migration is explicitly added to scope.
- Keep payout semantics unchanged (`balance + 0.000_001 >= threshold`, payout of full current balance).

## Agent Notes
<!-- Agents append notes here — do not edit above this line -->
