# Orchestrator — which audit to run next

You are helping decide which codebase audit to run next. **Do not run any audit.**
Your only job is to read the current state and recommend, with reasons. The user
picks.

## Steps

1. Read [`prompts/README.md`](prompts/README.md) — the index of audits, their
   cadence, last-run date, and last-run severity.
2. List `report/pending/`. Any prompt with a report there is **blocked** — its
   report must be processed into tickets (and moved to `report/done/`) before it
   can run again. Say so explicitly.
3. List `report/done/` — recent history, newest first by filename date.
4. Read [`../tickets.md`](../tickets.md) briefly for context on what is already
   tracked (a domain with lots of fresh, unstarted tickets is lower urgency —
   the last audit's output hasn't been worked yet).

## Ranking

Recommend in this order of weight:

1. **Never run** — a prompt with no entry in the index history. Highest priority;
   we have no coverage of that lens at all.
2. **Last run surfaced Critical or Major findings that are now ticketed and
   worked** — re-running confirms the fix landed and nothing regressed nearby.
3. **Longest time since last run**, adjusted by cadence (a `per-release` audit
   overdue by two releases outranks a `monthly` one overdue by three weeks).
4. **Domain with recent large changes** — run
   `git log --since='<Last run date of that prompt from prompts/README.md>' --name-only`
   and bucket the paths.
   A lot in `shell/Sources/` or `addons/` → `architecture-drift` / `code-quality`
   move up; a lot in `docs/architecture/` → `docs-consistency` and
   `architecture-drift`; a lot in `AddonInstaller` / `RegistryClient` /
   `release-addons.yml` → `security`. As of the first version of this system,
   `docs/architecture/` and `shell/Sources/JugnuUI/` are by far the hottest.

The **Last run** / **Last severity** columns in `prompts/README.md` are updated by
hand. If a row looks stale or wrong, cross-check against `report/done/` filenames
and `git log -- docs/audit/report/` before trusting it.

Never recommend a **blocked** prompt (report already in `pending/`). List it
separately as "blocked — process its report first".

## Output

```
## Recommended next audit: <name>

<2–4 sentences: why this one, what changed since last run, what it will likely find>

## Also consider
- <name> — <one line>
- <name> — <one line>

## Blocked (report pending, cannot run)
- <name> — report/pending/<file>, run YYYY-MM-DD

## Full state
| Prompt | Cadence | Last run | Last severity | Status |
|--------|---------|----------|---------------|--------|
| ...    | ...     | ...      | ...           | ready / blocked / never run |
```
