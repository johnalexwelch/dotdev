# Decision Log

Persistent record of accepted design decisions across `dotdev` workflow skills. Created as part of the `reconcile-issues` non-default-branch close fallback work (PRD #52, implementation #53).

Each entry captures the question asked, the decision accepted, the alternatives considered, and the tradeoffs accepted. Entries are append-only — supersede an entry by adding a new one that references the prior decision ID, never by editing the original.

This file is the canonical decision record for workflow-feature flows in this repo. Future grills should append entries here in the same format.

## Format

```markdown
## DL-NNNN — <short title>

**Date**: YYYY-MM-DD
**Context**: which PRD / issue / workflow run produced this decision
**Question**: the precise question the grill answered
**Decision**: the answer that was accepted
**Alternatives considered**: bulleted list of other options that were weighed
**Tradeoffs accepted**: what we gave up by choosing this path
```

---

## DL-0001 — Approval-bypass scope for non-default-branch close fallback

**Date**: 2026-05-26
**Context**: PRD #52 — `reconcile-issues` non-default-branch close fallback; grill phase of workflow-feature run for #53
**Question**: The `reconcile-issues` skill currently lists "Closing issues" as `Requires approval`. Should the new staging-target fallback bypass that approval gate, or should it still prompt y/n inside `workflow-finalize`?
**Decision**: Bypass the approval gate, but only for this specific narrow trigger: `pr.merged == true AND pr.baseRefName != defaultBranchRef.name AND issue is referenced by Closes/Fixes/Resolves in PR body AND issue is OPEN`. All other close paths in the skill (every entry in the drift-detection table, partial-completion drift, duplicate/superseded) remain approval-gated.
**Alternatives considered**:

- *Keep approval gate, just prompt automatically* — Doesn't eliminate drift. Humans miss prompts, run AFK, same outcome as the current manual-close pattern.
- *Bypass for all issue closures in this skill* — Too broad. Other drift checks benefit from human judgment (partial completion, supersession).
- *Bypass conditional on a `--auto-close` flag* — Adds optionality but doesn't fix the default. Drift recurs anytime the flag is forgotten.
**Tradeoffs accepted**: Silent state mutation on every non-default-branch merge. Acceptable because (a) the trigger is narrow enough that false-positives are unlikely, (b) the merge itself was human-approved, (c) closing the issue is bookkeeping that mirrors what GitHub *would* have done if the merge target were the default branch.

---

## DL-0002 — Location of the new behavior in `reconcile-issues/SKILL.md`

**Date**: 2026-05-26
**Context**: PRD #52 — same grill
**Question**: Where in `reconcile-issues/SKILL.md` should the new fallback behavior live?
**Decision**: A new top-level section titled "Non-default-branch close fallback", placed *before* the existing `## Process` section. The section is self-contained: trigger, behavior, comment template, dry-run handling, gh-account-flip retry, structured log format, golden examples.
**Alternatives considered**:

- *Add as Check #10 in the existing drift-detection table* — Hides the different semantics. A future agent reading the table would assume #10 behaves like #1-9 (propose, gate, approve) when in fact it auto-acts.
- *Extract into a referenced sub-document (`references/staging-close-fallback.md`)* — Adds indirection. The new content is small enough to live in-skill; sub-docs are for procedures longer than a screen.
**Tradeoffs accepted**: The skill file gets longer (one extra top-level section). Acceptable because the alternative (mixing auto-act semantics into a propose-and-approve table) is worse.

---

## DL-0003 — Verification mechanism for the new behavior

**Date**: 2026-05-26
**Context**: PRD #52 — same grill
**Question**: The skill is markdown spec, not executable code. How do we verify the new behavior?
**Decision**: Inline golden-example tables embedded in the new section of `SKILL.md`, covering all 6 acceptance cases (default-branch no-op, non-default + OPEN, already-CLOSED, dry-run, multi-ref, mixed case). Plus a post-merge self-demo: after the implementing PR merges, the next `workflow-finalize` invocation runs the dry-run pass and identifies the PR's own issue as a candidate.
**Alternatives considered**:

- *Shell-script test harness mocking `gh`* — Adds net-new CI surface area for a single skill. dotdev has no Python/pytest/jest infra (CI is pre-commit + `bash -n` + stow dry-run). Disproportionate for one skill.
- *No tests, self-demo only* — Weakest. Self-demo is a single case; doesn't cover the 6-case matrix.
**Tradeoffs accepted**: No automated test runs against the spec. The spec itself documents expected behavior in golden examples; correctness is enforced by reviewer judgment and by the self-demo gate. Acceptable because the implementation is documentation, not code.

---

## DL-0004 — Comment template wording (locked at design time)

**Date**: 2026-05-26
**Context**: PRD #52 — same grill
**Question**: Should the comment template for auto-closed issues be proposed in the grill and locked in the spec, or deferred to the implementing executor?
**Decision**: Propose and lock now. The exact template lives in the SKILL.md spec, reproduced verbatim. Substitutions are limited to `<N>`, `<sha7>`, `<baseRefName>`, `<defaultBranch>`.
**Alternatives considered**:

- *Defer to implementation* — Risks the executor improvising wording. Different runs produce different phrasings, hurting audit consistency.
- *Generic "Auto-closed by reconcile-issues" one-liner* — Saves space but loses the explanation of *why* GitHub didn't auto-close. Future readers see a closed issue and wonder if it was intentional.
- *Verbose multi-paragraph explanation* — Wastes review space. The PR link carries most of the context already.
**Tradeoffs accepted**: Template changes now require a spec edit + PR rather than per-run flexibility. Acceptable — we want uniform audit trails, not per-run creativity.

---

## DL-0005 — Reference parsing scope (PR body only)

**Date**: 2026-05-26
**Context**: PRD #52 — same grill
**Question**: Should the fallback parse closing references from PR commit messages and linked-via-UI references, or only from the PR body?
**Decision**: PR body only.
**Alternatives considered**:

- *Body + commits* — Catches more references but risks closing issues that the PR only *touched* via WIP commit refs, not *resolved*. False positives are worse than false negatives here: a missed close gets caught next reconcile run; a wrong close requires reopen + apology comment.
- *Body + commits + linked-via-GitHub-UI* — Even broader, even more false-positive risk.
**Tradeoffs accepted**: Closing keywords that appear only in commits won't trigger the fallback. Acceptable because (a) this matches GitHub's own auto-close semantics exactly, (b) authors who want a PR to close an issue write it in the PR body — that's the convention.

---

## DL-0006 — Decision-log persistence location

**Date**: 2026-05-26
**Context**: PRD #52 — same grill; this file is the artifact of this decision
**Question**: `docs/decision-log.md` doesn't exist yet in dotdev. Where should the decisions from this grill be persisted?
**Decision**: Create `docs/decision-log.md` (this file) at the repo root, alongside the existing `docs/` directory. Use it as the canonical decision record for all future workflow-feature flows in dotdev.
**Alternatives considered**:

- *Inline decisions in the PRD body only* — Loses precedent value. Future grills don't have an example format to follow. Also lost when the PRD issue is archived.
- *Create an ADR per decision (`docs/adr/0001-*.md`)* — Overkill. These are feature-scoping choices, not hard-to-reverse architectural decisions. ADRs are for things like "we chose Postgres over DynamoDB" — none of these qualify.
- *Skip the decision log, rely on the PR description* — Same loss-on-archive problem.
**Tradeoffs accepted**: A small file at the repo root that future grills must remember to append to. Acceptable — the format above is self-describing and the workflow-feature skill's design-gate explicitly requires a persisted decision record.

**Deviation note**: PRD #52 and issue #53 wrote the path as `dotfiles/docs/decision-log.md`. The implementing slice judged that to be a misjudgment from the stow-hybrid working-tree layout: dotdev's tracked structure has `docs/` at the repo root (alongside `dotfiles/`, `scripts/`, `test/`), and every workflow-skill that references the decision log uses the path `docs/decision-log.md` without prefix. Persisting at `docs/decision-log.md` matches both conventions and existing structure.

---

## DL-0007 — Worktree base branch (repo-agnostic trigger)

**Date**: 2026-05-26
**Context**: PRD #52 — same grill
**Question**: The original task spec called for cutting the worktree from `origin/staging`. dotdev uses `main`. Should the spec enumerate per-repo base branches, or use a dynamic check?
**Decision**: Worktree base is whatever the executing repo's default branch is — read at runtime, not hardcoded. For dotdev, that means `origin/main`. The fallback trigger inside `reconcile-issues` is similarly repo-agnostic: it reads `defaultBranchRef.name` from `gh repo view` rather than hardcoding `main` vs `staging` vs anything else.
**Alternatives considered**:

- *Hardcode a list of known staging-targeted repos* — Brittle. The list dates the moment the next repo flips its merge target. Plus it requires editing the skill every time a new repo adopts the workflow.
- *Add a config knob to opt in/out per repo* — Premature. The default behavior (read `defaultBranchRef` at runtime) is correct everywhere. Add a knob only if a repo explicitly objects, which hasn't happened.
**Tradeoffs accepted**: One extra `gh repo view --json defaultBranchRef` call per invocation. Negligible cost; pays for itself by making the spec portable across every repo `workflow-finalize` runs in.
