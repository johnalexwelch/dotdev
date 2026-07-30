# Session Reflection: IRIS loop — M3 lock, OD resolution, build tickets

**Date**: 2026-07-29
**Goal**: Lock the M3 loop-driver design, resolve OD-1..OD-4 from iris ground truth, and publish the first startable build tickets on #118.

## What Went Well

- **Process gates caught real defects.** The 5-round consensus panel surfaced genuine operational holes in M3 (undefined `emitted` trigger; `--state closed` conflating implemented with won't-fix → false counter increments). The to-issues-required critic caught a propagated ground-truth error before publish.
- **Live ground-truth checks paid off.** Reading the actual iris repo resolved OD-2 correctly against my assumption: habits/notes are DB-backed (`AgentNote` model + pending→approved workflow), not files — forcing a design amendment (Type-2 appends a note, not a PR). Checking beat guessing.
- **Convergence criterion ended the panel loop cleanly** — round 5 got an explicit "blocking = data-loss/silent-misroute/approval-bypass/baseline-corruption vs build-note" test, which is why it converged instead of finding unbounded new nits.

## What Went Wrong / Friction

- **Stale compacted memory propagated a wrong harness label.** I wrote "eval harness on Inspect AI (DL-0021)" into the roadmap heading, DL-0024 spec references, and #118 line 41 — but **DL-0021 explicitly rejected Inspect** ("thin owned driver + cherry-picked iris-eval, no Inspect"; Inspect deferred to "target #2"). My memory retained DL-0019's superseded choice. The critic caught it by quoting `decision-log.md:795`.
- **Same root cause, second instance:** I proposed a "private dotdev copy" for the P0a fixture target, over-rotating on the dead portability ambition (DL-0019/DL-0020 wording), until the user asked "I thought we were building for iris?" DL-0021 had already fixed SUT=IRIS.
- **`gh` account silently reverts** to `alexwelch-dojo` (no write perms) between bash blocks — one `gh issue edit` failed silently mid-session; I had to re-run `gh auth switch --user johnalexwelch` repeatedly.
- Minor self-caught: BSD `sed` left a literal `u2014` (no `\u` expansion) in #118; native sub-issue API returned FORBIDDEN (token lacks the perm) → checklist fallback; commit subjects repeatedly exceeded 72 chars.

## Corrections

| # | What the user/critic corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "I thought we were building for iris? or general?" — P0a target should be the iris repo, not a dotdev copy | Acted on superseded compacted memory (DL-0019 portable / DL-0020 "dotdev failures") without checking DL-0021's supersession | `docs/agents/habits.md` |
| 2 | (critic) "Inspect AI" mislabel contradicts locked DL-0021 | Same — remembered DL-0019's Inspect choice; didn't consult the supersedes-chain before writing artifacts | `docs/agents/habits.md` |

## Lessons

1. **After compaction, remembered decisions are a proxy — the decision-log supersession chain is authoritative.** Both errors this session came from building new artifacts on decisions (DL-0019 Inspect, DL-0020 "dotdev failures", portability) that a *later, explicitly-marked* DL had reversed. The decision log carries "supersedes DL-XXXX" markers precisely for this; I didn't grep them before writing. **Before writing any new artifact that references a prior DL, grep the decision log for that DL number + "supersede" to confirm it's still live.**
2. **A superseding decision leaves stale echoes in sibling docs.** DL-0021 superseded DL-0019, but "Inspect AI" and "dotdev failures" survived in the roadmap, DL-0020, and #118. When a decision is superseded, the same session should sweep dependent docs — a supersession isn't done until its echoes are corrected.

## Proposed Improvements

- [ ] `docs/agents/habits.md` — add habit: **"Compacted memory is a proxy; the decision-log supersession chain is ground truth. Before writing a new artifact (DL, roadmap, spec, issue) that cites a prior decision, grep `docs/decision-log.md` for that DL's number + `supersede` to confirm it hasn't been reversed. When a decision supersedes another, sweep dependent docs (roadmap/specs/issues) for stale echoes in the same session."** (priority: high — caused 2 corrections this session)
- [ ] `docs/agents/habits.md` — add env note: **"In the dotdev repo, `gh` silently reverts to `alexwelch-dojo` (no write perms); re-run `gh auth switch --user johnalexwelch` at the top of any bash block that calls `gh`, and treat a silent `gh issue edit`/`create` no-op as an auth-account failure, not a content error."** (priority: med — one silent failure this session)

## Skill Extraction Candidates
<!-- none: no new repeatable multi-step workflow cleared the quality gate; both findings are habit/policy refinements to existing owners -->
