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
- `wintermute.config.json` — mode toggle (`portable` vs `full-warp`).
- `tasks/` — one markdown file per task.
- `logs/` and `outputs/` — session logs and synthesis narratives.
- `scripts/` — Wintermute runtime scripts (`run_session.sh`, `run_agent.sh`, `record_warp_session.sh`, `wintermute_mode.py`, `synthesize.py`, `prompt_evaluator.py`, `nr_query.py`, `run_fluent_bit.sh`, `fluent-bit-newrelic.conf`).

## Run in Xcode
1. Open `Bumper.xcodeproj` in Xcode.
2. Select the `Bumper` scheme.
3. Choose an iPhone simulator and run.

To regenerate the project file after editing `project.yml`:

```bash
xcodegen generate --spec project.yml
```

## Wintermute setup
This repo supports two switchable execution modes:
- `portable` (work-safe/agnostic): aider-driven sessions and optional model synthesis
- `full-warp` (POC): run tasks directly in Warp, with manual session close logging

1. Check or switch mode:
   ```bash
   python3 scripts/wintermute_mode.py
   python3 scripts/wintermute_mode.py set portable
   # or
   python3 scripts/wintermute_mode.py set full-warp
   ```
2. Install dependencies:
   ```bash
   pip install aider-chat anthropic
   ```

   Verify anthropic is available in the active environment:
   ```bash
   python3 -c "import anthropic"
   ```

3. Configure credentials (only required when you want model-backed runs/synthesis). Load these from a secrets file — do not export raw keys directly in your shell history:
   ```bash
   export ANTHROPIC_API_KEY=...
   ```
   Optional New Relic event streaming:
   ```bash
   export NEW_RELIC_LICENSE_KEY=...
   export NEW_RELIC_ACCOUNT_ID=...
   export NEW_RELIC_API_KEY=...
   ```
4. Ensure scripts are executable:
   ```bash
   chmod +x scripts/*.sh scripts/*.py
   ```
5. Create or edit task files in `tasks/`.
6. Start a session:
   ```bash
   ./scripts/run_session.sh TASK-001
   ```
   - In `portable` mode, this executes aider via `scripts/run_agent.sh`.
   - In `full-warp` mode, this writes a start event and prints follow-up commands.
7. If running `full-warp`, close the session when done:
   ```bash
   ./scripts/record_warp_session.sh logs/<session>.jsonl TASK-001 done
   ```
8. Synthesize the session:
   ```bash
   python3 scripts/synthesize.py logs/<session>.jsonl
   ```
   - In `portable` mode + API key: dual-pass analysis drafts plus one final consolidated narrative.
   - In `full-warp` mode, or without API key, or without the `anthropic` package: facts-first deterministic narrative (no model call).
9. Optional prompt review:
   ```bash
   python3 scripts/prompt_evaluator.py outputs/<session>-narrative.md
   ```
   If Anthropic access is unavailable, this exits cleanly and you can review `AGENT_PROMPT.md` manually.
10. Optional full line-level logs to New Relic via Fluent Bit sidecar:
   ```bash
   ./scripts/run_fluent_bit.sh
   ```
   Run this in a separate terminal before starting sessions. It tails `logs/*.jsonl` and forwards records with the `newrelic` output plugin.

### Wintermute telemetry now captured
When New Relic credentials are set, Wintermute emits structured `WintermuteEvent` records for:
- Agent lifecycle: `agent_start`, `agent_done`, `agent_error`, `agent_canceled`
- Full-warp lifecycle: `warp_session_start`, `warp_session_done`, `warp_session_error`, `warp_session_canceled`
- Synthesis lifecycle: `synthesis_start`, `synthesis_done`, `synthesis_error`

Each terminal lifecycle event includes monitorable attributes where available:
- `duration_sec`
- `branch`, `head`, `base_ref`, `commits_ahead`, `dirty`
- `output_lines` (portable agent runs)
- `mode`

Review these generated files before acting on recommendations:
- `outputs/<session>-facts.json` (authoritative machine-derived facts)
- `outputs/<session>-narrative-pass-a.md` (analysis draft A, no prompt recommendations)
- `outputs/<session>-narrative-pass-b.md` (analysis draft B, no prompt recommendations)
- `outputs/<session>-narrative.md` (final consolidated narrative; the only file that includes prompt recommendations)
- `outputs/<session>-uncertainty.json` (citation diff/uncertainty report)

## Product notes
- “Automatic payout” is currently represented as a local simulated transfer event.
- Real bank transfer rails, account linking, and compliance workflows are not yet implemented.
