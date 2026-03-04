#!/bin/bash
# Usage: ./scripts/run_fluent_bit.sh
# Runs Fluent Bit as a sidecar to ship Wintermute JSONL logs to New Relic Logs.

set -u

CONFIG_PATH=${1:-scripts/fluent-bit-newrelic.conf}

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Fluent Bit config not found: $CONFIG_PATH"
  exit 1
fi

if ! command -v fluent-bit >/dev/null 2>&1; then
  echo "fluent-bit not found in PATH."
  echo "Install Fluent Bit, then re-run this script."
  exit 1
fi

if [[ -z "${NEW_RELIC_LICENSE_KEY:-}" ]]; then
  echo "NEW_RELIC_LICENSE_KEY is not set."
  echo "Set it first, then run this script again."
  exit 1
fi

mkdir -p logs
export WINTERMUTE_PROJECT="${WINTERMUTE_PROJECT:-$(basename "$(pwd)")}"

echo "Starting Fluent Bit sidecar for Wintermute logs..."
echo "Config: $CONFIG_PATH"
echo "Project: $WINTERMUTE_PROJECT"
echo "Tailing: logs/*.jsonl"
echo "Press Ctrl+C to stop."

exec fluent-bit -c "$CONFIG_PATH"
