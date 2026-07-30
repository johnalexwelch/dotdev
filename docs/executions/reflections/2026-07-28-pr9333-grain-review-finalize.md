# Session Reflection: PR #9333 gold-grain review, reply-posting, and finalize

**Date**: 2026-07-28
**Goal**: Fix reviewer findings on PR #9333 (declare gold model grain in YAML), post humanized review replies, verify grains empirically, and run workflow-finalize.

## What Went Well

- **Ground-truth over proxy, repeatedly.** Rather than trust the review reasoning that 14 grains were "false positives," ran a Redshift `COUNT(*)` vs `COUNT(DISTINCT grain)` falsifier over full history (3.44B / 9.63B / 520.7M rows → 0 dupes; trial_starts 0 dupes post-cutoff). Empirical proof, not argument.
- **Review-freshness discipline held.** workflow-finalize correctly flagged that 4 commits were pushed after the workflow-review APPROVE gate; closed it with an independent fork re-review (separate context = genuinely independent) instead of self-attesting.
- **PR state via REST fallback.** When GraphQL (`gh pr checks`, `gh run list`) 404'd under the SAML-scoped account, fell back to `gh api repos/.../pulls/9333` REST which worked — enough to ground-truth `mergeable_state: blocked`.
- **Humanizer gate enforced to 0** before posting 9 replies; one semicolon tell caught and split.

## What Went Wrong / Friction

- **`gh` active-account flip cost two detours.** Active account silently sat on `johnalexwelch` (no repo access) → 404 on every write. Switched to `alexwelch-dojo`; then a later `git fetch origin` RE-flipped the active account, 404-ing the very next `gh api` call. Had to `gh auth switch` a second time mid-run.
- **CI was unpollable from this account.** `alexwelch-dojo` lacks Actions/checks scope + GraphQL (SAML): `ci_find` aborted, `gh run list`, `gh pr checks`, `commits/<sha>/check-runs`, `actions/runs?head_sha=` all 404'd. watch-ci (finalize Step 3) could not complete; fell back to "pre-push hooks passed locally + hand the human the /checks URL."
- **`||` SQL concat mangled inside the psql heredoc.** `... || '|' || ...` was interpreted by the bash-tool wrapper as shell OR and injected `hypa -c`, erroring the query. Had to rewrite compound-grain checks with nested `SELECT DISTINCT` subqueries.
- **edit tool atomicity bit me after a reformat.** A multi-block `edit` call failed wholesale because one `oldText` no longer matched (ruff had reformatted the file between calls), silently dropping the import-addition and one type-arg fix → a second mypy round. Lesson: re-read after any formatter run; a single non-matching block voids the whole edit call.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | (self-corrected, no user redirect) auth flip → 404s | `gh` active account not pinned; `git fetch` re-triggers credential helper | receive-review (auth-flip note); habits.md |
| 2 | (self-corrected) CI unpollable | workflow-finalize assumes gh can read Actions; no SAML/scope fallback | workflow-finalize (watch-ci step) |
| 3 | (self-corrected) `\|\|` heredoc breakage | bash-tool wrapper interprets `\|\|` outside quotes even in `<<'EOF'` body | redshift SKILL.md |

No user-initiated corrections this session — user steered by approving next steps (draft replies → fix issues → push → post → pros/cons → falsify → finalize → review). Findings below are Pass-B opportunities.

## Lessons

1. **Pin the gh account for the whole run, and re-assert after any git network op.** A `git fetch`/`pull` can silently re-flip the active account via the credential helper, so a single `gh auth switch` at the start is not durable. Re-check `gh auth status` (or pass `-R owner/repo` and rely on REST) after fetches.
2. **A SAML-scoped delivery account may read PR REST but not Actions/checks/GraphQL.** workflow-finalize's watch-ci needs an explicit fallback: pre-push/pre-commit hooks as local CI evidence + hand the human the `/pull/<n>/checks` URL, and record `ci: unverifiable_via_api` rather than claiming green or halting hard.
3. **Avoid `||` string concat in psql-via-bash-tool heredocs.** Use nested `SELECT DISTINCT col_a, col_b` subqueries (or `CONCAT`) for compound-key uniqueness checks; `||` gets shell-mangled even inside a single-quoted heredoc under this bash wrapper.
4. **Grain declarations are cheaply falsifiable — do it.** `rows_total` vs `COUNT(DISTINCT grain)` (windowed to the documented valid range for partial-coverage keys) empirically proves or breaks a declared `meta.grain` in one query. Beats reasoning about `where:`-scoped unique tests.
5. **Re-read a file after a formatter touches it before the next edit; edit calls are all-or-nothing.** One stale `oldText` block silently drops every edit in the call.

## Proposed Improvements

- [ ] `redshift/SKILL.md` — add a Troubleshooting/gotcha row: "`||` string concat inside `<<'EOF'` heredocs is mangled by the bash-tool wrapper (interpreted as shell OR). For compound-key/grain uniqueness use nested `SELECT DISTINCT a, b` subqueries or `CONCAT()`." (priority: med)
- [ ] `redshift/SKILL.md` — add a one-liner grain-falsifier recipe: `rows_total` vs `(SELECT COUNT(*) FROM (SELECT DISTINCT <grain> FROM t [WHERE <valid-range>]))`; note windowing for partial-coverage keys. (priority: med)
- [ ] `workflow-finalize/SKILL.md` — Step 3 (watch-ci): document the SAML/scope fallback — when `gh` cannot read Actions/checks for the delivery account, use pre-push/pre-commit hooks as local CI evidence, hand the human the `/checks` URL, and record `ci: unverifiable_via_api` (not a hard halt in an interactive session). (priority: med)
- [ ] `receive-review/SKILL.md` (and/or `docs/agents/habits.md`) — strengthen the auth-flip note: pinning `gh auth switch` once is not durable; a `git fetch`/`pull` can re-flip the active account, so re-assert or prefer `-R owner/repo` + REST after any git network op. (priority: high)
- [ ] `docs/agents/habits.md` — generic tool-discipline habit: after a formatter (ruff/prettier) rewrites a file, re-read before the next `edit`; a single non-matching `oldText` voids the entire (atomic) edit call. (priority: low)

## Skill Extraction Candidates
<!-- none — the grain-falsifier is a 1-line recipe that belongs in redshift/SKILL.md, not a standalone skill; fails the "took real debugging to discover" bar as a new skill. -->
