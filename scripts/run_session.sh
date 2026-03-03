#!/bin/bash
# Usage: ./scripts/run_session.sh TASK-001
# Mode-aware session entrypoint:
# - portable: runs scripts/run_agent.sh (aider-driven)
# - full-warp: logs session start and prints Warp-native instructions

set -u

TASK=${1:-TASK-001}
MODE=$(python3 scripts/wintermute_mode.py get 2>/dev/null || echo "portable")

if [[ ! -f "tasks/${TASK}.md" ]]; then
  echo "Task file not found: tasks/${TASK}.md"
  exit 1
fi

if [[ "$MODE" == "portable" ]]; then
  exec ./scripts/run_agent.sh "$TASK"
fi

if [[ "$MODE" == "full-warp" ]]; then
  SESSION_ID=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  AGENT_ID="warp-manual-$$"
  LOG_FILE="logs/${SESSION_ID//:/}.jsonl"
  mkdir -p logs
  echo "{\"event\":\"warp_session_start\",\"agent\":\"$AGENT_ID\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":{\"mode\":\"full-warp\"}}" >> "$LOG_FILE"

  echo "Mode: full-warp"
  echo "Session log: $LOG_FILE"
  echo ""
  echo "Next:"
  echo "1) Execute TASK with Warp directly (no aider wrapper): tasks/${TASK}.md"
  echo "2) After you finish, close the session log:"
  echo "   ./scripts/record_warp_session.sh \"$LOG_FILE\" \"$TASK\" done"
  echo ""
  echo "If the task fails/cancels, use:"
  echo "   ./scripts/record_warp_session.sh \"$LOG_FILE\" \"$TASK\" error"
  echo "   ./scripts/record_warp_session.sh \"$LOG_FILE\" \"$TASK\" canceled"
  exit 0
fi

echo "Unknown mode: $MODE"
echo "Set mode with: python3 scripts/wintermute_mode.py set <portable|full-warp>"
exit 2
