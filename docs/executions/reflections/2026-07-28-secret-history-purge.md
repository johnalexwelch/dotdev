# Session Reflection: History-rewrite secret purge with a live concurrent session

**Date**: 2026-07-28
**Goal**: Purge a (now-rotated) leaked SSH private key from git history in the public `dotdev` repo, after first landing the two open PRs that were blocking a clean rewrite.

## What Went Well

- **Rehearsed the rewrite non-destructively.** Ran `git filter-repo --invert-paths` on a throwaway `--mirror` clone and *verified* the purge (blob-reachability via `git cat-file -e <blob>`, `git log --all -- <path>`, `git rev-list --all --objects | grep <blob>`, and `for-each-ref --contains <commit>`) before touching the remote. The live checkout and remote stayed untouched until verification passed.
- **Paused before the irreversible step.** Laid out the full force-push blast radius (20 branches + 2 open PRs + every clone/worktree) and recommended landing the open PRs first (plan b) instead of rushing the purge on a repo with inert-but-leaked material.
- **Protected-branch force-push handled cleanly.** Enumerated both guards (a rulesets-API `main-protection` ruleset *and* classic branch protection with `allow_force_pushes=false`), snapshotted the classic protection JSON, toggled both down for exactly one push, and restored both to the exact prior state.
- **Correctly diagnosed the "fresh mirror still shows the blob" result** as GitHub-immutable `refs/pull/*/head` snapshots — not a failed purge — and identified the GitHub-Support/GC step as the only remaining closure.

## What Went Wrong / Friction

