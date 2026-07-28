# Handoff — AI-response optimization loop: map charted

**State (durable):** Map **#118** — <https://github.com/johnalexwelch/dotdev/issues/118>
Last session: wayfinder **work mode** — resolved **#119** (eval-harness research). Next: one more work-mode ticket.

## What happened

Charted a `wayfinder:map` for a manually-run daily loop that eval-scores AI-response
quality and emits a morning ranked report → issues (a) + PRs (b) + reflections/habits (c).
Destination, Notes (handoff = `/to-prd`→`/to-issues`→`/triage`), fog, and out-of-scope
recorded on #118. Boundary: AI-response *optimization*, NOT skill/workflow quality
(session-insight owns that — out of scope).

## Progress

- ✅ **#119** research (AFK) — **resolved** → DL-0017 (provisional: **promptfoo** backbone; Inspect AI if eval-unit=agent runs; Harbor deferred; finalize after #120). Asset: `docs/research/2026-07-28-eval-harness-options.md`.

## Frontier (open · unblocked · unclaimed)

- **#120** grilling (HITL) — what gets evaluated: corpus + quality dimensions
- **#121** grilling (HITL) — bound the AI-optimization surface

Fog: report format, pipeline wiring, auto-mode, loop driver, **+ final harness selection (blocked by #120)** — in map's *Not yet specified*.

## Next session

Recommended: **#120** (defines the eval unit + quality dimensions — unblocks both the report format *and* the final harness pick). **HITL** — needs a live grilling session with Alex; agent must not answer his side. #121 is the alternative (also HITL).
Confirm the frontier before claiming — canonical query:

```bash
gh issue list --state open --search "no:assignee -label:wayfinder:blocked" \
  --json number,title,labels,assignees
# keep only sub-issues of #118 whose blockers are all closed
```

Then: claim (`gh issue edit 120 --add-assignee @me`) → grill via `/domain-modeling` + `/grill-with-docs` → comment answer →
close → append to #118 Decisions-so-far → mirror via `/decision-log`.

## Ops note

`gh` active account flips to `alexwelch-dojo`; repo owner is `johnalexwelch`.
Run `gh auth switch --user johnalexwelch` before any `gh` write.
Sub-issue attach needs the **numeric REST id** (`gh api repos/OWNER/REPO/issues/N -q .id`),
not the GraphQL node id.
