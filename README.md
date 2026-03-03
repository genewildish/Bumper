# Bumper
Bumper is an iOS app for tallying small debts between friends or family, then automatically paying them out once an agreed threshold is reached.

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
- `WARP.md` — project context used by Wintermute agents.
- `AGENT_PROMPT.md` — shared worker prompt for aider sessions.
- `tasks/` — one markdown file per task.
- `logs/` and `outputs/` — session logs and synthesis narratives.
- `scripts/` — Wintermute runtime scripts (`run_agent.sh`, `synthesize.py`, `prompt_evaluator.py`, `nr_query.py`).

## Run in Xcode
1. Open `Bumper.xcodeproj` in Xcode.
2. Select the `Bumper` scheme.
3. Choose an iPhone simulator and run.

To regenerate the project file after editing `project.yml`:

```bash
xcodegen generate --spec project.yml
```

## Wintermute setup
This repo is scaffolded for Wintermute Home Edition (Warp + aider + JSONL logs + synthesis).

1. Install dependencies for local agent runs:
   ```bash
   pip install aider-chat anthropic
   ```
2. Configure Anthropic credentials:
   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...
   ```
   Optional New Relic event streaming:
   ```bash
   export NEW_RELIC_LICENSE_KEY=...
   export NEW_RELIC_ACCOUNT_ID=...
   export NEW_RELIC_API_KEY=...
   ```
3. Ensure the agent runner is executable:
   ```bash
   chmod +x scripts/run_agent.sh
   ```
4. Create or edit task files in `tasks/`.
5. Run one agent session:
   ```bash
   ./scripts/run_agent.sh TASK-001
   ```
6. Synthesize the session log:
   ```bash
   python3 scripts/synthesize.py logs/<session>.jsonl
   ```

## Product notes
- “Automatic payout” is currently represented as a local simulated transfer event.
- Real bank transfer rails, account linking, and compliance workflows are not yet implemented.
