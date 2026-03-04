#!/usr/bin/env python3
"""
Post-session synthesis. Reads JSONL log + git log, produces:
- outputs/<session>-facts.json (authoritative machine-derived facts)
- outputs/<session>-narrative-pass-a.md (analysis draft A, no prompt recommendations)
- outputs/<session>-narrative-pass-b.md (analysis draft B, no prompt recommendations)
- outputs/<session>-narrative.md (final narrative; includes prompt recommendations)
- outputs/<session>-uncertainty.json (dual-pass disagreement and citation checks)
Usage: python3 scripts/synthesize.py logs/[session].jsonl
"""

import json
import os
import re
import hashlib
import subprocess
import sys
from datetime import datetime
from pathlib import Path
try:
    import anthropic
except Exception:
    anthropic = None


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


def get_mode() -> str:
    config_path = Path("wintermute.config.json")
    if not config_path.exists():
        return "portable"
    try:
        with open(config_path, encoding="utf-8") as f:
            cfg = json.load(f)
        mode = cfg.get("mode", "portable")
        return mode if mode in {"portable", "full-warp"} else "portable"
    except Exception:
        return "portable"


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


def get_git_log_structured(limit: int = 50) -> list[dict]:
    try:
        result = subprocess.run(
            ["git", "--no-pager", "log", f"-{limit}", "--pretty=format:%H%x1f%h%x1f%ct%x1f%s"],
            capture_output=True,
            text=True,
            check=False,
        )
        commits = []
        for i, line in enumerate(result.stdout.splitlines()):
            parts = line.split("\x1f")
            if len(parts) != 4:
                continue
            commits.append(
                {
                    "id": f"GIT-{i+1:03d}",
                    "hash": parts[0],
                    "short_hash": parts[1],
                    "ts": int(parts[2]) if parts[2].isdigit() else None,
                    "subject": parts[3],
                }
            )
        return commits
    except Exception:
        return []


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


def build_facts(events: list[dict], stats: dict, commits: list[dict]) -> dict:
    indexed_events = []
    counts = {}
    for e in events:
        event_type = e.get("event", "unknown")
        counts[event_type] = counts.get(event_type, 0) + 1
        indexed_events.append(
            {
                "id": f"EVT-{len(indexed_events)+1:04d}",
                "event": event_type,
                "agent": e.get("agent"),
                "task": e.get("task"),
                "session": e.get("session"),
                "ts": e.get("ts"),
                "data": e.get("data"),
            }
        )
    return {
        "schema_version": 1,
        "generated_by": "scripts/synthesize.py",
        "stats": stats,
        "event_counts": counts,
        "events": indexed_events,
        "git_commits": commits,
    }


def chunk_output_events(events: list[dict], chunk_size: int = 100) -> list[str]:
    output_lines = [e.get("data") for e in events if e.get("event") == "output" and e.get("data")]
    chunks = []
    for i in range(0, len(output_lines), chunk_size):
        chunks.append("\n".join(output_lines[i : i + chunk_size]))
    return chunks


def annotate_chunk(client, chunk: str, task: str, chunk_num: int) -> str:
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


def synthesize_without_llm(
    stats: dict,
    facts: dict,
    mode: str,
    reason: str,
    include_recommendations: bool,
) -> str:
    event_ids = [e.get("id") for e in facts.get("events", []) if e.get("id")]
    git_ids = [g.get("id") for g in facts.get("git_commits", []) if g.get("id")]
    evt_ref = f"[FACT:{event_ids[0]}]" if event_ids else ""
    git_ref = f"[FACT:{git_ids[0]}]" if git_ids else ""

    done_events = facts.get("event_counts", {}).get("agent_done", 0) + facts.get("event_counts", {}).get("warp_session_done", 0)
    error_events = facts.get("event_counts", {}).get("agent_error", 0) + facts.get("event_counts", {}).get("warp_session_error", 0)
    started_events = facts.get("event_counts", {}).get("agent_start", 0) + facts.get("event_counts", {}).get("warp_session_start", 0)

    lines = [
        "# Session Summary",
        f"Mode: `{mode}`. LLM synthesis was skipped because {reason}.",
        f"Observed {started_events} session starts, {done_events} session completions, and {error_events} error events {evt_ref}.",
        "",
        "# What Agents Did",
        f"Tasks touched: {', '.join(stats.get('tasks', [])) or '(none)'} {evt_ref}",
        f"Agents observed: {', '.join(stats.get('agents', [])) or '(none)'} {evt_ref}",
        f"Total commits counted from terminal events: {stats.get('total_commits', 0)} {evt_ref}",
        "",
        "# What Worked",
        f"Machine-derived facts and structured git history were generated successfully {evt_ref} {git_ref}.",
        "",
        "# What Didn't Work",
        f"No model-authored narrative was produced in this run ({reason}).",
        "Interpretation and recommendation quality require manual review of facts/logs.",
        "",
        "# Decisions Made",
        f"The session was processed in `{mode}` mode with deterministic/fact-first synthesis output only {evt_ref}.",
        "",
        "# Open Questions",
        "- Should full narrative generation be enabled for this environment?",
        "- Do we want stricter required fields for manual full-warp session closure events?",
    ]
    if include_recommendations:
        lines.extend(
            [
                "",
                "# Recommended AGENT_PROMPT.md Changes",
                "No automatic prompt change recommendations were generated in non-LLM mode.",
            ]
        )
    return "\n".join(lines)


