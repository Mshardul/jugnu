# <prompt-name> audit — YYYY-MM-DD

- **Prompt:** `docs/audit/prompts/<name>.md`
- **Commit:** `<git rev-parse --short HEAD at audit time>`
- **Scope actually inspected:** <list the files/dirs you read — if you skipped
  part of the declared scope, say which and why>
- **Tickets cross-checked:** <IDs from docs/tickets.md in this domain that you
  reviewed>

## Summary

<2–4 sentences. How many findings, worst severity, any theme.>

| # | Severity | Title | Where |
|---|----------|-------|-------|
| F1 | Critical | ... | `path:line` |
| F2 | Major | ... | `path:line` |

## Findings

### F1 — <short title>

- **Severity:** Critical | Major | Minor | Observation
- **Where:** `path/to/file.swift:120-134` (repeat for every site)
- **What:** <the defect or drift, concretely>
- **Why it matters:** <impact — tie to a constraint, spec line, or user-visible
  consequence>
- **Existing ticket:** none | covered by 00XX | related to 00XX (too narrow / stale)
- **Suggested direction:** <optional, one line — not a spec>

### F2 — <short title>

...

## Notes for the ticketing discussion

- <findings that look like they should merge into one ticket>
- <findings already fully covered by a ticket — likely no new ticket needed>
- <anything that needs a product call before it can be a ticket>
