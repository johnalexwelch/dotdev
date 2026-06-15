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

---

## 2026-05-28 - Canonical PR right-sizing policy

**Question:** Where should the right-size PR rule live: one new canonical skill, or duplicated guidance across every workflow skill?

**Decision:** Create one canonical PR sizing / slice sizing policy and reference it from the workflows that create, execute, review, and finalize PRs.

**What else was considered:**

- Inline the full rule everywhere: stronger local visibility, but drift-prone.
- Only enforce in `workflow-finalize`: simple, but catches oversize PRs after implementation work is already done.

**Tradeoffs accepted:**

- Workflow skills will need to depend on a shared policy reference, so the policy must be easy to find and explicit enough that agents do not miss it.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Enforce PR budget during issue slicing

**Question:** Should the 300-500 target be enforced at the issue/slice level, not just at PR finalization?

**Decision:** Yes. Every generated implementation issue should include an estimated PR budget: target 400 reviewable changed lines, acceptable range 300-500, and explicit split triggers when the work likely exceeds that.

**What else was considered:**

- Let implementers decide during coding: flexible, but inconsistent.
- Use finalizer-only enforcement: catches mistakes, but after sunk cost.

**Tradeoffs accepted:**

- Issue creation will take more effort because slice feasibility must be estimated up front.
- Estimates may be wrong, so execution workflows still need midstream stop rules.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Count reviewable changed lines

**Question:** What should count as "lines of code" for the right-sized PR rule?

**Decision:** Use reviewable changed lines, not net LOC. Count code, tests, docs, config, migrations, and skill markdown when they require human review. Exclude generated files, mechanically regenerated lockfiles, snapshots, vendored output, and local state artifacts unless they are the actual subject of the PR.

**What else was considered:**

- Net LOC: easy to compute, but hides churn.
- Raw diff stat: objective, but includes noisy generated output.

**Tradeoffs accepted:**

- Agents must explain material exclusions in the PR body so reviewers can audit the sizing claim.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Pause when implementation outgrows the budget

**Question:** Should agents stop mid-implementation if they realize a slice will exceed the budget?

**Decision:** Yes. If the agent predicts the final PR will exceed 500 reviewable changed lines or span unrelated concerns, it must pause, propose a split plan, and avoid continuing into a large PR unless the user explicitly approves.

**What else was considered:**

- Finish and split later: sometimes necessary, but usually wastes review effort.
- Allow oversize PRs if tests pass: optimizes for completion, not review quality.

**Tradeoffs accepted:**

- Some runs will halt before a full implementation is complete, but the resulting PRs should be easier to review and merge.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Require explicit size exceptions

**Question:** Should there be an explicit exception path for indivisible changes?

**Decision:** Yes. Allow PRs over 500 reviewable changed lines only when the change is logically atomic, hard to split safely, and the PR body includes a Size Exception note explaining why it was not split.

**What else was considered:**

- Hard cap at 500 lines: clean, but can create unsafe artificial splits.
- No cap: easy, but preserves the current failure mode.

**Tradeoffs accepted:**

- Reviewers will occasionally see larger PRs, but those PRs must carry an explicit rationale that can be challenged.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Create a standalone right-sized PR skill

**Question:** Should the canonical policy be a new standalone skill?

**Decision:** Yes. Create a new standalone skill, such as `right-sized-prs` or `pr-scope-sizing`, to define the 300-500 reviewable-line range, 400-line target, counting rules, split triggers, and exception path.

**What else was considered:**

- Use only `AGENTS.md`: visible, but less likely to be invoked during issue slicing.
- Use only workflow edits: strong local visibility, but drift-prone.

**Tradeoffs accepted:**

- Workflow skills must explicitly reference the standalone skill so the policy is invoked at planning, execution, review, and finalization time.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Put the first PR-size gate in issue slicing

**Question:** Which workflow should own the first hard gate: `to-issues`, `execute-prd`, or `workflow-finalize`?

