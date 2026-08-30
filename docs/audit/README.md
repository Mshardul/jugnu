# Codebase audit

A recurring, POV-driven review of the Jugnu repo. Each audit looks at the codebase
through **one lens** (security, architecture drift, catalog hygiene, …), runs to a
written report, and that report seeds a ticket-writing discussion.

This directory holds the machinery, not the findings history you act on directly:

```
docs/audit/
  README.md              you are here — lifecycle, severity rubric, rules
  orchestrator.md        "which audit next?" — an agent reads this to recommend one
  prompts/
    README.md            index: prompt | cadence | last run | last severity
    security.md
    architecture-drift.md
    catalog-hygiene.md
    code-quality.md
    docs-consistency.md
  report/
    _template.md         copy this to start a report
    pending/             audits run, tickets NOT yet created
    done/                audits run, tickets created — moved here by hand
```

## Lifecycle

1. **Pick** — run the orchestrator prompt (`orchestrator.md`) in a fresh agent
   session. It reads `prompts/README.md` and `report/pending/`, then recommends
   which audit to run next and why. You choose.
2. **Run** — feed the chosen `prompts/<name>.md` to an agent. It inspects the
   scope, applies the flag criteria, and writes a report into `report/pending/`
   using `report/_template.md`.
3. **Discuss** — you and the agent read the report together. Findings can be
   combined, split, or dropped. Not every finding becomes a ticket.
4. **Ticket** — agreed work is written into [`docs/tickets.md`](../tickets.md),
   one row per ticket, following that file's rules and the repo instructions
   ([AGENTS.md](../../AGENTS.md), [conventions.md](../conventions.md)).
5. **Archive** — once every finding in a report is either ticketed or explicitly
   dropped, move the report file from `report/pending/` to `report/done/`.

## What this rotation does NOT cover

Behavior and correctness bugs — logic errors, crashes, race conditions, wrong
output — are **not** in any audit lens here. `code-quality` explicitly punts them.
Use `/code-review` (on a branch or PR) for that; it is not on a cadence and does
not write a report into this directory. If an audit agent trips over a real bug
while working its lens, it notes it as an `Observation` and moves on — the fix
goes through `/code-review`, not a finding here.

## Rules

- **One report per prompt in `pending/` at a time.** If a report for prompt X
  already sits in `report/pending/`, do **not** run audit X again. Warn the user
  and stop. Process the existing report first.
- **Every audit runs full.** There is no accepted-debt list and no baseline diff.
  Each run re-inspects its whole scope from scratch. Known-debt patterns
  (see [conventions.md](../conventions.md)) and items already in
  [`docs/tickets.md`](../tickets.md) are still *reported*, but tagged as already
  tracked so the discussion can skip them fast.
- **The report is raw findings, not ticket drafts.** It carries enough detail to
  drive the ticketing discussion — file/line, what, why, severity, whether a
  ticket already covers it — and nothing more.
- **`report/done/` is pruned by hand.** No automatic retention.
- **No linking metadata.** The report filename's date is the only cross-reference.
  Cleanup is manual.

## Report filename

```
report/pending/YYYY-MM-DD-<prompt-name>.md
```

e.g. `report/pending/2026-08-29-security.md`. Date is the day the audit ran.

## Severity rubric

Used to triage findings in the discussion. **Severity does not auto-create a
ticket** — it only ranks the conversation.

| Severity | Meaning | Typical outcome |
|---|---|---|
| **Critical** | Security hole, data loss, privacy breach, crash-loop, or anything that violates a hard constraint in [conventions.md](../conventions.md#privacy-and-trust). | Almost always a ticket, High priority. |
| **Major** | Spec violation, missing error/cancel path, resource leak, a documented v0 non-goal that silently shipped. | Usually a ticket. |
| **Minor** | Convention drift, naming, dead code, small inconsistency. | Often batched into one cleanup ticket, or noted. |
| **Observation** | No defect. Context worth recording for the discussion. | Usually no ticket. |

## Cross-checking existing tickets

Every prompt lists the ticket IDs in its domain. Before writing a finding, the
agent checks whether an open ticket in [`docs/tickets.md`](../tickets.md) already
covers it. If so, the finding still goes in the report, tagged
`Existing ticket: covered by 00XX` — so the discussion knows not to file a
duplicate, but also so a stale or too-narrow ticket can be caught.
