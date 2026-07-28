# Session Reflection: wayfinder AI-optimization loop — charting, IRIS eval discovery

**Date**: 2026-07-28
**Goal**: `/wayfinder` a daily loop that explores an agentic codebase and proposes AI-response-quality improvements; chart the map, then work its first tickets.

## What Went Well

- **Chart step 0 (survey existing) paid off twice.** Grounding in the codebase found dotdev's existing session-insight/reflections/habits machinery (scoped the loop *away* from it, out-of-scope) and, decisively, that the first target **IRIS already ships a full eval stack** (`iris-eval`, golden set, prod-replay, CI deltas) — avoiding building a harness from scratch. Ground-truth over speculation held.
- **gh account flip caught proactively** — asserted `johnalexwelch` before every tracker write (active kept defaulting to `alexwelch-dojo`).
- **Wayfinder discipline mostly held** — one ticket per session, decisions mirrored to decision-log, handoff on exit.

## What Went Wrong / Friction

- **Invented a requirement.** Wrote "cheap to run manually" into research ticket #119's criteria without the user ever stating it; user struck it (*"id dont care about cheap to run manually"*), forcing a revise of #119 + DL-0017 + the map index. The criterion was an unlabeled assumption presented as a given.
- **Narration contradicted the artifact.** Chat summary said Harbor was "rejected"; the research asset + DL-0017 said "deferred / watch-list." User had to ask *"why was harbor rejected"* to surface the mismatch.
- **Offered to cross a session boundary.** In the charting session I offered to also resolve #119; user checked *"is this still wayfinding"*. Wayfinder says charting is one session — the offer invited drift.
- **`sub_issue` attach failed first attempt** — used the GraphQL node id (`gh issue view --json id` → `I_kw...`); the sub_issues REST API wants the **numeric database id** (`gh api repos/O/R/issues/N -q .id`). Silent 404-ish failure until corrected.
- **Multi-line `for … do … done` loop mangled** by the shell wrapper (`hypa: ...trying to start process 'for'`); single-line `;`-separated loops worked. Matches the known "bash tool flattens newlines" habit.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "id dont care about cheap to run manually" | Invented an eval criterion, presented as given not assumed | `docs/agents/habits.md` (label-assumptions) + `wayfinder` (research-ticket criteria come from grilling) |
| 2 | "why was harbor rejected" (it was deferred) | Narration used a harsher disposition than the artifact | `docs/agents/habits.md` (narration mirrors artifact) |
| 3 | "is this still wayfinding" | Offered to cross the chart→work session boundary | `wayfinder` (chart session must not offer to also work a ticket) |

## Lessons

1. **Criteria in a research ticket must come from the ask, not the author.** When grilling hasn't fixed the criteria, either ask or mark each inferred criterion **(assumed)** so it's cheap to challenge — a silently-invented requirement propagates into the ticket, the decision-log, and the map before anyone can veto it.
2. **Narrate the exact disposition the artifact records.** "Deferred/watch-list" ≠ "rejected." Compression may drop words but must not upgrade a disposition.
3. **The sub_issue attach needs the numeric REST id** — the tracker doc's `sub_issue_id=<ticket-id>` is ambiguous and reads like the number/node-id.

## Proposed Improvements

- [ ] `docs/agents/issue-tracker.md` (Wayfinding operations → Tickets) — change the attach line to specify the **numeric REST id**: `id=$(gh api repos/{owner}/{repo}/issues/<ticket> -q .id)` then `-F sub_issue_id="$id"`; note the GraphQL node id (`I_...`) does **not** work. (priority: high — concrete, already cost a retry this session)
- [ ] `docs/agents/habits.md` — add: "Don't invent requirements/criteria. When writing a ticket/spec, criteria come from the ask or grilling; mark any inferred criterion **(assumed)** so it's easy to strike. Narration must mirror the artifact's exact disposition (deferred ≠ rejected)." (priority: med — two of three corrections this session)
- [ ] `dotfiles/.config/agents/skills/wayfinder/SKILL.md` — in "Chart the map" step 5, add: "Do not offer to also resolve a ticket in the charting session — charting ends at the handoff." (priority: low — skill already implies it; user still had to check)

## Skill Extraction Candidates

<!-- none — wayfinder already owns this workflow; no new repeatable pattern cleared the gate -->
