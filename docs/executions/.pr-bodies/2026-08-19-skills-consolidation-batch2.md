# feat(skills): consolidation batch 2 — herdr merge, exec folds, twin seams (D-006)

## Summary

Alex-approved corpus consolidation batch 2 (2026-08-19): five items, one PR. Evidence base: `skill-invocations.log` full span (2026-07-20 → 2026-08-19) — zero invocations ever of `herdr`, `herdr-launch`, `humanizer-exec`, `stage-v1-concept`, `find-skills`, `decision-memo`; `humanizer` 8, `deep-research` 1. The retro trio and `graph-first` were explicitly examined and KEPT per Alex's per-item answers.

1. **herdr-launch → herdr.** One `herdr` skill; the genuinely distinct content — stage-appropriate companion-tool launches (implement/review/ci/cleanup) — kept as § Companion tools by delivery stage. Pair slimmed 673 → 164 lines (herdr 382→155, tombstone 9). Tombstone per the #164 pattern (redirect body, `disable-model-invocation: true`). Decision log records: retirement candidate if still zero-use at next audit (the auto-naming extension covers the automatic case).
2. **humanizer-exec → humanizer § Exec mode.** More than tone constraints (exec-register table, sharpen-don't-reorganize scope rule, no-fabricated-headline gate) → full section, not a paragraph. Sole skill caller `workflow-executive-doc` rewired (flow diagram, Step 9 polish, pairs-well). Tombstoned.
3. **Twin disambiguation, no retirement** (plugin twins aren't ours to remove): corpus `find-skills` description claims canonical status over `meta-skills:find-skills`; corpus `deep-research` names the engine boundary vs `meta-skills:deep-research` (Claude-native AFK web research with cited markdown asset vs OpenAI Deep Research API — choose by engine).
4. **Exec-writing seam.** `decision-memo` ↔ `workflow-executive-doc` mirror sentences (single decision → exec one-pager vs full memos/board docs); exec-doc's polish step is explicitly `Load and run humanizer` (exec mode) and its decision sections compose `decision-memo` where applicable.
5. **stage-v1-concept → v1-workflow Step 2.25 (Stage the Concept).** Scratch/ephemeral grill promotion absorbed concisely (pending entries → repo docs, name/slug, location + git-init human gates, restart brief); `grill-with-docs` promotion handoff rewired. Tombstoned.

Catalog: router Knowledge/utility row 8→6; skills-index regenerated; SKILL-MANIFEST tombstone annotations; AUDIT_REPORT batch-2 resolution table; decision-log entry appended. herdr-launch deliberately left in the router's Library/infra row — router refactor rows are owned by the in-flight planning-lane consolidation PR; the tombstone dir keeps the ref resolving.

## Review

Independent `workflow-review`, `full` profile (computed floor: `full`), 4 opus lanes (security, logic, tests, style), six rounds:

- **R1** (`e75adf6`): security/tests/style APPROVE, logic REQUEST_CHANGES — 7 findings: v1-workflow Contract/Hard-Gates inventory missing Step 2.25's write gates; Step 2's on-disk decision-log evidence unsatisfiable on the scratch path Step 2.25 exists to serve; exec-mode passes running after the `check_tells` exit gate; four unbound herdr pane placeholders + lost `open_yazi`/date-strip input defaults + HERDR_ENV skip→stop semantic change; unscoped `decision-memo` composition; missing router legacy-name rows.
- **R2** (`12918e3`): six closed and independently re-verified; router rows deferred (see Notes). 4× APPROVE, two new style should-fixes.
- **R3** (`33aede3`): HERDR_ENV gate scoped stop-vs-skip, yazi opt-out mechanism named. 4× APPROVE.
- **R4** (`ef763d0`, `e84d05d`): the tests lane caught that the merged skill documented a **nonexistent** top-level `herdr wait`. Verified against the installed binary and corrected at all 9 sites to `herdr pane wait-output [--match TEXT|--regex PATTERN] --timeout N <PANE_ID>` and `herdr agent wait <TARGET> --until <STATUS>`, plus the JSON-contract list and prose defaults. A pre-existing origin/main error (the style lane independently confirmed the count: `grep -c 'herdr wait '` → 9 on origin/main), fixed here. 4× APPROVE, every lane re-verifying the CLI surface itself rather than trusting the claim.
- **R5** (`8bd0a8a`, `3d7b659`): the logic lane caught that R4 had silently dropped origin/main's timeout exit-status contract while the PR body claimed it was preserved — restored as a `--help`-grounded clause, and this record corrected. Two PR-body accuracy corrections from the style and logic lanes folded in. 4× APPROVE.
- **R6** (`efb8c81` + this commit): the style lane blocked on a markdownlint **MD038** violation in this PR body that would have failed `pre-commit run --all-files` in CI — and where the hook's own `--fix` was the wrong remedy, since stripping the space would have left a green file with an unsourced claim. Rephrased to cite the command instead. 4× APPROVE.

Rebased twice onto an advancing `origin/main` mid-review (`f0214d9` after #180/#181, then `0f09b1f` after #178/#183 — the latter also edits `workflow-router`, in the routing table rather than this batch's catalog row). Round SHAs above are the current post-rebase ones; each rebase remapped every commit, and only `docs/executions/state.yaml` ever conflicted (kernel-owned, per-run whole-file rewrite). Lane files record every round's verdict and per-finding closure status.

## Test plan

- `lint-skill-refs.sh <worktree skills root>`: 48 explicit refs, 0 dangling (explicit root — the script's default root is the *installed* `~/.claude/skills` tree, a footgun the tests lane caught; follow-up filed)
- `lint-skill-suite.sh`: failures=0 (warnings pre-existing warn-mode)
- `_docs/skills-index.sh --check`: up to date; tombstone descriptions trimmed ≤137 chars so the generated index keeps the full redirect instruction
- `test/routing-eval.sh --dry-run`: 45 cases (18 log-harvested, 27 synthetic), all expected routes present; zero golden cases expect a tombstoned name
- herdr command surface conformance-checked against the installed binary (`herdr --help`, `pane --help`, `pane wait-output --help`, `agent wait --help`, `agent rename --help`, `pane read --help`, `workspace create --help`)
- Ledger run `2026-08-19-skills-consolidation-batch2` (kind=skill) with review + finalize stamps; lane digests in `docs/executions/state.yaml`

## Notes

- Conflict-lane guard: does not touch `design-plan`, `execute-phase`, `to-prd`, `execute-prd`, workflow-router refactor rows, or `reference/workflows.md` (owned by the planning-lane consolidation PR).
- Stale long-tail maps (`AI_ENVIRONMENT.md`, `dotfiles/.claude/SKILLS-MAP.md`) still name pre-batch retired skills from earlier batches too — left for a docs-audit sweep, consistent with prior retirement batches (drift now three batches deep per the style lane; sweep follow-up recommended).
- Deferred router edits (logic F7 / style lane): legacy-name redirect rows for `humanizer-exec` / `stage-v1-concept` and the `herdr-launch` Library/infra row — this batch's router allowance was scoped to the Knowledge/utility catalog counts while the planning-lane consolidation PR owns broader router edits; add the redirect rows in a follow-up once that PR lands (tombstone descriptions carry the redirect meanwhile).
- Follow-up tooling (tests lane): default `lint-skill-refs.sh` root to its own directory like the sibling lints (its current default silently lints the *installed* `~/.claude/skills` tree, so any worktree review that runs it the documented way misattributes its evidence); add a "tombstoned name in live catalog" assertion; the refs extractor doesn't match prose-form handoffs, so this batch's two new cross-skill refs were hand-verified.
- **Kernel gate defect found in passing, affecting this PR's own `verify-local` record** (tests lane, pre-existing, non-blocking): `docs/executions/ci-commands.yaml` invokes `lint-skill-refs.sh` with no argument, so verify-local lints the *installed* `~/.claude/skills` tree rather than the commit it certifies — a green `verify_local` field can attest to the wrong tree. Fix by passing the repo-relative skills root in the manifest, independent of the script-default fix above. Three further manifest gaps against its own "keep in sync with CI gates" header: no `pre-commit run --all-files` (so markdownlint/MD038 — the near-miss this review caught by hand — plus shellcheck, yamlfmt, gitleaks, detect-secrets are all outside verify-local), no `_docs/skills-index.sh --check`, no `test/routing-eval.sh --dry-run`. All four were verified by hand for this PR; the manifest itself is the follow-up.
- Exit-status contract restored, not dropped: origin/main documented "if it times out, exit code is `1`", and the CLI-correction round briefly lost it. It is back as a grounded clause — both `--timeout` flags are documented as "Fail after this many milliseconds", so the skill now states that a timeout exits non-zero and that `if ! herdr pane wait-output …; then` is a valid readiness check. Caught by the logic lane, which also showed the claim was verifiable from `--help` without a live pane.
- One unverified pre-existing claim left as-is rather than guessed at: the spawn recipe's `--match ">"` prompt-readiness wait (any output containing `>` satisfies it — robustness, not security). Predates this batch.
- Future-edit hazard recorded by the logic lane: #180's new wayfinder escalation (full mode) and Step 2.25 promotion (scratch/ephemeral) are disjoint today because full mode requires CONTEXT.md; if that escalation is ever broadened past full mode, both paths consume the same `pending_decision_log_entries`.
- Do not merge without Alex; post-merge Codex mirror via `sync-codex-skills.sh` per Track D.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
