# Session Reflection: document-dbt-model skill + enforcement scope creep
**Date**: 2026-08-05
**Goal**: Ship the `document-dbt-model` skill as its own draft PR with a Linear ticket, after earlier documenting one staging model.

## What Went Well
- YAGNI reflex fired correctly on the first ask (add YAML lint): mapped the four existing layers (pi-lens, `check-yaml`, `dbt parse` CI, `dbt_integrity`) and declined a redundant fifth instead of building it.
- Reused existing infra when a gate was warranted: put the boilerplate test in `tests/dbt_integrity/` (auto-run by CI + pre-commit) rather than new plumbing, and defended that placement when asked about a skill-local `scripts/` folder.
- Every gate change shipped with a runnable self-check that proved it *caught* violations, not just passed vacuously.
- Clean PR split at the end: skill-only branch off `main`, Linear AE-191 created and linked, description gated to `check_tells.py` TOTAL 0 and MECE.

## What Went Wrong / Friction
- Built escalating enforcement (test + allowlist, then opt-in scope file) that the user rolled back. Two round-trips of build-then-remove before landing on "just the skill."
- First rollout was opt-out (scan all YAML, block everyone except 4 baselined files). User had to say "don't roll out to the whole population" to get opt-in. Default should have been the smaller blast radius.
- Skill cross-reference first landed in anti-pattern prose, not the Verify step where a practitioner looks for "what must pass" — user had to ask "why isn't that in our skill?"

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "going too deep... just want to push the skill without the boilerplate enforcement" | Escalated from offering a check to building CI enforcement without confirming rollout appetite | ponytail persona / habits |
| 2 | "don't want to roll out yet to the whole population" | Defaulted to opt-out (repo-wide) enforcement instead of opt-in pilot | habits (rollout-scope default) |
| 3 | "why isn't that in our skill?" | Reference placed in wrong doc section (prose, not the Verify checklist) | document-dbt-model SKILL.md (astronomer repo) |

## Lessons
1. **A gate's blast radius is part of the spec, not a default.** When I offered "a doc-coverage gate" and got "please do," I still owned the rollout scope. Building any enforcement should start opt-in (one file/dir) and ask before going population-wide. The user's "please do" approved the idea, not the blast radius.
2. **Offering an enhancement invites over-building.** "Say the word and I'll scope it" led to three build/rollback cycles. When the enhancement is enforcement infra, confirm rollout scope in the same breath as the offer, before writing code.
3. **Put "what must pass" in the checklist, not the prose.** A reference to a gate belongs in the Verify step, where someone looks for gating criteria.

## Proposed Improvements
- [ ] `ponytail` persona (or `docs/agents/habits.md`) — add a rule: when the lazy-ladder output is *enforcement* (a CI gate, lint, or check that blocks others), default to opt-in single-target scope and confirm blast radius before repo-wide rollout. (priority: med)
- [ ] No change to `document-dbt-model` — the enforcement was correctly removed; the skill itself was not the problem. (priority: n/a)

<!-- No skill-extraction candidate: the PR-split + Linear-ticket + humanizer-gate flow is real but already composed from existing skills (humanizer, clarity-review); not a new repeatable skill worth extracting. -->