**Decision:** `to-issues` owns the first hard gate. Every issue it creates should include an Estimated PR Budget section with target changed-line range, expected touched areas, split triggers, and whether the slice is likely to be AFK-safe.

**What else was considered:**

- Put the first gate in `execute-prd`: useful, but later than ideal.
- Put the first gate in `workflow-finalize`: too late.

**Tradeoffs accepted:**

- Issue drafting becomes more demanding because agents must reason about implementation size before publishing.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Check PR size before PR creation

**Question:** Should execution skills be required to check PR size before opening the PR?

**Decision:** Yes. Add a pre-PR size checkpoint to `workflow-build-one` and `execute-prd`: run a diff stat against the branch base, classify reviewable changed lines, and halt with a split proposal if the PR is over 500 lines or spans unrelated concerns.

**What else was considered:**

- Check only during finalization: catches the problem after PR body and CI setup.
- Check continuously after every edit: too heavy.

**Tradeoffs accepted:**

- Execution workflows may halt for replanning after implementation has started, but before PR review churn begins.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Treat oversize diffs as review risk

**Question:** Should `workflow-review` treat oversize PRs as review risk?

**Decision:** Yes. `workflow-review` should escalate the review profile when diffs exceed 15 files or 500 reviewable changed lines, and return `NEEDS HUMAN` if the diff is both oversize and not justified by a Size Exception.

**What else was considered:**

- Let finalization handle size only: simpler, but misses independent review pressure.
- Always reject oversize PRs: too rigid for atomic changes.

**Tradeoffs accepted:**

- Some large atomic diffs can still proceed, but only with an explicit exception that review can challenge.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Apply PR-size targets to skills and docs

**Question:** Should the same 300-500 target apply to skill/docs PRs, not just application code?

**Decision:** Yes. Apply the right-sized PR target to all reviewable changes: code, tests, docs, config, and skills. For skill-library work specifically, prefer one coherent workflow family per PR, even if the changed-line count is slightly below 300.

**What else was considered:**

- Apply only to code: misses skill-maintenance and documentation review load.
- Apply strictly to docs too: can force awkward padding.

**Tradeoffs accepted:**

- Coherence takes priority over the lower bound, so some valid PRs will be smaller than 300 reviewable changed lines.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Preserve vertical slices while right-sizing PRs

**Question:** Should agents be allowed to split by technical layer to hit the line budget?

**Decision:** No by default. The right-sized PR policy should preserve vertical slices as the default: one narrow behavior through the needed layers. Horizontal splits are allowed only for independently verifiable work, mechanical refactors, migrations, generated updates, or preparatory changes that have their own verification.

**What else was considered:**

- Always split by layer: easy to size, but weak product coherence.
- Never split by layer: too rigid for migrations and mechanical prep.

**Tradeoffs accepted:**

- Some right-sized slices may be smaller or more dependent than a purely layer-based split, but they should reduce integration risk and avoid half-shipped behavior.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Require structured split proposals

**Question:** Should the policy require a split proposal format when a task is too large?

**Decision:** Yes. Require a split proposal with proposed PRs, target line estimate per PR, dependencies, verification per PR, what remains out of scope, and whether each PR is AFK-safe or needs human approval.

**What else was considered:**

- Ask the user what to do: acceptable when ambiguous, but weak as a default.
- Auto-split silently: risky because it may change scope or dependencies without approval.

**Tradeoffs accepted:**

- Agents must pause and produce explicit decomposition when the split changes the planned issue boundary.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Include PR size evidence in PR descriptions

**Question:** Should line-budget estimates be included in PR descriptions?

**Decision:** Yes. `describe-pr` should include a compact PR Size section with the reviewable changed-line estimate, excluded generated or mechanical files if any, whether the PR is within budget, and Size Exception rationale if over 500.

**What else was considered:**

