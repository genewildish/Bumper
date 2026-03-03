---
id: TASK-001
status: available
claimed_by: null
claimed_at: null
---

# TASK-001: Define bank transfer integration boundary

## What to build
Create a clear interface boundary for future real transfer rails by introducing a protocol/service abstraction for payout execution, while preserving the current simulated payout behavior.

## Acceptance criteria
- [ ] A protocol (or equivalent abstraction) exists for payout execution.
- [ ] Existing simulated payout behavior still works end-to-end.
- [ ] Existing `PayoutProcessorTests` still pass.

## Context
- Real bank transfer rails are not implemented yet.
- Current payout behavior is local/simulated and should remain default-safe.
- Keep scope to domain/service boundaries; avoid broad UI refactors.

## Agent Notes
<!-- Agents append notes here — do not edit above this line -->
