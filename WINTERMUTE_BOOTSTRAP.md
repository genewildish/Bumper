# Wintermute Home Edition — Agent Bootstrap

You are helping set up a minimal multi-agent development system called **Wintermute** (named after the orchestrating AI in Gibson's Neuromancer). Your job is to scaffold this system in the current project directory so the human can run their first agent session.

Read this entire document before doing anything.

---

## What This System Is

A lightweight feedback loop for multi-agent software development with three goals:
1. Multiple aider agents work on a codebase in parallel, each claiming individual tasks
2. Everything is logged to JSONL so we know exactly what happened
3. After each session, a synthesis script reads the logs and produces a narrative document — capturing decisions, reasoning, and outcomes that normally exist only in developers' heads

Over time, the narrative documents feed back into an evolving agent system prompt, improving each session based on empirical evidence from the last one. This is the core feedback loop.

---

## The Stack

- **Terminal**: Warp (Agent Management Panel = built-in panopticon)
- **Agent runtime**: Aider with `claude-haiku-4-5` for workers (cheap), `claude-sonnet-4-6` for synthesis only
- **Coordination**: Individual task files + git (no central state file, no conflicts)
- **Observability**: Append-only JSONL log (local, no external services needed yet)
- **Synthesis**: Python script calling Anthropic API post-session

No Docker. No daemons. No external services. Own every line.
Secrets rule: load Anthropic and New Relic credentials via environment variables sourced from a local secrets file; never paste raw keys into tracked files or shell history.

---

## Directory Structure to Create

```
project/
├── WARP.md                        ← project context (Warp reads this natively like CLAUDE.md)
├── AGENT_PROMPT.md                ← aider system prompt, evolves each session
├── tasks/                         ← one file per task, agents claim these
│   └── TASK-001.md                ← example task (human writes these before each session)
├── logs/                          ← JSONL event logs, one per session
├── outputs/                       ← synthesis narratives, one per session
└── scripts/
    ├── run_agent.sh               ← thin aider wrapper with logging
    ├── synthesize.py              ← post-session narrative generation
    └── prompt_evaluator.py        ← suggests edits to AGENT_PROMPT.md based on session
```

---

## Files to Create

### `WARP.md`
This is the project brain. Warp reads it natively. Populate it with whatever the current project is. The template:

```markdown
# Project: [PROJECT NAME]

## What This Is
[1-2 sentence description]

## Architecture
[Key components and how they connect]

## Conventions
[Naming, file structure, patterns agents must follow]

## Constraints
[What agents must never touch or change]

## Current State
[What's done, what's in progress, known issues]

## Task File Format
Each task lives in tasks/TASK-NNN.md with this header:
---
id: TASK-NNN
status: available | in_progress | completed | abandoned
claimed_by: null | agent-N
claimed_at: null | ISO timestamp
---
Agents update this header when claiming and completing tasks.
Agent notes go below the header as append-only entries.
```

---

### `AGENT_PROMPT.md`
This is the system prompt injected into every aider worker. Start with this template and refine after each session:

```markdown
You are a focused coding agent working on a shared codebase with other agents running in parallel.

## Your workflow
1. Read WARP.md to understand the project
2. Read all tasks/TASK-*.md files to find an available task
3. Claim the task: update its header (status: in_progress, claimed_by: agent-N, claimed_at: timestamp)
4. Commit the claim immediately: `git add tasks/ && git commit -m "agent-N: claim TASK-NNN"`
5. If the push is rejected, another agent claimed first — pick a different task
6. Do the work. Commit frequently with messages like: `agent-N: [what you did and why]`
7. When done: update task header (status: completed), add a brief note under ## Agent Notes, commit and push
8. Pick another available task or stop if none remain

## Rules
- Never modify another agent's task file
- Never rewrite or refactor code outside your assigned task scope
- If you're uncertain about something, write a note in the task file and move on — don't block
- Commit messages must explain reasoning, not just what changed
- If you hit a conflict on push: `git pull --rebase`, resolve, push again

## What good work looks like
- Small, focused commits
- Decisions explained in commit messages
- Test coverage for anything you add
- No scope creep
```

---

### `scripts/run_agent.sh`

```bash
#!/bin/bash
# Usage: ./scripts/run_agent.sh TASK-001
# Runs an aider worker on the given task, logs everything to JSONL

TASK=${1:-TASK-001}
SESSION_ID=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AGENT_ID="agent-$$"
LOG_FILE="logs/${SESSION_ID//:/}.jsonl"

mkdir -p logs

log_event() {
  echo "{\"event\":\"$1\",\"agent\":\"$AGENT_ID\",\"task\":\"$TASK\",\"session\":\"$SESSION_ID\",\"ts\":$(date +%s),\"data\":$2}" >> "$LOG_FILE"
}

log_event "agent_start" "{}"

aider \
  --model claude-haiku-4-5-20251001 \
  --system-prompt "$(cat AGENT_PROMPT.md)" \
  --message "$(cat tasks/${TASK}.md)" \
  --yes-always \
  --no-auto-commits \
  2>&1 | while IFS= read -r line; do
    log_event "output" "$(echo "$line" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
    echo "$line"
  done

COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null | wc -l | tr -d ' ')
log_event "agent_done" "{\"commits\":$COMMITS}"

echo ""
echo "Session log: $LOG_FILE"
```

Make executable: `chmod +x scripts/run_agent.sh`

---

### `scripts/synthesize.py`

```python
#!/usr/bin/env python3
"""
Post-session synthesis. Reads JSONL log + git log, produces narrative document.
Usage: python scripts/synthesize.py logs/[session].jsonl
"""

import json
import sys
import subprocess
from datetime import datetime
from pathlib import Path
import anthropic

def load_events(log_file):
    events = []
    with open(log_file) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return events

def get_git_log():
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-50"],
            capture_output=True, text=True
        )
        return result.stdout
    except Exception:
        return "(git log unavailable)"

def get_session_stats(events):
    tasks = set(e["task"] for e in events)
    agents = set(e["agent"] for e in events)
    done = [e for e in events if e["event"] == "agent_done"]
    errors = [e for e in events if e["event"] == "agent_error"]
    total_commits = sum(int(e.get("data", {}).get("commits", 0)) if isinstance(e.get("data"), dict) else 0 for e in done)
    return {
        "tasks": list(tasks),
        "agents": list(agents),
        "total_commits": total_commits,
        "errors": len(errors),
        "duration_events": len(events)
    }

def chunk_output_events(events, chunk_size=100):
    output_lines = [
        e["data"] for e in events
        if e["event"] == "output" and e.get("data")
    ]
    chunks = []
    for i in range(0, len(output_lines), chunk_size):
        chunks.append("\n".join(output_lines[i:i+chunk_size]))
    return chunks

def annotate_chunk(client, chunk, task, chunk_num):
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": f"""These are agent output lines from task {task}, chunk {chunk_num}.
Summarize in 3-5 sentences: what was the agent attempting, what happened, what was the outcome?
Be specific about decisions made and problems encountered.

OUTPUT:
{chunk}"""
        }]
    )
    return response.content[0].text

def synthesize_narrative(client, annotations, stats, git_log, agent_prompt):
    annotation_text = "\n\n".join(f"CHUNK {i+1}:\n{a}" for i, a in enumerate(annotations))

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4000,
        messages=[{
            "role": "user",
            "content": f"""You are synthesizing a development session into a narrative document.
This document will be read by future agents and developers to understand what happened, why decisions were made, and what was learned.

SESSION STATS:
{json.dumps(stats, indent=2)}

GIT LOG (recent commits):
{git_log}

AGENT BEHAVIOR ANNOTATIONS (what agents actually did, chunk by chunk):
{annotation_text}

CURRENT AGENT_PROMPT.MD:
{agent_prompt}

Produce a narrative document with these sections:
1. **Session Summary** — what was accomplished in 2-3 sentences
2. **What Agents Did** — factual account of agent behavior, decisions made, problems hit
3. **What Worked** — patterns and approaches that produced good outcomes
4. **What Didn't Work** — failures, conflicts, confusion, wasted effort
5. **Decisions Made** — specific technical or architectural choices and the reasoning behind them
6. **Open Questions** — things that were unclear or deferred
7. **Recommended AGENT_PROMPT.md Changes** — specific edits with evidence from this session

Be specific and honest. This document is more valuable when it captures what actually happened, not a sanitized summary."""
        }]
    )
    return response.content[0].text

def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/synthesize.py logs/[session].jsonl")
        sys.exit(1)

    log_file = sys.argv[1]
    client = anthropic.Anthropic()

    print(f"Loading events from {log_file}...")
    events = load_events(log_file)
    stats = get_session_stats(events)
    git_log = get_git_log()

    print(f"Stats: {stats}")

    agent_prompt = Path("AGENT_PROMPT.md").read_text() if Path("AGENT_PROMPT.md").exists() else ""

    # Group events by task
    tasks = set(e["task"] for e in events)
    all_annotations = []

    for task in tasks:
        task_events = [e for e in events if e["task"] == task]
        chunks = chunk_output_events(task_events)
        print(f"Annotating {task}: {len(chunks)} chunks...")
        for i, chunk in enumerate(chunks):
            if chunk.strip():
                annotation = annotate_chunk(client, chunk, task, i+1)
                all_annotations.append(annotation)

    print("Synthesizing narrative...")
    narrative = synthesize_narrative(client, all_annotations, stats, git_log, agent_prompt)

    # Write output
    session_date = datetime.now().strftime("%Y-%m-%d-%H%M")
    output_file = f"outputs/{session_date}-narrative.md"
    Path("outputs").mkdir(exist_ok=True)
    Path(output_file).write_text(narrative)

    print(f"\nNarrative written to: {output_file}")
    print("\n--- PREVIEW ---")
    print(narrative[:500] + "...")

if __name__ == "__main__":
    main()
```

---

### `tasks/TASK-001.md` (example)

```markdown
---
id: TASK-001
status: available
claimed_by: null
claimed_at: null
---

# TASK-001: [Task Title]

## What to build
[Clear description of what needs to exist when this task is done]

## Acceptance criteria
- [ ] Criterion one
- [ ] Criterion two
- [ ] Tests pass

## Context
[Any relevant background, links to related code, constraints]

## Agent Notes
<!-- Agents append notes here — do not edit above this line -->
```

---

## First Session Checklist

Before running your first session:

- [ ] `pip install aider-chat anthropic` (or your preferred env setup)
- [ ] Source a local secrets file that exports `ANTHROPIC_API_KEY` (and optional New Relic vars); do not paste raw keys into your shell history
- [ ] Fill in `WARP.md` with actual project context
- [ ] Write 1-3 task files in `tasks/`
- [ ] Review `AGENT_PROMPT.md` and adjust for your project conventions
- [ ] `git init` (if not already a repo) and make an initial commit
- [ ] `chmod +x scripts/run_agent.sh`

**First session goal: one agent, one task, synthesis runs cleanly afterward.** Don't run 3 agents in parallel until you've seen one session work end to end. The narrative document is your success metric — if it accurately describes what happened, the system is working.

---

## Running a Session

```bash
# Terminal 1 (Warp pane 1)
./scripts/run_agent.sh TASK-001

# Terminal 2 (Warp pane 2) — only after first solo session works
./scripts/run_agent.sh TASK-002

# After all agents finish
python scripts/synthesize.py logs/[session].jsonl

# HUMAN REVIEW REQUIRED - do not skip this step:
# 1. Read the final narrative in outputs/<session>-narrative.md
# 2. Review section 7 ("Recommended AGENT_PROMPT.md Changes") in that final file only
#    (pass drafts are analysis-only and should not contain prompt recommendations)
# 3. Decide which recommendations to accept (some may be session-specific overfitting)
# 4. Manually edit AGENT_PROMPT.md based on accepted recommendations
# 5. Update WARP.md "Current State" section with completed tasks and new architectural facts
# 6. Write new task files for next session if needed
# 7. Commit everything including outputs/ to preserve the narrative in git history
```

---

## Cost Reference

| Run | Model | Approx cost |
|-----|-------|-------------|
| 1 worker, 1 hour | Haiku | ~$0.50–1 |
| 3 workers, 2 hours | Haiku | ~$4–6 |
| Synthesis pass | Sonnet | ~$1 |

---

## What Not to Build Yet

- No Docker (not needed for personal projects)
- No coordinator.py (assign tasks manually by opening panes)
- No automatic AGENT_PROMPT.md updates (human reviews synthesis and edits manually)

**Why human review matters:**
The synthesis narrative includes recommended prompt changes based on one session. Some recommendations are valuable patterns; others are overfitting to session-specific quirks. A human must filter:
- Accept: patterns that will improve future sessions
- Reject: session-specific fixes that don't generalize
- Defer: changes that need more data from multiple sessions

Skipping human review defeats the feedback loop. The narrative is not automatically applied — it's input for human judgment.

---

## New Relic Integration

New Relic is included from the start. JSONL remains the local buffer — New Relic is where you query, alert, and build dashboards. The two are not redundant: JSONL is the synthesis input, New Relic is the observability layer.

### Environment setup

```bash
# Source a local secrets file — do not paste raw keys into tracked files
export NEW_RELIC_LICENSE_KEY=...
export NEW_RELIC_ACCOUNT_ID=...
```

### Ship events from `run_agent.sh`

Add this function to `run_agent.sh` and call it alongside `log_event`:

```bash
nr_event() {
  EVENT_TYPE=$1
  PAYLOAD=$2
  curl -s -X POST "https://insights-collector.newrelic.com/v1/accounts/${NEW_RELIC_ACCOUNT_ID}/events" \
    -H "Api-Key: ${NEW_RELIC_LICENSE_KEY}" \
    -H "Content-Type: application/json" \
    -d "[{\"eventType\":\"WintermuteEvent\",\"event\":\"${EVENT_TYPE}\",\"agent\":\"${AGENT_ID}\",\"task\":\"${TASK}\",\"session\":\"${SESSION_ID}\",\"project\":\"$(basename $(pwd))\",${PAYLOAD:1}}]" \
    > /dev/null
}

# Call alongside log_event at start, done, and error points:
nr_event "agent_start" "{}"
nr_event "agent_done" "{\"commits\":$COMMITS}"
```

### Ship logs via Fluent Bit or direct

If you want full line-level logs in New Relic Logs (not just events), pipe aider output through the New Relic Logs API. Since you know Fluent Bit: run a sidecar `fluent-bit` process with `tail` input on the JSONL file and `newrelic` output. Or skip it and rely on events — for a personal project, events are enough.

### `scripts/nr_query.py` — pull event timeline for synthesis

Replace the git-log-only context in `synthesize.py` with a real event timeline:

```python
import requests, os

def get_nr_timeline(session_id):
    account_id = os.environ["NEW_RELIC_ACCOUNT_ID"]
    api_key = os.environ["NEW_RELIC_API_KEY"]  # User API key, not license key
    
    nrql = f"SELECT * FROM WintermuteEvent WHERE session='{session_id}' SINCE 1 day ago LIMIT 1000"
    
    response = requests.post(
        f"https://api.newrelic.com/graphql",
        headers={"API-Key": api_key, "Content-Type": "application/json"},
        json={"query": f"{{ actor {{ account(id: {account_id}) {{ nrql(query: \"{nrql}\") {{ results }} }} }} }}"}
    )
    return response.json()["data"]["actor"]["account"]["nrql"]["results"]
```

Then in `synthesize_narrative()`, pass the timeline as additional context alongside the chunk annotations. The synthesis prompt already has a slot for it.

### Dashboard

Create a dashboard with these panels — you know how to build these, so just the NRQL:

```sql
-- Active agents right now
SELECT uniqueCount(agent) FROM WintermuteEvent 
WHERE event = 'agent_start' AND session IN (
  SELECT latest(session) FROM WintermuteEvent
) SINCE 1 hour ago

-- Commits per session over time
SELECT sum(commits) FROM WintermuteEvent 
WHERE event = 'agent_done' 
FACET session TIMESERIES

-- Error rate
SELECT percentage(count(*), WHERE event = 'agent_error') 
FROM WintermuteEvent SINCE 7 days ago TIMESERIES

-- Task completion funnel
SELECT count(*) FROM WintermuteEvent 
WHERE event IN ('agent_start', 'agent_done', 'agent_error') 
FACET event

-- Sessions over time
SELECT uniqueCount(session) FROM WintermuteEvent 
FACET project TIMESERIES daily SINCE 30 days ago
```

### Alert to add immediately

One alert worth setting up before your first session: agent crash rate. If more than 1 agent errors in a 10-minute window, you want to know before the session runs off the rails silently.

```sql
SELECT count(*) FROM WintermuteEvent WHERE event = 'agent_error' SINCE 10 minutes ago
```
Threshold: > 1 → warning, > 3 → critical.

### What New Relic adds to synthesis

Once you have a few sessions of data, `synthesize.py` can ask New Relic questions the JSONL alone can't answer:

```sql
-- Which task types take longest?
SELECT average(numeric(commits)) FROM WintermuteEvent 
WHERE event = 'agent_done' FACET task

-- Which agent roles produce the most conflicts?
SELECT count(*) FROM WintermuteEvent 
WHERE event = 'agent_conflict' FACET agent

-- Session quality trend (commits per agent per session)
SELECT sum(numeric(commits)) / uniqueCount(agent) 
FROM WintermuteEvent WHERE event = 'agent_done' TIMESERIES
```

This is where the compounding value starts — after 10+ sessions you have empirical data about what configurations actually work for your specific projects.

---

## The Feedback Loop

```
Write tasks → Run agents → Synthesize → HUMAN REVIEW → Update AGENT_PROMPT.md → Update WARP.md → Write tasks → ...
```

### How the loop works:

1. **Synthesis produces artifacts with separated concerns:**
   - `outputs/<session>-narrative-pass-a.md` — analysis draft A (no prompt recommendations)
   - `outputs/<session>-narrative-pass-b.md` — analysis draft B (no prompt recommendations)
   - `outputs/<session>-narrative.md` — final consolidated narrative (the only file with recommendations)
   - `outputs/<session>-facts.json` — authoritative machine-derived facts (events, commits)
   - `outputs/<session>-uncertainty.json` — dual-pass citation diff and confidence signals

2. **Human reads and filters:**
   - Review section 7 of the narrative ("Recommended AGENT_PROMPT.md Changes")
     - Note: stats.total_commits should be cross-referenced against warp_session_done.data.commits until the counting bug is resolved. Future narrative-generating agents should be warned not to treat total_commits: 0 as authoritative.
   - Accept generalizable patterns, reject session-specific quirks
   - Apply accepted changes to `AGENT_PROMPT.md` manually

3. **Update project state:**
   - Mark completed tasks in `WARP.md` "Current State"
   - Document new architectural facts (protocols, boundaries, integrations)
   - Do NOT copy narrative lessons into WARP.md — they stay in `outputs/` and filter into `AGENT_PROMPT.md`

4. **Commit everything:**
   - Narratives in `outputs/` preserve the long-term record
   - Updated `AGENT_PROMPT.md` encodes accepted patterns
   - Updated `WARP.md` reflects current project reality

5. **Next session reads the updated context automatically:**
   - Agents see the improved `AGENT_PROMPT.md`
   - Agents see current state in `WARP.md`
   - The loop compounds: each session makes the next one better

**Critical rule:** Never skip human review. Auto-applying narrative recommendations will cause the prompt to overfit to session noise and degrade over time. The human filters signal from noise.
