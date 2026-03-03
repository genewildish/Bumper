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
  
  # New Relic event helper
  nr_event() {
    EVENT_TYPE=$1
    PAYLOAD=$2
    if [[ -z "${NEW_RELIC_LICENSE_KEY:-}" || -z "${NEW_RELIC_ACCOUNT_ID:-}" ]]; then
      return 0
    fi
    curl -s -X POST "https://insights-collector.newrelic.com/v1/accounts/${NEW_RELIC_ACCOUNT_ID}/events" \
      -H "Api-Key: ${NEW_RELIC_LICENSE_KEY}" \
      -H "Content-Type: application/json" \
      -d "[{\"eventType\":\"WintermuteEvent\",\"event\":\"${EVENT_TYPE}\",\"agent\":\"${AGENT_ID}\",\"task\":\"${TASK}\",\"session\":\"${SESSION_ID}\",\"project\":\"$(basename "$(pwd)")\",${PAYLOAD:1}}]" \
      > /dev/null || true
  }
  
  echo "{\"event\":\"warp_session_start\",\"agent\":\"$AGENT_ID\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":{\"mode\":\"full-warp\"}}" >> "$LOG_FILE"
  nr_event "warp_session_start" "{\"mode\":\"full-warp\"}"

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
