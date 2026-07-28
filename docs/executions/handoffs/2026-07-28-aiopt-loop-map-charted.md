# Handoff — AI-response optimization loop: map charted

**State (durable):** Map **#118** — <https://github.com/johnalexwelch/dotdev/issues/118>
Session type: wayfinder **chart** (complete). Next: wayfinder **work mode**, one ticket.

## What happened

Charted a `wayfinder:map` for a manually-run daily loop that eval-scores AI-response
quality and emits a morning ranked report → issues (a) + PRs (b) + reflections/habits (c).
Destination, Notes (handoff = `/to-prd`→`/to-issues`→`/triage`), fog, and out-of-scope
recorded on #118. Boundary: AI-response *optimization*, NOT skill/workflow quality
(session-insight owns that — out of scope).

## Frontier (open · unblocked · unclaimed)

- **#119** research (AFK) — eval harness options (Harbor vs promptfoo/Inspect/Braintrust/…)
- **#120** grilling (HITL) — what gets evaluated: corpus + quality dimensions
- **#121** grilling (HITL) — bound the AI-optimization surface

Fog (report format, pipeline wiring, auto-mode, loop driver) in map's *Not yet specified*.

## Next session

Recommended first ticket: **#119** (AFK, sharpest first step; final pick may revisit after #120).
Confirm the frontier before claiming — canonical query:

```bash
gh issue list --state open --search "no:assignee -label:wayfinder:blocked" \
  --json number,title,labels,assignees
# keep only sub-issues of #118 whose blockers are all closed
```

Then: claim (`gh issue edit 119 --add-assignee @me`) → resolve → comment answer →
close → append to #118 Decisions-so-far → mirror via `/decision-log`.

## Ops note

`gh` active account flips to `alexwelch-dojo`; repo owner is `johnalexwelch`.
Run `gh auth switch --user johnalexwelch` before any `gh` write.
Sub-issue attach needs the **numeric REST id** (`gh api repos/OWNER/REPO/issues/N -q .id`),
not the GraphQL node id.
