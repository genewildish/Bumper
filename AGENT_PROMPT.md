# Project Instructions
You are working on Bumper, an iOS SwiftUI app for friendly micro-debts.

## Product intent
- Bumper tracks tiny debts (typically less than $5 per bump) between a debtor and creditor.
- Each debt has:
  - Name
  - Increment amount (`Bump $amount`)
  - Payout threshold
- Once threshold is reached, debt auto-pays (simulated transfer event).

## Build & test
- Generate project: `xcodegen generate --spec project.yml`
- Open project: `Bumper.xcodeproj`
- Target: `Bumper` (iOS 17+)
- Tests: `BumperTests`

## Architecture
- `Bumper/Models`: domain types (`MicroDebt`, `PayoutEvent`, `AppSettings`)
- `Bumper/ViewModels`: state and persistence (`DebtStore`)
- `Bumper/Services`: payout and formatting logic
- `Bumper/Views`: SwiftUI presentation

## Working conventions
- Keep UI language friendly and simple.
- Preserve `Bump $amount` as the debt increment action text.
- Keep per-bump increments constrained to micro-debt values.
- Prefer small, focused commits and avoid unrelated refactors.
