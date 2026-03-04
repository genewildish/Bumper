#!/bin/bash
# Usage: ./scripts/run_agent.sh TASK-001
# Runs an aider worker on the given task and logs everything to JSONL.

set -u

TASK=${1:-TASK-001}
MODE=$(python3 scripts/wintermute_mode.py get 2>/dev/null || echo "portable")
if [[ "$MODE" != "portable" ]]; then
  echo "Current mode is '$MODE'. scripts/run_agent.sh only runs in portable mode."
  echo "Use ./scripts/run_session.sh $TASK or switch mode:"
  echo "  python3 scripts/wintermute_mode.py set portable"
  exit 2
fi
if [[ ! -f "tasks/${TASK}.md" ]]; then
  echo "Task file not found: tasks/${TASK}.md"
  exit 1
fi

SESSION_ID=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AGENT_ID="agent-$$"
LOG_FILE="logs/${SESSION_ID//:/}.jsonl"
START_TS=$(date +%s)

mkdir -p logs
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

log_event() {
  echo "{\"event\":\"$1\",\"agent\":\"$AGENT_ID\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":$2}" >> "$LOG_FILE"
}
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
START_PAYLOAD="{\"mode\":\"${MODE}\",\"branch\":\"$(git_branch)\",\"head\":\"$(git_head)\",\"base_ref\":\"$(git_base_ref)\",\"commits_ahead\":$(git_commits_ahead),\"dirty\":$(git_dirty)}"
log_event "agent_start" "$START_PAYLOAD"
nr_event "agent_start" "$START_PAYLOAD"

on_cancel() {
  END_TS=$(date +%s)
  DURATION=$((END_TS - START_TS))
  CANCEL_PAYLOAD="{\"mode\":\"${MODE}\",\"duration_sec\":${DURATION},\"branch\":\"$(git_branch)\",\"head\":\"$(git_head)\",\"base_ref\":\"$(git_base_ref)\",\"commits_ahead\":$(git_commits_ahead),\"dirty\":$(git_dirty)}"
  log_event "agent_canceled" "$CANCEL_PAYLOAD"
  nr_event "agent_canceled" "$CANCEL_PAYLOAD"
  echo ""
  echo "Session canceled. Log: $LOG_FILE"
  exit 130
}

trap on_cancel INT TERM
PROMPT_ENV_FILE=${PROMPT_ENV_FILE:-.agent_prompt.env}
if [[ -f "$PROMPT_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PROMPT_ENV_FILE"
  set +a
fi

SYSTEM_PROMPT=$(python3 - <<'PY'
import os
import re
from pathlib import Path

text = Path("AGENT_PROMPT.md").read_text(encoding="utf-8")
pattern = re.compile(r"\$\{(REC_[A-Z0-9_]+)\}")

def replace(match):
    key = match.group(1)
    return os.environ.get(key, match.group(0))

print(pattern.sub(replace, text), end="")
PY
)

aider \
  --model claude-haiku-4-5-20251001 \
  --system-prompt "$SYSTEM_PROMPT" \
  --message "$(cat tasks/${TASK}.md)" \
  --yes-always \
  --no-auto-commits \
  2>&1 | while IFS= read -r line; do
    log_event "output" "$(printf "%s" "$line" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
    echo "$line"
  done

AIDER_EXIT=${PIPESTATUS[0]}
if [[ $AIDER_EXIT -ne 0 ]]; then
  END_TS=$(date +%s)
  DURATION=$((END_TS - START_TS))
  OUTPUT_LINES=$(grep -c '"event":"output"' "$LOG_FILE" 2>/dev/null || echo 0)
  ERROR_PAYLOAD="{\"exit_code\":$AIDER_EXIT,\"mode\":\"${MODE}\",\"duration_sec\":${DURATION},\"output_lines\":${OUTPUT_LINES},\"branch\":\"$(git_branch)\",\"head\":\"$(git_head)\",\"base_ref\":\"$(git_base_ref)\",\"commits_ahead\":$(git_commits_ahead),\"dirty\":$(git_dirty)}"
  log_event "agent_error" "$ERROR_PAYLOAD"
  nr_event "agent_error" "$ERROR_PAYLOAD"
  echo ""
  echo "Session log: $LOG_FILE"
  exit $AIDER_EXIT
fi
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
BASE_REF=$(git_base_ref)
COMMITS=$(git_commits_ahead)
OUTPUT_LINES=$(grep -c '"event":"output"' "$LOG_FILE" 2>/dev/null || echo 0)
DONE_PAYLOAD="{\"commits\":$COMMITS,\"mode\":\"${MODE}\",\"duration_sec\":${DURATION},\"output_lines\":${OUTPUT_LINES},\"branch\":\"$(git_branch)\",\"head\":\"$(git_head)\",\"base_ref\":\"${BASE_REF}\",\"commits_ahead\":$(git_commits_ahead),\"dirty\":$(git_dirty)}"
log_event "agent_done" "$DONE_PAYLOAD"
nr_event "agent_done" "$DONE_PAYLOAD"

echo ""
echo "Session log: $LOG_FILE"
