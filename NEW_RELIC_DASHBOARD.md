# Wintermute New Relic Dashboard

This file contains a ready-to-use dashboard payload for Wintermute monitoring.

## 1) Set required env vars

```bash
export NEW_RELIC_API_KEY=...
export NEW_RELIC_ACCOUNT_ID=...
```

## 2) Create dashboard via NerdGraph

```bash
curl -s https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NEW_RELIC_API_KEY}" \
  -d @- <<'JSON'
{
  "query": "mutation DashboardCreate($accountId: Int!, $dashboard: DashboardInput!) { dashboardCreate(accountId: $accountId, dashboard: $dashboard) { entityResult { guid name permalink } errors { description type } } }",
  "variables": {
    "accountId": 12345678,
    "dashboard": {
      "name": "Wintermute Monitoring",
      "permissions": "PUBLIC_READ_WRITE",
      "pages": [
        {
          "name": "Session Health",
          "widgets": [
            {
              "title": "Active agents right now",
              "layout": { "row": 1, "column": 1, "width": 4, "height": 3 },
              "visualization": { "id": "viz.billboard" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT uniqueCount(agent) FROM WintermuteEvent WHERE event = 'agent_start' AND session IN (SELECT latest(session) FROM WintermuteEvent) SINCE 1 hour ago"
                  }
                ]
              }
            },
            {
              "title": "Error rate",
              "layout": { "row": 1, "column": 5, "width": 4, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT percentage(count(*), WHERE event IN ('agent_error','warp_session_error','synthesis_error')) FROM WintermuteEvent SINCE 7 days ago TIMESERIES"
                  }
                ]
              }
            },
            {
              "title": "Cancellation rate",
              "layout": { "row": 1, "column": 9, "width": 4, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT percentage(count(*), WHERE event IN ('agent_canceled', 'warp_session_canceled')) FROM WintermuteEvent WHERE event IN ('agent_start','agent_done','agent_error','agent_canceled','warp_session_start','warp_session_done','warp_session_error','warp_session_canceled') SINCE 7 days ago TIMESERIES"
                  }
                ]
              }
            },
            {
              "title": "Task completion funnel",
              "layout": { "row": 4, "column": 1, "width": 6, "height": 3 },
              "visualization": { "id": "viz.pie" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT count(*) FROM WintermuteEvent WHERE event IN ('agent_start', 'agent_done', 'agent_error', 'agent_canceled', 'warp_session_start', 'warp_session_done', 'warp_session_error', 'warp_session_canceled') FACET event SINCE 7 days ago"
                  }
                ]
              }
            },
            {
              "title": "Sessions over time",
              "layout": { "row": 4, "column": 7, "width": 6, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT uniqueCount(session) FROM WintermuteEvent FACET project TIMESERIES daily SINCE 30 days ago"
                  }
                ]
              }
            }
          ]
        },
        {
          "name": "Runtime & Throughput",
          "widgets": [
            {
              "title": "Runtime distribution (p50/p90/p99)",
              "layout": { "row": 1, "column": 1, "width": 6, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT percentile(duration_sec, 50, 90, 99) FROM WintermuteEvent WHERE event IN ('agent_done', 'agent_error', 'agent_canceled', 'warp_session_done', 'warp_session_error', 'warp_session_canceled') SINCE 7 days ago TIMESERIES"
                  }
                ]
              }
            },
            {
              "title": "Commits per session",
              "layout": { "row": 1, "column": 7, "width": 6, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT sum(commits) FROM WintermuteEvent WHERE event IN ('agent_done','warp_session_done') FACET session TIMESERIES SINCE 30 days ago"
                  }
                ]
              }
            },
            {
              "title": "Average output lines per completed portable run",
              "layout": { "row": 4, "column": 1, "width": 6, "height": 3 },
              "visualization": { "id": "viz.billboard" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT average(output_lines) FROM WintermuteEvent WHERE event = 'agent_done' SINCE 7 days ago"
                  }
                ]
              }
            },
            {
              "title": "Dirty working tree at terminal events",
              "layout": { "row": 4, "column": 7, "width": 6, "height": 3 },
              "visualization": { "id": "viz.pie" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT count(*) FROM WintermuteEvent WHERE event IN ('agent_done','agent_error','agent_canceled','warp_session_done','warp_session_error','warp_session_canceled') FACET dirty SINCE 7 days ago"
                  }
                ]
              }
            }
          ]
        },
        {
          "name": "Synthesis",
          "widgets": [
            {
              "title": "Synthesis lifecycle counts",
              "layout": { "row": 1, "column": 1, "width": 6, "height": 3 },
              "visualization": { "id": "viz.pie" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT count(*) FROM WintermuteEvent WHERE event IN ('synthesis_start','synthesis_done','synthesis_error') FACET event SINCE 7 days ago"
                  }
                ]
              }
            },
            {
              "title": "Synthesis duration",
              "layout": { "row": 1, "column": 7, "width": 6, "height": 3 },
              "visualization": { "id": "viz.line" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT average(duration_sec), percentile(duration_sec, 95) FROM WintermuteEvent WHERE event = 'synthesis_done' SINCE 7 days ago TIMESERIES"
                  }
                ]
              }
            },
            {
              "title": "Synthesis error detail (recent)",
              "layout": { "row": 4, "column": 1, "width": 12, "height": 3 },
              "visualization": { "id": "viz.table" },
              "rawConfiguration": {
                "nrqlQueries": [
                  {
                    "accountIds": [12345678],
                    "query": "SELECT timestamp, session, mode, error FROM WintermuteEvent WHERE event = 'synthesis_error' SINCE 7 days ago LIMIT 100"
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  }
}
JSON
```

## 3) Replace account id placeholders

This payload uses `12345678` as a placeholder in:
- `variables.accountId`
- every `rawConfiguration.nrqlQueries[].accountIds` array

Replace all of them with your real New Relic account ID before running.
