#!/usr/bin/env python3
"""
Post-session synthesis. Reads JSONL log + git log, produces a narrative document.
Usage: python3 scripts/synthesize.py logs/[session].jsonl
"""

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import anthropic


def load_events(log_file: str) -> list[dict]:
    events = []
    with open(log_file, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return events


def get_git_log() -> str:
    try:
        result = subprocess.run(
            ["git", "--no-pager", "log", "--oneline", "-50"],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.stdout
    except Exception:
        return "(git log unavailable)"


def get_session_stats(events: list[dict]) -> dict:
    tasks = set(e.get("task") for e in events if e.get("task"))
    agents = set(e.get("agent") for e in events if e.get("agent"))
    done = [e for e in events if e.get("event") == "agent_done"]
    errors = [e for e in events if e.get("event") == "agent_error"]
    total_commits = sum(
        int(e.get("data", {}).get("commits", 0)) if isinstance(e.get("data"), dict) else 0
        for e in done
    )
    return {
        "tasks": sorted(tasks),
        "agents": sorted(agents),
        "total_commits": total_commits,
        "errors": len(errors),
        "duration_events": len(events),
    }


def chunk_output_events(events: list[dict], chunk_size: int = 100) -> list[str]:
    output_lines = [e.get("data") for e in events if e.get("event") == "output" and e.get("data")]
    chunks = []
    for i in range(0, len(output_lines), chunk_size):
        chunks.append("\n".join(output_lines[i : i + chunk_size]))
    return chunks


def annotate_chunk(client: anthropic.Anthropic, chunk: str, task: str, chunk_num: int) -> str:
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1000,
        messages=[
            {
                "role": "user",
                "content": f"""These are agent output lines from task {task}, chunk {chunk_num}.
Summarize in 3-5 sentences: what was the agent attempting, what happened, and what was the outcome?
Be specific about decisions made and problems encountered.

OUTPUT:
{chunk}""",
            }
        ],
    )
    return response.content[0].text


def synthesize_narrative(
    client: anthropic.Anthropic, annotations: list[str], stats: dict, git_log: str, agent_prompt: str
) -> str:
    annotation_text = "\n\n".join(f"CHUNK {i + 1}:\n{a}" for i, a in enumerate(annotations))
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4000,
        messages=[
            {
                "role": "user",
                "content": f"""You are synthesizing a development session into a narrative document.
This document is read by future agents and developers to understand what happened, why decisions were made, and what was learned.

SESSION STATS:
{json.dumps(stats, indent=2)}

GIT LOG (recent commits):
{git_log}

AGENT BEHAVIOR ANNOTATIONS (chunk by chunk):
{annotation_text}

CURRENT AGENT_PROMPT.md:
{agent_prompt}

Produce a narrative with these sections:
1. Session Summary
2. What Agents Did
3. What Worked
4. What Didn't Work
5. Decisions Made
6. Open Questions
7. Recommended AGENT_PROMPT.md Changes

Be specific and honest.""",
            }
        ],
    )
    return response.content[0].text


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/synthesize.py logs/[session].jsonl")
        sys.exit(1)

    log_file = sys.argv[1]
    client = anthropic.Anthropic()

    print(f"Loading events from {log_file}...")
    events = load_events(log_file)
    stats = get_session_stats(events)
    git_log = get_git_log()

    print(f"Stats: {stats}")
    agent_prompt = Path("AGENT_PROMPT.md").read_text(encoding="utf-8") if Path("AGENT_PROMPT.md").exists() else ""

    tasks = set(e.get("task") for e in events if e.get("task"))
    all_annotations = []

    for task in tasks:
        task_events = [e for e in events if e.get("task") == task]
        chunks = chunk_output_events(task_events)
        print(f"Annotating {task}: {len(chunks)} chunks...")
        for i, chunk in enumerate(chunks):
            if chunk.strip():
                all_annotations.append(annotate_chunk(client, chunk, task, i + 1))

    print("Synthesizing narrative...")
    narrative = synthesize_narrative(client, all_annotations, stats, git_log, agent_prompt)

    session_date = datetime.now().strftime("%Y-%m-%d-%H%M")
    output_file = f"outputs/{session_date}-narrative.md"
    Path("outputs").mkdir(exist_ok=True)
    Path(output_file).write_text(narrative, encoding="utf-8")

    print(f"\nNarrative written to: {output_file}")
    print("\n--- PREVIEW ---")
    print(narrative[:500] + "...")


if __name__ == "__main__":
    main()
