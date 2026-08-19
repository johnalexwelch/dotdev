# feat(skills): consolidation batch 2 — herdr merge, exec folds, twin seams (D-006)

## Summary

Alex-approved corpus consolidation batch 2 (2026-08-19): five items, one PR. Evidence base: `skill-invocations.log` full span (2026-07-20 → 2026-08-19) — zero invocations ever of `herdr`, `herdr-launch`, `humanizer-exec`, `stage-v1-concept`, `find-skills`, `decision-memo`; `humanizer` 8, `deep-research` 1. The retro trio and `graph-first` were explicitly examined and KEPT per Alex's per-item answers.

1. **herdr-launch → herdr.** One `herdr` skill; the genuinely distinct content — stage-appropriate companion-tool launches (implement/review/ci/cleanup) — kept as § Companion tools by delivery stage. Pair slimmed 673 → 162 lines (herdr 382→153, tombstone 9). Tombstone per the #164 pattern (redirect body, `disable-model-invocation: true`). Decision log records: retirement candidate if still zero-use at next audit (the auto-naming extension covers the automatic case).
2. **humanizer-exec → humanizer § Exec mode.** More than tone constraints (exec-register table, sharpen-don't-reorganize scope rule, no-fabricated-headline gate) → full section, not a paragraph. Sole skill caller `workflow-executive-doc` rewired (flow diagram, Step 9 polish, pairs-well). Tombstoned.
3. **Twin disambiguation, no retirement** (plugin twins aren't ours to remove): corpus `find-skills` description claims canonical status over `meta-skills:find-skills`; corpus `deep-research` names the engine boundary vs `meta-skills:deep-research` (Claude-native AFK web research with cited markdown asset vs OpenAI Deep Research API — choose by engine).
4. **Exec-writing seam.** `decision-memo` ↔ `workflow-executive-doc` mirror sentences (single decision → exec one-pager vs full memos/board docs); exec-doc's polish step is explicitly `Load and run humanizer` (exec mode) and its decision sections compose `decision-memo` where applicable.
5. **stage-v1-concept → v1-workflow Step 2.25 (Stage the Concept).** Scratch/ephemeral grill promotion absorbed concisely (pending entries → repo docs, name/slug, location + git-init human gates, restart brief); `grill-with-docs` promotion handoff rewired. Tombstoned.

Catalog: router Knowledge/utility row 8→6; skills-index regenerated; SKILL-MANIFEST tombstone annotations; AUDIT_REPORT batch-2 resolution table; decision-log entry appended. herdr-launch deliberately left in the router's Library/infra row — router refactor rows are owned by the in-flight planning-lane consolidation PR; the tombstone dir keeps the ref resolving.

## Review

Independent `workflow-review`, `full` profile (computed floor: full): 4 opus lanes (security, logic, tests, style) → R1: security/tests/style APPROVE, logic REQUEST_CHANGES (7 findings: v1-workflow contract/gate inventory, scratch-path Step 2 decision-log collision, exec-mode gate ordering, herdr placeholder bindings + input defaults + HERDR_ENV skip semantics, decision-memo composition scoping, router legacy rows) → all fixed except the two router-table additions (deferred, see Notes) → R2 delta verification: 4× APPROVE, with two new style should-fixes (HERDR_ENV gate top/section contradiction; yazi opt-out mechanism) closed in a final wording commit confirmed by the lanes.

## Test plan

- `lint-skill-refs.sh <worktree skills root>`: 48 explicit refs, 0 dangling (explicit root — the script's default root is the *installed* `~/.claude/skills` tree, a footgun the tests lane caught; follow-up filed)
- `lint-skill-suite.sh`: failures=0 (warnings pre-existing warn-mode)
- `_docs/skills-index.sh --write` regenerated; index committed fresh; tombstone descriptions trimmed ≤137 chars so the generated index keeps the full redirect instruction
- Ledger run `2026-08-19-skills-consolidation-batch2` (kind=skill) with review + finalize stamps; lane digests in `docs/executions/state.yaml`

## Notes

- Conflict-lane guard: does not touch `design-plan`, `execute-phase`, `to-prd`, `execute-prd`, workflow-router refactor rows, or `reference/workflows.md` (owned by the planning-lane consolidation PR).
- Stale long-tail maps (`AI_ENVIRONMENT.md`, `dotfiles/.claude/SKILLS-MAP.md`) still name pre-batch retired skills from earlier batches too — left for a docs-audit sweep, consistent with prior retirement batches (drift now three batches deep per the style lane; sweep follow-up recommended).
- Deferred router edits (logic F7 / style lane): legacy-name redirect rows for `humanizer-exec` / `stage-v1-concept` and the `herdr-launch` Library/infra row — this batch's router allowance was scoped to the Knowledge/utility catalog counts while the planning-lane consolidation PR owns broader router edits; add the redirect rows in a follow-up once that PR lands (tombstone descriptions carry the redirect meanwhile).
- Follow-up tooling (tests lane): default `lint-skill-refs.sh` root to its own directory like the sibling lints; add a "tombstoned name in live catalog" assertion.
- Do not merge without Alex; post-merge Codex mirror via `sync-codex-skills.sh` per Track D.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