- Keep sizing internal: less noise, but no accountability.
- Only mention oversize PRs: lighter, but loses useful review context.

**Tradeoffs accepted:**

- PR bodies will include a small amount of process metadata, but reviewers can audit scope quickly.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Use stacked PRs only for tightly coupled increments

**Question:** Should the policy prefer stacked PRs when one feature cannot fit in one PR?

**Decision:** Yes, but only when dependencies are clear and the repo workflow can handle stacked branches. The default split should be sequential issue PRs; stacked PRs are appropriate for tightly coupled increments where each child still has independent verification.

**What else was considered:**

- Never stack: simpler, but can force awkward blocked PRs.
- Always stack large features: increases branch-management overhead.

**Tradeoffs accepted:**

- Stacked PRs add branch-management complexity, so they should be reserved for clear dependency chains rather than used as the default split strategy.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Ship the right-sizing system in right-sized PRs

**Question:** Should the first implementation PR for the right-sizing system be the new canonical skill only?

**Decision:** Yes. PR 1 should add the standalone right-sized PR skill and the decision log entries only. PR 2 should wire the policy into planning and issue creation. PR 3 should wire execution, review, and finalization enforcement.

**What else was considered:**

- Do all edits in one PR: faster, but undermines the policy and creates broad review scope.
- Patch finalization first: useful, but leaves planning and execution behavior unchanged.

**Tradeoffs accepted:**

- The rollout takes multiple PRs, but the implementation demonstrates the desired review-size discipline.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Keep PR 1 to the canonical policy artifact

**Question:** What should PR 1 contain exactly?

**Decision:** PR 1 should contain only `docs/decision-log.md` and `dotfiles/.claude/skills/right-sized-prs/SKILL.md`. It should not modify workflow skills yet.

**What else was considered:**

- Include `to-issues` wiring in PR 1: useful, but expands scope.
- Include all workflow wiring in PR 1: faster, but violates the new right-sizing policy.

**Tradeoffs accepted:**

- The first PR will not yet enforce the policy across workflows, but it creates a reviewable canonical foundation.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Wire planning workflows in PR 2

**Question:** What should PR 2 contain?

**Decision:** PR 2 should wire the policy into planning and issue creation: `workflow-roadmap/SKILL.md`, `workflow-feature/SKILL.md` if used for feature-to-issue flow, `to-prd/SKILL.md` if PRDs shape downstream slices, `to-issues/SKILL.md`, and optionally `workflow-autonomous-backlog/SKILL.md` because it calls `to-prd` and `to-issues`.

**What else was considered:**

- Skip roadmap and PRD layers and only patch `to-issues`: faster, but upstream plans may still be too large.
- Patch every planning-adjacent skill: broader than needed.

**Tradeoffs accepted:**

- PR 2 may touch several planning skills, but the scope is coherent because all changes shape issue and slice size before implementation.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Wire execution and delivery workflows in PR 3

**Question:** What should PR 3 contain?

**Decision:** PR 3 should wire execution and delivery enforcement: `workflow-build-one/SKILL.md`, `execute-prd/SKILL.md`, `workflow-review/SKILL.md`, `workflow-finalize/SKILL.md`, and `describe-pr/SKILL.md`.

**What else was considered:**

- Only patch `workflow-finalize`: catches issues too late.
- Patch execution only: misses review and PR-body accountability.

**Tradeoffs accepted:**

- PR 3 will span multiple delivery skills, but they form one coherent enforcement path from implementation through review, finalization, and PR description.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Use precise trigger terms for right-sized PRs

**Question:** Should the right-sized PR skill be auto-triggered by broad terms like "PR," "issue," or "implementation"?

**Decision:** No. The skill description should trigger on scope and sizing language such as "right-sized PR," "split PR," "too large," "PR budget," "reviewable diff," "300-500 lines," "slice sizing," and "scope creep." Workflow skills should explicitly invoke or reference it when they create or evaluate implementation slices.

**What else was considered:**