- **Ran `git reset --hard origin/main` on `~/dotdev` without first checking which branch the checkout was on.** It was the *concurrent session's* active branch `skill/deep-dive-review`; the reset moved their branch pointer to main. Recovered only because (a) their commits were already on the remote and (b) the reflog still held `ca06a03`. This was a near data-loss and a direct hazard the existing habit *almost* covers — but that habit is scoped to *uncommitted changes*, and here the working tree was clean; the hazard was **branch ownership**, not dirty state.
- **`rm -rf grill-with-docs/references/` on a path assumed untracked.** A concurrent fast-forward had made it a *tracked* file (`delegate-mode.md`, landed via #106) between my earlier `git status` read and the `rm`. Showed up as a `D` and had to be reverted with `git checkout --`.
- **Stale mental model of the checkout's state.** Assumed `~/dotdev` was pinned at an old HEAD; a concurrent session fast-forwarded it *twice* during the session (`06e9692` → `b6d2ca2` → … → `f1b75bc`) and switched branches under me. Every re-read returned a different SHA/branch.
- **Push guards discovered serially.** The force-push to main was rejected once by the ruleset, then again by classic protection — two round-trips because I toggled one guard at a time instead of enumerating both up front.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | (Implicit, via framing) rotate the key *first*, then land the blocking PRs *before* the rewrite — steered away from a rushed purge | No standing playbook for secret-history removal ordering | new `purge-git-secret` skill / `cleanup-delivery` |

Most failures this session were **self-caught near-misses**, not user corrections — the strongest signals are the reset-on-wrong-branch and rm-on-tracked-file mistakes.

## Lessons

1. **Treat a shared working checkout as live, unowned state.** In a repo where another agent session is active, the current branch and tracked/untracked status are volatile facts, not remembered ones. Before *any* destructive git op (`reset --hard`, `rm`, `checkout --`, `clean`), re-run `git rev-parse --abbrev-ref HEAD` + `git status` + `git worktree list` *at that moment*, and never `reset --hard` a checkout/branch you don't own.
2. **The hazard in `reset --hard` is broader than uncommitted changes.** It also silently moves the *current branch pointer* — catastrophic when that branch is someone else's in-flight work. A clean working tree is not a safe signal.
3. **A "complete" secret-history purge has a known residual on GitHub.** Force-push clears branch history, but `refs/pull/*/head` PR snapshots and cached commit objects survive until GitHub GC / a Support cache-purge request. Rotation is the real mitigation; the Support request is the closure. Plan both up front.
4. **Enumerate every protected-branch push guard before toggling.** Modern repos can have *both* a rulesets-API ruleset and classic branch protection; check both, snapshot before changing, restore exactly, minimize the open window to a single push.

## Proposed Improvements

- [ ] `docs/agents/habits.md` — extend the existing "Never `git reset --hard`…" bullet: also verify `git rev-parse --abbrev-ref HEAD` and `git worktree list` before destructive ops; in a repo with concurrent agent sessions, never `reset --hard`/`rm`/`checkout --` a checkout or branch you don't own. The hazard is a *shared/foreign checkout and a moved branch pointer*, not only uncommitted changes. (priority: high)
- [ ] `docs/agents/habits.md` — add: tracked/untracked status is *live* state. Re-check `git ls-files`/`git status` immediately before `rm`/`git checkout --`/`git clean` on a path if any time has passed or a concurrent session may have fast-forwarded the tree (this session: an assumed-untracked dir had become a tracked file). (priority: med)
- [ ] new skill `purge-git-secret` (or a section in `cleanup-delivery`) — capture the end-to-end workflow; see extraction candidate below. (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `purge-git-secret` · **target**: `~/dotdev/dotfiles/.config/agents/skills/purge-git-secret/SKILL.md` · **invocation**: user (leading words: "clean the history", "remove secret from git history")
  - **Trigger / leading word**: a committed secret/credential must be removed from git history (typically after rotation).
  - **Inputs**: the secret's path and/or blob SHA; repo remote; confirmation the secret is rotated.
  - **Steps**:
    1. Confirm rotation first (rotation is the real mitigation; history cleaning is hygiene) — completion: user confirms the key/credential is inert.
    2. Scope it: `git log --all -- <path>`, find the blob SHA, confirm no *other* blob/path holds the same material (distinguish a real key from a doc that merely quotes a header). Completion: exactly the target blob/paths identified.
    3. Rewrite on a throwaway `git clone --mirror` (never the live object store) with `git filter-repo --invert-paths --path <path>`. Completion: filter-repo reports commits reparsed.
    4. Verify before pushing: blob unreachable (`git cat-file -e`), 0 objects contain it, path absent from all history, ref count preserved, tree still intact. Completion: all checks green on the mirror.
    5. Land/close open PRs first (rewriting rebases every branch under active work). Completion: 0 open PRs, or explicit go to break them.
    6. Enumerate push guards (`gh api repos/:o/:r/rulesets` + `…/branches/main/protection`), snapshot, toggle down, force-push all refs + main, restore guards exactly. Completion: all heads rewritten, guards restored to snapshot.
    7. Verify remote: fresh mirror shows blob only under `refs/pull/*` (immutable). Completion: no branch head contains it.
    8. Reconcile local checkouts/worktrees and draft the GitHub Support cache-purge request for `refs/pull/*` + GC. Completion: Support draft handed to user.
  - **Success criteria**: no branch/tag on the remote references the secret blob; the only residual is GitHub-controlled `refs/pull/*` + cache, covered by the Support request; all protections restored; live checkouts reconciled without clobbering concurrent work.
  - **Constraints / pitfalls**: run filter-repo on a mirror, not the live repo (it strips `origin`); `refs/pull/*` are immutable and require GitHub Support; dual push guards (ruleset + classic); **never `reset --hard` a checkout you don't own during reconcile**; a doc quoting a key *header* is not the key — don't over-scrub recent history.
  - **Verification evidence**: this session — blob `3fef018…` reachable pre-rewrite, GONE from all 21 heads post-rewrite, residual confined to `refs/pull/*`; protections restored (force-push off, ruleset active); concurrent session's `skill/deep-dive-review` confirmed clean on rebased history.
  - **Quality gate**: googleable=No (filter-repo is googleable, but the dual-guard toggle + `refs/pull/*` residual + concurrent-session safety + rotation-first ordering as one playbook is not a 5-minute lookup) · specific=Yes · real-effort=Yes
  - **Open questions**: should this live as its own skill or a section of `cleanup-delivery`? Is a helper script worth it, or is the risk profile better kept as a human-gated checklist?
