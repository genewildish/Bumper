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

git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

git_head() {
  git rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

git_dirty() {
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

git_base_ref() {
  local base
  base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')
  echo "${base:-origin/main}"
}

git_commits_ahead() {
  local base_ref
  base_ref=$(git_base_ref)
  git --no-pager log --oneline "${base_ref}..HEAD" 2>/dev/null | wc -l | tr -d ' '
}

BASE_REF=$(git_base_ref)
COMMITS=$(git_commits_ahead)

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
START_TS=$(python3 - "$LOG_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
start_ts = 0
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except Exception:
            continue
        if event.get("event") == "warp_session_start":
            ts = event.get("ts")
            if isinstance(ts, int):
                start_ts = ts
            break
print(start_ts)
PY
)
NOW_TS=$(date +%s)
DURATION=0
if [[ "${START_TS}" =~ ^[0-9]+$ ]] && [[ "${START_TS}" -gt 0 ]]; then
  DURATION=$((NOW_TS - START_TS))
fi
EVENT="warp_session_${STATUS}"
PAYLOAD="{\"commits\":$COMMITS,\"mode\":\"full-warp\",\"duration_sec\":${DURATION},\"branch\":\"$(git_branch)\",\"head\":\"$(git_head)\",\"base_ref\":\"${BASE_REF}\",\"commits_ahead\":$(git_commits_ahead),\"dirty\":$(git_dirty)}"
echo "{\"event\":\"$EVENT\",\"agent\":\"warp-manual\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":${PAYLOAD}}" >> "$LOG_FILE"
nr_event "$EVENT" "$PAYLOAD" "$SESSION_ID"

echo "Recorded $EVENT to $LOG_FILE (commits since ${BASE_REF}: $COMMITS)"
