# Router golden-eval baseline — 2026-08-19 (pre-Phase-1)

Run: `test/routing-eval.sh` from PR #156's branch (`feat/router-golden-eval`, commit `f1ea4c0`), model sonnet, router SKILL.md unchanged from main. Cases NOT tuned to pass — failures kept as signal per D-006 track decisions.

## Result

**total: 40 · pass: 36 · fail: 4 · pass-rate: 90% — below the 95% bar**

## Failures (verbatim)

| case | source | prompt | expected | got |
|---|---|---|---|---|
| 2 | log | De-AI this paragraph before I post it. | humanizer | direct |
| 21 | synthetic | The error message users see when upload fails is confusing — improve the wording. | workflow-feature | direct |
| 24 | synthetic | Run receive-review on PR #17. | receive-review | workflow-finalize |
| 35 | synthetic | Rewrite this work-order so the AFK agent can execute it — just give me the text back. | prompt-builder | direct |

## Reading

- **Dominant failure mode: collapse to `direct`** (3/4). The router's under-routing bias matches the gate-compliance baseline (0% gate coverage, ≤4 router invocations across 40 merges) — same story, two instruments. Case 21 is the costly shape: user-facing copy is tracked code; `direct` there bypasses worktree/review/finalize entirely. Corroborates D-006 decision 18 (entry enforcement).
- **Case 24 is a prose-priority ambiguity**, not model sloppiness: the owner-vs-sub-step carve-out (bare skill name → dispatch sub-step) lost to the owner-default rule. Phase 1 fix candidate: sharpen the carve-out wording/ordering in the classification section.
- Phase 1 rerun must beat 90% without touching golden-routes.yaml expected values; eval-set changes and router changes never land in the same PR.

Full log: session artifact (routing-eval-baseline.log); summary preserved here as the durable record.