def synthesize_analysis_pass(
    client,
    annotations: list[str],
    stats: dict,
    git_log: str,
    agent_prompt: str,
    facts: dict,
    pass_label: str,
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

AUTHORITATIVE FACTS JSON (machine-derived, source of truth):
{json.dumps(facts, indent=2)}

Produce an analysis draft with these sections (PASS {pass_label}):
1. Session Summary
2. What Agents Did
3. What Worked
4. What Didn't Work
5. Decisions Made
6. Open Questions

Important:
- Do NOT include a "Recommended AGENT_PROMPT.md Changes" section in this pass.
- Prompt recommendation content is reserved for the final consolidated narrative only.

Rules:
- Every non-trivial factual claim MUST include at least one citation in the form [FACT:EVT-####] or [FACT:GIT-###].
- If a claim cannot be supported by a fact id from the provided JSON, label it as [UNCERTAIN] and explain why.
- Prefer omission over unsupported inference.
- Do not invent event IDs, commit hashes, or outcomes.

Be specific and honest.""",
            }
        ],
    )
    return response.content[0].text


def synthesize_final_narrative(
    client,
    stats: dict,
    git_log: str,
    agent_prompt: str,
    facts: dict,
    analysis_a: str,
    analysis_b: str,
    uncertainty: dict,
) -> str:
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4000,
        messages=[
            {
                "role": "user",
                "content": f"""You are producing the FINAL consolidated narrative for one development session.
This final narrative is the only file that should contain prompt-recommendation guidance.

SESSION STATS:
{json.dumps(stats, indent=2)}

GIT LOG (recent commits):
{git_log}

CURRENT AGENT_PROMPT.md:
{agent_prompt}

AUTHORITATIVE FACTS JSON:
{json.dumps(facts, indent=2)}

ANALYSIS PASS A (no recommendations):
{analysis_a}

ANALYSIS PASS B (no recommendations):
{analysis_b}

UNCERTAINTY REPORT:
{json.dumps(uncertainty, indent=2)}

Produce the FINAL narrative with these sections:
1. Session Summary
2. What Agents Did
3. What Worked
4. What Didn't Work
5. Decisions Made
6. Open Questions
7. Recommended AGENT_PROMPT.md Changes

Rules:
- Section 7 must appear only in this final narrative output.
- Every non-trivial factual claim MUST include at least one citation in the form [FACT:EVT-####] or [FACT:GIT-###].
- If a claim cannot be supported, mark it [UNCERTAIN] and explain why.
- Prefer omission over unsupported inference.
- Do not invent event IDs, commit hashes, or outcomes.

Be specific and honest.""",
            }
        ],
    )
    return response.content[0].text


def extract_fact_ids(text: str) -> set[str]:
    return set(re.findall(r"\[FACT:(EVT-\d{4}|GIT-\d{3})\]", text))


def count_uncertain_marks(text: str) -> int:
    return text.count("[UNCERTAIN]")


def build_uncertainty_report(narrative_a: str, narrative_b: str, facts: dict) -> dict:
    fact_ids_a = extract_fact_ids(narrative_a)
    fact_ids_b = extract_fact_ids(narrative_b)
    valid_ids = {e["id"] for e in facts.get("events", [])} | {g["id"] for g in facts.get("git_commits", [])}
    invalid_a = sorted(fid for fid in fact_ids_a if fid not in valid_ids)
    invalid_b = sorted(fid for fid in fact_ids_b if fid not in valid_ids)
    return {
        "schema_version": 1,
        "citation_counts": {"pass_a": len(fact_ids_a), "pass_b": len(fact_ids_b)},
        "invalid_citations": {"pass_a": invalid_a, "pass_b": invalid_b},
        "citation_diff": {
            "only_in_pass_a": sorted(fact_ids_a - fact_ids_b),
            "only_in_pass_b": sorted(fact_ids_b - fact_ids_a),
        },
        "uncertain_markers": {"pass_a": count_uncertain_marks(narrative_a), "pass_b": count_uncertain_marks(narrative_b)},
        "notes": [
            "Large citation_diff suggests unstable interpretation across passes.",
            "invalid_citations must be resolved by human review before trusting recommendations.",
        ],
    }


def normalize_recommendation_seed(text: str) -> str:
    cleaned = re.sub(r"\[REC-[0-9a-f]{7}\]", "", text, flags=re.IGNORECASE)
    cleaned = re.sub(r"^\s*\d+[a-z]?\.\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = cleaned.replace("`", "")
    cleaned = cleaned.replace("*", "")
    cleaned = re.sub(r"\s+", " ", cleaned).strip().lower()
    return cleaned


def recommendation_id_from_seed(seed: str, used_ids: set[str]) -> str:
    salt = 0
    while True:
        payload = seed if salt == 0 else f"{seed}:{salt}"
        rec_id = f"REC-{hashlib.sha1(payload.encode('utf-8')).hexdigest()[:7]}"
        if rec_id not in used_ids:
            used_ids.add(rec_id)
            return rec_id
        salt += 1


def assign_recommendation_ids(narrative: str) -> str:
    lines = narrative.splitlines()
    if not lines:
        return narrative

    section_idx = None
    section_level = None
    section_header_pattern = re.compile(
        r"^(#{1,6})\s*7\.\s*Recommended AGENT_PROMPT\.md Changes\b",
        re.IGNORECASE,
    )
    for i, line in enumerate(lines):
        match = section_header_pattern.match(line)
        if match:
            section_idx = i
            section_level = len(match.group(1))
            break
    if section_idx is None or section_level is None:
        return narrative

    section_end = len(lines)
    heading_pattern = re.compile(r"^(#{1,6})\s+")
    for i in range(section_idx + 1, len(lines)):
        heading = heading_pattern.match(lines[i])
        if heading and len(heading.group(1)) <= section_level:
            section_end = i
            break

    used_ids: set[str] = set()
    added_any = False
    existing_id_pattern = re.compile(r"\[?(REC-[0-9a-f]{7})\]?", re.IGNORECASE)
    subheading_pattern = re.compile(r"^(#{1,6})\s+(.+?)\s*$")

    for i in range(section_idx + 1, section_end):
        match = subheading_pattern.match(lines[i])
        if not match:
            continue
        if len(match.group(1)) <= section_level:
            continue
        heading_text = match.group(2).strip()
        existing = existing_id_pattern.search(heading_text)
        if existing:
            used_ids.add(existing.group(1).upper())
            continue
        seed = normalize_recommendation_seed(heading_text)
        if not seed:
            continue
        rec_id = recommendation_id_from_seed(seed, used_ids)
        lines[i] = f"{match.group(1)} [{rec_id}] {heading_text}"
        added_any = True

    if not added_any:
        list_item_pattern = re.compile(r"^(\s*)(\d+\.)\s+(.+?)\s*$")
        for i in range(section_idx + 1, section_end):
            match = list_item_pattern.match(lines[i])
            if not match:
                continue
            item_text = match.group(3).strip()
            existing = existing_id_pattern.search(item_text)
            if existing:
                used_ids.add(existing.group(1).upper())
                continue
            seed = normalize_recommendation_seed(item_text)
            if not seed:
                continue
            rec_id = recommendation_id_from_seed(seed, used_ids)
            lines[i] = f"{match.group(1)}{match.group(2)} [{rec_id}] {item_text}"
            added_any = True

    return "\n".join(lines)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/synthesize.py logs/[session].jsonl")
        sys.exit(1)

    log_file = sys.argv[1]
    mode = get_mode()
    has_api_key = bool(os.getenv("ANTHROPIC_API_KEY"))
    llm_enabled = mode == "portable" and anthropic is not None and has_api_key
    llm_reason = ""
    if not llm_enabled:
        if mode != "portable":
            llm_reason = f"mode is '{mode}'"
        elif anthropic is None:
            llm_reason = "anthropic package is unavailable"
        else:
            llm_reason = "ANTHROPIC_API_KEY is missing"
    client = anthropic.Anthropic() if llm_enabled else None

    print(f"Loading events from {log_file}...")
    events = load_events(log_file)
    stats = get_session_stats(events)
    git_log = get_git_log()
    git_commits = get_git_log_structured()

    print(f"Stats: {stats}")
    agent_prompt = Path("AGENT_PROMPT.md").read_text(encoding="utf-8") if Path("AGENT_PROMPT.md").exists() else ""
    facts = build_facts(events, stats, git_commits)

    all_annotations = []
    if llm_enabled:
        tasks = set(e.get("task") for e in events if e.get("task"))
        for task in tasks:
            task_events = [e for e in events if e.get("task") == task]
            chunks = chunk_output_events(task_events)
            print(f"Annotating {task}: {len(chunks)} chunks...")
            for i, chunk in enumerate(chunks):
                if chunk.strip():
                    all_annotations.append(annotate_chunk(client, chunk, task, i + 1))

    session_date = datetime.now().strftime("%Y-%m-%d-%H%M")
    Path("outputs").mkdir(exist_ok=True)
    facts_file = f"outputs/{session_date}-facts.json"
    narrative_a_file = f"outputs/{session_date}-narrative-pass-a.md"
    narrative_b_file = f"outputs/{session_date}-narrative-pass-b.md"
    narrative_file = f"outputs/{session_date}-narrative.md"
    uncertainty_file = f"outputs/{session_date}-uncertainty.json"

    Path(facts_file).write_text(json.dumps(facts, indent=2), encoding="utf-8")

    if llm_enabled:
        print("Synthesizing analysis pass A...")
        narrative_a = synthesize_analysis_pass(client, all_annotations, stats, git_log, agent_prompt, facts, "A")
        print("Synthesizing analysis pass B...")
        narrative_b = synthesize_analysis_pass(client, all_annotations, stats, git_log, agent_prompt, facts, "B")
        uncertainty = build_uncertainty_report(narrative_a, narrative_b, facts)
        print("Synthesizing final consolidated narrative...")
        final_narrative = synthesize_final_narrative(
            client,
            stats,
            git_log,
            agent_prompt,
            facts,
            narrative_a,
            narrative_b,
            uncertainty,
        )
    else:
        print(f"LLM synthesis skipped ({llm_reason}); generating facts-only narrative.")
        narrative_a = synthesize_without_llm(
            stats,
            facts,
            mode,
            llm_reason,
            include_recommendations=False,
        )
        narrative_b = f"# Pass B skipped\n\nReason: {llm_reason}\n\n" + narrative_a
        final_narrative = synthesize_without_llm(
            stats,
            facts,
            mode,
            llm_reason,
            include_recommendations=True,
        )
        uncertainty = {
            "schema_version": 1,
            "llm_synthesis": "skipped",
            "reason": llm_reason,
            "mode": mode,
            "notes": [
                "Use facts file and raw logs for manual interpretation.",
                "Set portable mode and ANTHROPIC_API_KEY to enable dual-pass narratives.",
            ],
        }
    final_narrative = assign_recommendation_ids(final_narrative)
    Path(narrative_a_file).write_text(narrative_a, encoding="utf-8")
    Path(narrative_b_file).write_text(narrative_b, encoding="utf-8")
    Path(narrative_file).write_text(final_narrative, encoding="utf-8")
    Path(uncertainty_file).write_text(json.dumps(uncertainty, indent=2), encoding="utf-8")

    print(f"\nFacts written to: {facts_file}")
    print(f"Narrative (pass A) written to: {narrative_a_file}")
    print(f"Narrative (pass B) written to: {narrative_b_file}")
    print(f"Final narrative written to: {narrative_file}")
    print(f"Uncertainty report written to: {uncertainty_file}")
    print("\n--- PREVIEW ---")
    print(final_narrative[:500] + "...")


if __name__ == "__main__":
    main()
