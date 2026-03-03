#!/usr/bin/env python3
"""
Fetches Wintermute event timeline from New Relic for a session.
Usage: python3 scripts/nr_query.py <session_id>
"""

import json
import os
import sys
from urllib import request


def get_nr_timeline(session_id: str) -> list[dict]:
    account_id = os.environ["NEW_RELIC_ACCOUNT_ID"]
    api_key = os.environ["NEW_RELIC_API_KEY"]  # User API key, not license key
    nrql = f"SELECT * FROM WintermuteEvent WHERE session='{session_id}' SINCE 1 day ago LIMIT 1000"

    payload = {
        "query": (
            "{ actor { account(id: "
            f"{account_id}"
            ') { nrql(query: "'
            f"{nrql}"
            '") { results } } } }'
        )
    }
    req = request.Request(
        "https://api.newrelic.com/graphql",
        data=json.dumps(payload).encode("utf-8"),
        headers={"API-Key": api_key, "Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["data"]["actor"]["account"]["nrql"]["results"]


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/nr_query.py <session_id>")
        sys.exit(1)
    timeline = get_nr_timeline(sys.argv[1])
    print(json.dumps(timeline, indent=2))


if __name__ == "__main__":
    main()
