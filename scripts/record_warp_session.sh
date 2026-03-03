#!/bin/bash
# Usage: ./scripts/record_warp_session.sh logs/<session>.jsonl TASK-001 done
# Appends a terminal event to a full-warp session log.

set -u

LOG_FILE=${1:-}
TASK=${2:-TASK-001}
STATUS=${3:-done}

if [[ -z "$LOG_FILE" ]]; then
  echo "Usage: ./scripts/record_warp_session.sh logs/<session>.jsonl TASK-001 <done|error|canceled>"
  exit 2
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE"
  exit 1
fi

case "$STATUS" in
  done|error|canceled) ;;
  *)
    echo "Invalid status: $STATUS (use done|error|canceled)"
    exit 2
    ;;
esac

BASE_REF=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')
BASE_REF=${BASE_REF:-origin/main}
COMMITS=$(git --no-pager log --oneline "${BASE_REF}..HEAD" 2>/dev/null | wc -l | tr -d ' ')

# New Relic event helper
nr_event() {
  EVENT_TYPE=$1
  PAYLOAD=$2
  SESSION_ID=$3
  if [[ -z "${NEW_RELIC_LICENSE_KEY:-}" || -z "${NEW_RELIC_ACCOUNT_ID:-}" ]]; then
    return 0
  fi
  curl -s -X POST "https://insights-collector.newrelic.com/v1/accounts/${NEW_RELIC_ACCOUNT_ID}/events" \
    -H "Api-Key: ${NEW_RELIC_LICENSE_KEY}" \
    -H "Content-Type: application/json" \
    -d "[{\"eventType\":\"WintermuteEvent\",\"event\":\"${EVENT_TYPE}\",\"agent\":\"warp-manual\",\"task\":\"${TASK}\",\"session\":\"${SESSION_ID}\",\"project\":\"$(basename "$(pwd)")\",${PAYLOAD:1}}]" \
    > /dev/null || true
}

SESSION_ID=$(basename "$LOG_FILE" .jsonl)
EVENT="warp_session_${STATUS}"
echo "{\"event\":\"$EVENT\",\"agent\":\"warp-manual\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":{\"commits\":$COMMITS,\"mode\":\"full-warp\"}}" >> "$LOG_FILE"
nr_event "$EVENT" "{\"commits\":$COMMITS,\"mode\":\"full-warp\"}" "$SESSION_ID"

echo "Recorded $EVENT to $LOG_FILE (commits since ${BASE_REF}: $COMMITS)"