- Very broad trigger: high recall, high annoyance.
- Very narrow trigger: low annoyance, missed enforcement.

**Tradeoffs accepted:**

- The skill relies on explicit workflow references for routine enforcement rather than firing on every generic PR mention.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Include an executable sizing checklist

**Question:** Should the canonical skill include a command/checklist agents can run manually?

**Decision:** Yes. Include a compact checklist: estimate reviewable changed lines; identify excluded generated or mechanical files; confirm one coherent behavior or independently verifiable change; if over 500 or unrelated, produce a split proposal; if over 500 and atomic, require Size Exception; add PR Size evidence to the PR body.

**What else was considered:**

- Principles only: easier to read, weaker in execution.
- Full script: premature unless repeated manual counting becomes unreliable.

**Tradeoffs accepted:**

- The first version stays lightweight and manual; automation can be added later if counting becomes unreliable.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Validate PR 1 with targeted skill checks

**Question:** How should we validate PR 1?

**Decision:** Validate PR 1 with lightweight skill-file checks only: confirm `right-sized-prs/SKILL.md` has valid frontmatter, the decision log entries exist, and the new skill does not modify workflow behavior yet.

**What else was considered:**

- Run broad skill sync or audit: useful later, but may surface unrelated existing skill-library noise.
- No validation: too loose.

**Tradeoffs accepted:**

- PR 1 validation will not prove downstream workflow enforcement because that belongs in later PRs.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Merge right-sizing rollout sequentially by default

**Question:** Should PR 2 and PR 3 be stacked on PR 1 or merged sequentially?

**Decision:** Merge sequentially if practical. PR 1 establishes the canonical policy. PR 2 targets the branch after PR 1 lands. PR 3 targets the branch after PR 2 lands. Use stacked PRs only if reviewing the whole rollout before merging any part is more important than branch simplicity.

**What else was considered:**

- Stack all three PRs: faster parallel review, more branch overhead.
- One mega-PR: fastest to author, worst for the policy.

**Tradeoffs accepted:**

- Sequential rollout may take longer, but each PR can stand alone and remain easier to review.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Exclude unrelated dirty changes from the rollout

**Question:** Should existing broad dirty changes in this skills repo be included in this rollout?

**Decision:** No. Treat current unrelated skill edits, moves, settings changes, shell changes, `.omc/`, and `.skill-observations/` as separate work unless they directly support PR 1. For this rollout, isolate only the right-sized PR policy changes.

**What else was considered:**

- Bundle all current changes and split later: likely confusing.
- Pause this rollout until the worktree is clean: safer, but may block useful policy work.

**Tradeoffs accepted:**

- The repo remains dirty with unrelated work, so PR 1 branch preparation must stage or commit only the policy files.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Propose splits before creating issues

**Question:** Should the new policy skill require agents to create new issues when a split is needed?

**Decision:** Not always. The policy should require a split proposal first. Creating new issues should happen only through the project's normal issue workflow, such as `to-issues`, after user approval or existing workflow authorization.

**What else was considered:**

- Auto-create child issues: efficient, but too much state mutation.
- Never create issues: leaves approved splits unactionable.

**Tradeoffs accepted:**

- Splitting may take an extra approval step, but it avoids silent tracker mutations and unexpected scope changes.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.

## 2026-05-28 - Implement PR 1 after the grill

**Question:** After this grill is accepted, should I implement PR 1 now?

**Decision:** Yes. Implement PR 1 only: add `dotfiles/.claude/skills/right-sized-prs/SKILL.md`, keep `docs/decision-log.md`, and avoid touching workflow skills in this PR.

**What else was considered:**

- Stop after decision log: useful, but incomplete.
- Implement all three PRs now: too broad.

**Tradeoffs accepted:**

- The canonical artifact becomes available immediately, while workflow integration remains scoped follow-up work.

**Source:** grill-with-docs conversation on PR right-sizing for future project work.
