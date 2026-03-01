# Bumper
Bumper is a fun and friendly iOS app for tallying small debts between friends or family, then automatically paying them out once an agreed threshold is reached.

## What Bumper does
- Track named micro-debts (for example: `Pinball machine games`).
- Use a one-tap debt increment button labeled `Bump $amount`.
- Keep each increment in the micro-debt range (capped at $5.00 per bump).
- Trigger automatic payout when the running balance meets or exceeds the debtor/creditor threshold (default $25.00).
- Let users choose monetization mode:
  - Upfront fee
  - Per-transaction fee
  - Advertisements

## Current implementation
- SwiftUI iOS app scaffold generated with XcodeGen (`Bumper.xcodeproj`).
- Core domain models for debts, payout events, and app settings.
- Local persistence to app support storage via JSON.
- Auto-payout logic implemented and covered by unit tests.

## Project layout
- `Bumper/` — App source code (models, views, store, services, assets).
- `BumperTests/` — Unit tests for payout behavior.
- `project.yml` — XcodeGen spec to regenerate `Bumper.xcodeproj`.
- `AGENT_PROMPT.md` and `PROGRESS.md` — Metamorph collaboration context files.

## Run in Xcode
1. Open `Bumper.xcodeproj` in Xcode.
2. Select the `Bumper` scheme.
3. Choose an iPhone simulator and run.

To regenerate the project file after editing `project.yml`:

```bash
xcodegen generate --spec project.yml
```

## Metamorph setup
This repo includes Metamorph-friendly prompt/progress files.

1. Install Metamorph (from upstream docs):
   ```bash
   go install github.com/robmorgan/metamorph@latest
   ```
2. Register this repository as a Metamorph project:
   ```bash
   metamorph project create .
   ```
3. Add tasks and start agents:
   ```bash
   metamorph task add "Build bank transfer integration prototype"
   metamorph start
   ```

Note: Metamorph stores project runtime configuration in `~/.metamorph/projects/<project-name>/config.json`.

## Product notes
- “Automatic payout” is currently represented as a local simulated transfer event.
- Real bank transfer rails, account linking, and compliance workflows are not yet implemented.
