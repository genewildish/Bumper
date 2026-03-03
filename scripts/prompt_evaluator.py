#!/usr/bin/env python3
"""
Evaluates a synthesized narrative and proposes review-only edits to AGENT_PROMPT.md.
This script NEVER writes AGENT_PROMPT.md; it outputs evidence-backed suggestions and a proposed diff.
Usage: python3 scripts/prompt_evaluator.py outputs/[narrative].md
"""

import difflib
import json
import os
import sys
from pathlib import Path
try:
    import anthropic
except Exception:
    anthropic = None
import anthropic


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/prompt_evaluator.py outputs/[narrative].md")
        sys.exit(1)

    narrative_path = Path(sys.argv[1])
    if not narrative_path.exists():
        print(f"Narrative file not found: {narrative_path}")
        sys.exit(1)

    prompt_path = Path("AGENT_PROMPT.md")
    current_prompt = prompt_path.read_text(encoding="utf-8") if prompt_path.exists() else ""
    narrative = narrative_path.read_text(encoding="utf-8")
    if anthropic is None or not os.getenv("ANTHROPIC_API_KEY"):
        print("Prompt evaluator skipped: Anthropic package or ANTHROPIC_API_KEY is unavailable.")
        print("Manual path: review the narrative and edit AGENT_PROMPT.md directly.")
        sys.exit(0)

    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2200,
        messages=[
            {
                "role": "user",
                "content": f"""You are reviewing one Wintermute session narrative to improve AGENT_PROMPT.md.
Human review is mandatory. Do not assume the agent behavior was correct; instructions may be wrong too.

CURRENT AGENT_PROMPT.md:
{current_prompt}

SESSION NARRATIVE:
{narrative}

Return valid JSON with this schema:
{{
  "suggestions": [
    {{
      "title": "short title",
      "reason": "why this should change",
      "evidence": ["direct quote or concrete excerpt from narrative", "..."],
      "risk_if_applied_blindly": "what could go wrong"
    }}
  ],
  "revised_prompt_markdown": "full proposed AGENT_PROMPT.md content"
}}
Rules:
- Include 3-7 suggestions.
- Every suggestion must include concrete evidence.
- Highlight uncertainty if evidence is weak.""",
            }
        ],
    )
    raw = response.content[0].text
    try:
        parsed = json.loads(raw)
    except Exception:
        print("Failed to parse model output as JSON. Raw output follows:\n")
        print(raw)
        sys.exit(2)

    revised_prompt = parsed.get("revised_prompt_markdown", "")
    if not revised_prompt.strip():
        print("Model output did not include revised_prompt_markdown.")
        sys.exit(2)

    print("# HUMAN REVIEW REQUIRED")
    print("Do not auto-apply these changes. Review evidence before editing AGENT_PROMPT.md.\n")

    print("## Evidence-backed suggestions")
    for i, s in enumerate(parsed.get("suggestions", []), start=1):
        print(f"{i}. {s.get('title', 'Untitled')}")
        print(f"   Reason: {s.get('reason', '')}")
        print(f"   Risk if applied blindly: {s.get('risk_if_applied_blindly', '')}")
        ev = s.get("evidence", [])
        for item in ev:
            print(f"   - Evidence: {item}")
        print("")

    print("## Proposed AGENT_PROMPT.md unified diff (review-only)")
    current_lines = current_prompt.splitlines(keepends=True)
    revised_lines = revised_prompt.splitlines(keepends=True)
    diff = difflib.unified_diff(
        current_lines,
        revised_lines,
        fromfile="AGENT_PROMPT.md (current)",
        tofile="AGENT_PROMPT.md (proposed)",
    )
    print("".join(diff))


if __name__ == "__main__":
    main()
