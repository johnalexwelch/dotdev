# Session Reflection: Verifying a handoff fix + the Stow-seam path drift
**Date**: 2026-07-16
**Goal**: Resume a handoff to fix `handoff/SKILL.md` repo-name derivation; user asked to *assess* the proposed fix rather than apply it blindly.

## What Went Well
- Refused a blind "commit and merge": verified git ancestry **and** diffs/mtimes (authoritative) before acting — caught that the worktree was a stale ancestor whose uncommitted WIP would have reverted main's k9s/mise + re-added silicon.
- On "assess if this is good advice", empirically ran the proposed fix in **all four cwd contexts** (worktree/main × root/subdir) instead of trusting the handoff's "proof it works" — caught a real subdir bug (`--git-common-dir` returns `../.git`, case logic yields `..`).
- Recovered cleanly when `git add` failed with "beyond a symbolic link" — surfaced the real source path.

## What Went Wrong / Friction
- The handoff's proposed fix was presented as ready, with "proof it works" — but that proof only exercised the **worktree root**. A blind apply would have shipped a subdir regression.
- My first alternative (`--absolute-git-dir` with a `%/.git/worktrees/*` strip) *also* had a bug (double-appended `.git`, yielded `.git`). Took a second empirical pass to land `basename "${agd%%/.git*}"`.
- The commit failed because the handoff (and skills) name `dotfiles/.claude/skills/...` as the source — but that's a **symlink** to `dotfiles/.config/agents/skills/`. Had to retry against the real path.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Twice steered "evaluate / assess if this is good advice" instead of letting me execute | Handoff-follow flow has no built-in "verify proposed fix against ground truth before applying" step | `session-insight` (skill-editing governance) |

## Ground-truth vs proxy (dominant theme)
- **Proxy**: handoff doc's "proof it works". **Authoritative**: running git in a subdir → disproved it. Authoritative won.
- **Proxy**: skills/handoff naming `dotfiles/.claude/skills/` as source. **Authoritative**: filesystem symlink (`-> ../.config/agents/skills`), enforced by git ("beyond a symbolic link"). Authoritative won.

## Lessons
1. **A proposing session's "proof" is a proxy.** Re-verify a code fix against authoritative execution in its *edge* contexts (subdir, worktree, no-arg) before applying — not just the happy path the author tested.
2. **Skill source paths drift.** `.claude/skills` is now a symlink to `.config/agents/skills` (the "hoist to neutral ~/.config/agents" refactor). Hard-coding the old path is the exact Stow-seam defect the skills warn about (#19). Resolve the canonical path instead of trusting a literal.
3. **`--absolute-git-dir` + `${agd%%/.git*}` is the worktree+subdir-safe repo-name idiom.** `--show-toplevel` (transient slug) and the `--git-common-dir` case-glob (relative `../.git` from subdirs) are both fragile.

## Proposed Improvements
- [ ] `session-insight/SKILL.md` — Contract line + Process step 4 name `~/dotdev/dotfiles/.claude/skills/<name>/SKILL.md` as the Stow **source**, but that path is now a symlink to `.config/agents/skills/`. Update both refs to `~/dotdev/dotfiles/.config/agents/skills/<name>/SKILL.md`, and add: "resolve with `readlink -f` before editing/committing — do not `git add` through the symlink." (priority: **high** — evidence: my commit failed "beyond a symbolic link"; this skill is the sole remaining hard-coder of the stale path, 2 refs.)
- [ ] `session-insight/SKILL.md` — Process step 1 (Pass A, ground-truth): add an explicit check "when resuming a handoff that proposes a code/skill fix, re-run the fix in its edge contexts before applying; the author's 'it works' is a proxy." (priority: **med** — evidence: correction #1, the subdir bug.)
- [ ] `setup-worktree/SKILL.md` — audit its `--show-toplevel` usage for any *stable-identity* derivation that would break under a worktree (verify-only; may be legit for the worktree path itself). (priority: **low**)
- [ ] Cross-skill idiom — the `--absolute-git-dir` repo-name derivation now lives in `handoff/SKILL.md`; if `setup-worktree` or others need a stable repo identity, reference the same idiom rather than re-deriving. (priority: **low**)

_Note: already folded into `handoff/SKILL.md` this session (committed + pushed + codex-mirrored): the corrected `--absolute-git-dir` derivation, the two-part naming clause, and a compute-then-literal note._
