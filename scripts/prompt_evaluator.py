#!/usr/bin/env python3
"""
Evaluates a synthesized narrative and proposes edits to AGENT_PROMPT.md.
Usage: python3 scripts/prompt_evaluator.py outputs/[narrative].md
"""

import sys
from pathlib import Path

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

    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1500,
        messages=[
            {
                "role": "user",
                "content": f"""You are reviewing one Wintermute session narrative to improve AGENT_PROMPT.md.

CURRENT AGENT_PROMPT.md:
{current_prompt}

SESSION NARRATIVE:
{narrative}

Return:
1) Top 5 prompt improvements with evidence from the narrative.
2) A proposed revised AGENT_PROMPT.md.
3) Any risks of overfitting to one session.""",
            }
        ],
    )

    print(response.content[0].text)


if __name__ == "__main__":
    main()
