# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview
Bumper is an iOS SwiftUI app (iOS 17+) for tracking micro-debts between friends. Users track small debts with a one-tap "Bump $amount" button. When the balance reaches a threshold (default $25), the app triggers an automatic payout (currently simulated locally).

## Build and Test Commands

### Generate Xcode project
```bash
xcodegen generate --spec project.yml
```
Run this after editing `project.yml` to regenerate `Bumper.xcodeproj`.

### Run tests
Open `Bumper.xcodeproj` in Xcode, select the `Bumper` scheme, and run tests via Xcode UI (Cmd+U).

Note: Command-line `xcodebuild` validation is blocked due to local environment limitations.

## Architecture

### Core Flow
1. User creates a `MicroDebt` with a name, increment amount (capped at $5), and payout threshold
2. Each "bump" increments the debt balance by the increment amount
3. `PayoutProcessor.bump()` checks if balance ≥ threshold and triggers a `PayoutEvent` if true
4. Balance resets to zero after payout; payout amount equals the full pre-payout balance

### Key Components
- **Models** (`Bumper/Models/`): Domain types
  - `MicroDebt`: Represents a named debt with balance, threshold, and payout history
  - `PayoutEvent`: Records automatic payout details (amount, timestamp, note)
  - `AppSettings`: Stores debtor/creditor names, default threshold, monetization option

- **ViewModels** (`Bumper/ViewModels/`): State management
  - `DebtStore`: Observable store managing debt collection, persistence to JSON, and bump actions. Seeds with a default "Pinball machine games" debt on first launch.

- **Services** (`Bumper/Services/`):
  - `PayoutProcessor`: Pure function that mutates a debt in-place and returns `.paidOut(event)` or `.none`
  - `Formatting`: Currency/date formatting utilities

- **Views** (`Bumper/Views/`): SwiftUI presentation layer
  - `ContentView`: Main list of debts
  - `DebtCardView`: Individual debt card with bump button
  - `AddDebtSheetView`: Sheet for creating new debts

### Persistence
State is persisted as JSON to `~/Library/Application Support/Bumper/state.json` (or equivalent per platform). The `DebtStore` uses ISO8601 date encoding and pretty-printed, sorted-key JSON.

### Payout Logic
`PayoutProcessor.bump()` uses a floating-point tolerance (`balance + 0.000_001 >= threshold`) to handle rounding. Payouts capture the entire balance, not just the threshold amount.

## Development Conventions
- **Language**: Keep UI text friendly and simple
- **Terminology**: Always use "Bump $amount" for the debt increment action
- **Constraints**: Per-bump increments are clamped between $0.25 and $5.00
- **Thresholds**: Minimum payout threshold is $5.00
- **Commit style**: Small, focused commits; avoid unrelated refactors

## Wintermute Agent Loop
- Set/check mode with `python3 scripts/wintermute_mode.py` and `python3 scripts/wintermute_mode.py set <portable|full-warp>`.
- Preflight model-backed synthesis dependencies before running synthesis-related scripts:
  - Verify package import: `python3 -c "import anthropic"`
  - If missing, install in the active env: `python3 -m pip install anthropic`
  - Re-run the import check before continuing.
- `WARP.md` is the project context file for agent sessions.
- `AGENT_PROMPT.md` is the shared worker system prompt for aider runs.
- `tasks/TASK-NNN.md` files are the source of truth for available and claimed work.
- `scripts/run_session.sh TASK-001` is the mode-aware session entrypoint.
  - `portable` mode routes to `scripts/run_agent.sh` (aider flow).
  - `full-warp` mode logs a start event and expects manual task execution in Warp; close with `scripts/record_warp_session.sh`.
- `scripts/synthesize.py logs/<session>.jsonl` produces analysis pass files plus a final narrative in `outputs/`; prompt recommendations are included only in `outputs/<session>-narrative.md`.
  - Model-backed synthesis is mode-agnostic and requires both `ANTHROPIC_API_KEY` and the `anthropic` Python package.
  - If configured mode and log-inferred mode differ, the script prints a warning and continues.
- `scripts/nr_query.py <session_id>` fetches `WintermuteEvent` timeline from New Relic when API credentials are configured.
- Optional sidecar log shipping to New Relic Logs is provided by `scripts/run_fluent_bit.sh` with config `scripts/fluent-bit-newrelic.conf` (tail input on `logs/*.jsonl`, `newrelic` output).
