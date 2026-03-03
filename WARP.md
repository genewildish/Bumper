# Project: Bumper

## What This Is
Bumper is an iOS SwiftUI app for tracking small debts between friends/family and auto-paying them out once the running balance reaches a configured threshold.
The core user action is a one-tap "Bump $amount" increment on each debt.

## Architecture
- `Bumper/BumperApp.swift` launches `ContentView`.
- `Bumper/ViewModels/DebtStore.swift` is the state hub (`@MainActor`, `ObservableObject`) for debt CRUD, bump actions, and JSON persistence.
- `Bumper/Services/PayoutProcessor.swift` is pure domain logic: each bump increments balance, and when threshold is met/crossed it creates a `PayoutEvent`, resets balance to zero, and increments `totalPaidOut`.
- `Bumper/Models/` holds core types: `MicroDebt`, `PayoutEvent`, `AppSettings`, `MonetizationOption`.
- `Bumper/Views/` renders the UI (`ContentView`, `DebtCardView`, `AddDebtSheetView`) using `DebtStore`.
- `BumperTests/PayoutProcessorTests.swift` validates threshold behavior (below threshold, at threshold, crossing threshold).

## Conventions
- Preserve user-facing copy around bumping: use "Bump $amount".
- Per-bump increment must stay in micro-debt range (`$0.25...$5.00`), enforced in store/model logic.
- Minimum payout threshold is `$5.00`.
- Keep commits focused and avoid unrelated refactors.
- Prefer behavior-driven tests for meaningful flows; use targeted unit tests for isolated logic.

## Constraints
- Do not change payout semantics without an explicit task:
  - payout triggers when `balance + 0.000_001 >= payoutThreshold`
  - payout amount is the full pre-reset balance (not just the threshold delta).
- Keep persistence format compatible with current `DebtStore` JSON state unless migration is part of the task.
- iOS build/test is Xcode-centric in this repo; command-line `xcodebuild` validation may be unavailable in some local environments.

## Current State
- Done:
  - SwiftUI scaffold and XcodeGen setup
  - micro-debt models and local JSON persistence
  - threshold-triggered payout logic
  - unit tests for payout processor scenarios
- In progress:
  - bank transfer provider integration (not yet implemented)
  - UI polish (icons/design)

## Task File Format
Each task lives in tasks/TASK-NNN.md with this header:
---
id: TASK-NNN
status: available | in_progress | completed | abandoned
claimed_by: null | agent-N
claimed_at: null | ISO timestamp
---
Agents update this header when claiming and completing tasks.
Agent notes go below the header as append-only entries.
