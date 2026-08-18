# Gate-compliance baseline (pre-D-006 enforcement)

**Date:** 2026-08-19 (audit run 2026-08-18)
**Purpose:** PRE-change baseline for D-006 decision 15's scoreboard (`dotfiles/.config/agents/skills/_docs/decision-log.md` §D-006). These numbers describe how well delivery sessions complied with the prose workflow gates before `workflow-ledger` script enforcement. Post-change numbers will come from ledger state files.

## Methodology

**Sources examined (all read-only):**

1. **Merged PR record** — last 40 merged dotdev PRs (#100–#152, merged 2026-07-24 → 2026-08-14), via `gh pr list --state merged --limit 40 --json number,title,body,mergedAt`. Bodies, issue comments (`gh pr view --json comments`), and review bodies (`gh api repos/{owner}/{repo}/pulls/N/reviews`) were all swept for `WORKFLOW_REVIEW_GATE`, `WORKFLOW_FINALIZE_GATE`, `WORKFLOW_BASE_GATE`, `WORKTREE_BASELINE_GATE`.
2. **Durable artifacts** — `~/dotdev/docs/executions/` (handoffs ×8, reflections ×84 for July–Aug, plans, architecture-reviews) swept for the same strings.
3. **Skill invocation log** — `~/.claude/logs/skill-invocations.log` (99 entries, 2026-07-20 → 2026-08-18).
4. **Session transcripts** — `~/.claude/projects/-Users-alexwelch-dotdev/` (25 session files; retention floor 2026-07-27). Grepped for gate strings only; each hit classified TEMPLATE (skill text loaded into context, placeholder pipes present) vs FILLED (actual emitted gate). The 2 gate-bearing transcripts under the current D-006 worktree's project dir were excluded (they are this effort itself).
5. **Contract specs** — `workflow-review/SKILL.md` §Required Gate Block (10 fields: workflow_base, worktree_baseline, skill_loaded, review_profile, independent_review, model_used, required_lanes, conditional_lanes, dispatch_evidence, verdict) and `workflow-finalize/SKILL.md` §Required Gate Block, including spec-as-of-2026-07-31 via `git show 7335250:...` to avoid holding old gates to new field sets.

**Known limits, stated up front:**

- **Contract nuance:** `workflow-finalize` requires the gate block "in the final response and any handoff artifact" (SKILL.md line 224) and per-issue handoff artifacts only for AFK/backlog runs (line 225) — the PR body itself is not the contractually named destination. The audit therefore measures the *durable record* (PR bodies + comments + reviews + handoff artifacts + surviving transcripts), not just PR bodies.
- **Transcript retention:** oldest surviving dotdev transcript is 2026-07-27; PRs #100–#103 (merged 07-24) predate it. Sessions may also be pruned inside the window.
- **AFK blind spot:** Codex/AFK batch workers (the likely producers of the 07-27 evening batch #104–#115 and the 07-29 batch #133–#144, merged minutes apart) do not write to `skill-invocations.log` and leave no local transcript, so their in-session gate emission is unobservable — which is precisely the durability gap D-006 fixes.
- **Log semantics:** `skill-invocations.log` records interactive Skill-tool invocations across *all* repos (work-repo sessions included), so router-invocation counts cannot be attributed per-PR. Rates derived from it are proxies, labeled as such.

## Metric table

| Metric | Value | Denominator | Confidence |
|---|---|---|---|
| PR bodies with a complete `WORKFLOW_REVIEW_GATE` block | **0** | 40 | high |
| PR bodies with a complete `WORKFLOW_FINALIZE_GATE` block | **0** | 40 | high |
| PR bodies/comments/reviews with `WORKFLOW_BASE_GATE`/`WORKTREE_BASELINE_GATE` evidence | **0** | 40 | high |
| Any gate string in PR issue comments or review bodies | **0** | 40 | high |
| Durable emitted gate blocks anywhere in `docs/executions/` | **0** | 8 handoffs + 84 reflections + plans + arch-reviews | high |
| Filled (non-template) review gates observed in surviving transcripts | **2 sessions** (both astronomer work repo: PR #9420, #9459) — **0 for dotdev PRs** | 25 dotdev-project session files, 2026-07-27 → 2026-08-18 | medium (retention + AFK blind spot) |
| Review gates stating `review_profile` | dotdev PRs: **0/0 (no gates exist)**; transcript-observed: **2/2** (`standard`) | see above | high / low-n |
| Apparent self-downgrades below the trigger-table floor | dotdev: **indeterminable** (no gates to check); observed instances: **0/2** | 2 observed gates | low (n=2) |
| Merged dotdev PRs whose diff hit a `full`-profile trigger with **no recorded review at all** (spot-check) | **2/5** (#103: 19 files >15-file trigger; #149: 110 files, +9264) | 5 sampled (#103, #105, #122, #138, #149) | high for the 5 sampled |
| Freshness violations (commits after review gate) | dotdev PRs: **indeterminable — no gates exist to timestamp against** (this is itself the finding); 2 observed transcript instances: **0/2 violations** | intended 10; actual 2 observable | low (n=2) |
| Gate fabrication signals in observed filled gates | **2/2 incomplete vs canonical spec-at-time** (missing `workflow_base` + `model_used`); **0/2** hand-invented shapes; **0/2** vague `dispatch_evidence` | 2 observed filled review gates | medium |
| User corrections attributable to skipped/violated workflow gates (reflections, Jul 9–Aug 17) | **10 strict** (14 broad) | 243 correction rows across 73 reflections with Corrections tables (84 files) | medium (keyword extraction + manual classification) |
| Router-compliance proxy: logged `workflow-router` invocations vs merged dotdev PRs in window | **4 router invocations** vs **40 merged PRs** (≤10% upper bound; not per-PR attributable) | log window 2026-07-20 → 2026-08-18 | low (proxy; see limits) |
| Logged delivery-chain skill invocations in same window | workflow-build-one ×1, execute-prd ×1, workflow-review ×1, workflow-skill ×4, to-prd ×2, to-issues ×2 | 99 log entries | high (count), low (attribution) |
| D-006 §15 "gate coverage" (merges with valid stamps) — baseline value | **0%** | 40 merged PRs | high |

## Per-metric evidence

### 1–4. PR record: zero gates (0/40)

Full sweep of bodies, issue comments, and review bodies for PRs #100–#152 (list captured in scratchpad `prs.json`). Sole string hit: **PR #136** ("Harden describe-pr compliance in PR finalization gates", merged 2026-07-29) mentions `WORKFLOW_FINALIZE_GATE` because the PR *edits the skill text* — its body describes gate requirements added to `workflow-finalize`, `workflow-build-one`, `execute-prd`, `run-backlog`; it does not emit a gate for itself. Classified subject-matter, not evidence. Every other PR: zero hits.

Notable irony: #136's own body enumerates acceptance criteria for finalize-gate completeness while carrying no finalize gate.

### 5. Durable artifacts: zero emitted gates

- `docs/executions/handoffs/` (8 files, all 2026-07-09/07-17): one string hit — `2026-07-17-deepen-worktree-baseline.md` lines 61–62, a *grill prompt proposing* `WORKTREE_BASELINE_GATE`/`STACKED_WORKTREE_GATE`, not an emitted gate.
- `docs/executions/architecture-reviews/2026-07-17-workflow-skills.html` (4 hits) and reflections `2026-07-17-router-entry-vs-chain-audit.md`, `2026-07-28-issue-59-workflow-gates.md` (1 hit each): all discuss gates; none emit one.

### 6–8. Transcript-observed gates (the only filled gates found)

Classification of every `WORKFLOW_*_GATE:` occurrence in 25 session files: template blocks (placeholder pipes, e.g. `review_profile: fast|standard|full`) in sessions `0f8c6ca9` (2026-07-29), `367c09d7` (2026-07-27), `7a38ad17` (2026-07-31) — skill text loaded into context, no emission followed in `0f8c6ca9`/`367c09d7`. Filled gates:

- **Session `5f30e761` (2026-07-30, astronomer repo, draft PR classdojo/astronomer#9420):** `WORKFLOW_REVIEW_GATE` with `review_profile: standard`, `verdict: APPROVE`, two named lanes (logic_and_edge_case, verification_adequacy), concrete `dispatch_evidence` ("2x Opus subagent (oh-my-claudecode:code-reviewer), fresh independent contexts"), security lane `not_applicable_with_reason`. Freshness-positive: the logic lane was resumed via SendMessage to cover the second commit `e1a2b424d` at HEAD. Subagent transcripts corroborate independent dispatch.
- **Session `7a38ad17` (2026-07-31, astronomer repo, draft PR classdojo/astronomer#9459):** filled review gate at 10:57Z (`standard`, APPROVE, 2 lanes, dispatch evidence with tool-use counts) and a filled `WORKFLOW_FINALIZE_GATE` in the final response at 12:21Z — after the single commit `36d3e6a6` and the 12:16Z `gh pr create --draft`. All finalize fields present including honest `ci: skipped_by_design_draft_gate`. No commits observed after the final gate → no freshness violation.

**Neither corresponds to a dotdev PR.** For the 40 audited dotdev merges, zero filled gates survive anywhere observable.

### 9. Fabrication signals

The 2 filled review gates omit `workflow_base` and `model_used`. Canonical spec at the time already required both — verified via `git show 7335250:dotfiles/.config/agents/skills/workflow-review/SKILL.md` (commit dated 2026-07-29; `model_used` present since 0d79290, 2026-07-17; `workflow_base` since 76e7108, 2026-07-15). However, the *template text loaded into those very sessions* also lacks both fields — the sessions ran a **stale mirror of the skill**, not the canonical dotfiles version. Verdict: not hand-fabricated (shape matches the loaded template exactly; dispatch_evidence is concrete in both), but **2/2 incomplete against the canonical contract**, root cause skill-mirror drift — a distribution failure the prose system cannot detect, and a distinct bypass class for the ledger to close.

### 10. Corrections attributable to gate skips/violations

243 correction rows extracted from Corrections tables in 73 of 84 July 9–Aug 17 reflections (regex on `## Corrections` sections; header/separator rows dropped). 47 matched gate/workflow keywords; manual classification of those 47 yields **10 strict** gate-skip/violation corrections:

1. `2026-07-19-skill-compliance-no-mechanical-enforcement.md` #1 — skipped workflow-finalize's mandated WORKFLOW_STEPS ledger and ordered chain ("i didnt see you go through our workflow?")
2. `2026-07-24-pr-delivery-reviewer-response.md` #1 — receive-review never run on PR #1531
3. same file #2 — same gap repeated after correction (marked CRITICAL in the reflection)
4. same file #3 — finalize not swept across all session PRs
5. `2026-07-27-pergamon-workflow-finalize-discipline.md` #1 — "PLEASE ENSURE THAT WE ARE FOLLOWING /workflow-router … /workflow-build-one … /workflow-review … /workflow-finalize"
6. `2026-07-27-pergamon-phase6-backlog-cleanup.md` #1 — ad-hoc continuation instead of router → PRD/backlog route
7. `2026-07-28-issue-59-workflow-gates.md` #2 — "did you not run workflow-build-one and workflow-review" — finalize advanced without the gates
8. `2026-07-28-pergamon-issue60-delivery-loop.md` #2 — first finalization did not fully emit/verify the required step ledger/final gate
9. `2026-08-11-3mf-multicolor-slicer-compatibility.md` #1 — "You're not using the instructed skills" (ad-hoc debugging, no router/workflow-debug)
10. same file #3 — "Please restart properly" — continued ad-hoc after the reminder

Broad count (14) adds four adjacent-but-arguable rows: `2026-07-28-issue-59` #1 (triage→execution pivot not routed), `2026-08-11-workboard-sync` #2 (finalize stopped short of merge), `2026-07-19-skill-compliance` #5 (user naming the unenforced-prompt architecture), `2026-07-23-workflow-review-merged-state` (stale-proxy-over-ground-truth during finalize; self-inflicted, no user correction). The remaining 33 keyword matches are gate-*design* corrections (human-gate taxonomy too conservative, gh-vs-Forgejo tooling assumptions, cleanup scope) — real workflow feedback but not skipped/violated gates. Non-gate causes dominate the other 196 rows.

The 3mf pair (#9, #10) is the D-006 decision-18 evidence: an exit-gate system cannot catch a session that never enters it.

### 11. Router-compliance proxy

`skill-invocations.log`, window 2026-07-20 → 2026-08-18 (99 entries; 13 entries have empty skill names): `workflow-router` invocations = **4** (2×2026-07-28 06:28/06:49 as `core:workflow-router`, 2026-07-31 16:32, 2026-07-31 19:07). One (07-28 06:49) is immediately followed by `coding-a1:workflow-build-one` — a correct route→execute pair. Against 40 dotdev PRs merged in the same window, that is at most a ~10% logged-router rate, but the number is a weak proxy in both directions: AFK/Codex batch runs (which produced the largest merge batches) don't log here at all, and interactive router invocations can belong to work-repo sessions. What the log *does* establish firmly: interactive delivery-chain skill usage was sparse (build-one ×1, execute-prd ×1, workflow-review ×1 in a month) relative to merge volume, and August shows essentially no delivery-chain invocations against dotdev despite 4 August merges (#149–#152).

## What these numbers mean as a baseline

The headline is not "reviews didn't happen" — the two surviving transcript gates show the review machinery producing genuinely good output (independent Opus lanes, concrete evidence, honest CI disclosures, correct re-review after new commits) when the chain was actually entered. The headline is that **compliance evidence does not survive the session**: 0 of 40 merged PRs carry any gate block in any durable location, so gate coverage — D-006 §15's metric, "% merges with valid stamps" — starts at **0%**, and every downstream sub-metric (profile floors, self-downgrades, freshness) is *indeterminable from the durable record*, which is itself the baseline finding. Three distinct failure classes are visible: (1) gates emitted only into chat scrollback and lost (contract permits this — the finalize destination is "final response", not the PR); (2) sessions that never enter the workflow system at all (10 strict user corrections, the 3mf pattern); (3) silent spec drift — sessions loading a stale skill mirror and emitting yesterday's gate shape with no detection. The ledger design addresses each: committed `docs/executions/state.yaml` snapshots make (1) structurally impossible, entry-enforcement hooks (decision 18) address (2), and script-owned schema-checked stamps address (3). Post-change, the scoreboard should re-measure: % of merged PRs with valid finalize stamps (target 100% in opted-in repos vs 0% here), override rate (target ~0–2/mo vs n/a here), and corrections-per-month attributable to gate skips (baseline ≈ 10 over ~6 weeks ≈ 7/mo in delivery-heavy weeks).

**Numbers explicitly not determinable in this audit:** per-PR review-profile floor compliance, self-downgrade rate, and freshness-violation rate for the 40 dotdev merges (no gates exist to evaluate — recorded as indeterminable, not estimated); gate emission inside AFK/Codex runs (no transcripts); pre-2026-07-27 session behavior (transcript retention).
