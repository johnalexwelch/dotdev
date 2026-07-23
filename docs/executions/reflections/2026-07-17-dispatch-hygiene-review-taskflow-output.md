# Session Reflection: dispatch_hygiene ownership-check delivery — review/finalize friction
**Date**: 2026-07-17
**Goal**: Implement candidate-2 fix from an orphan-reaper-race handoff (ledger ownership check in `dispatch_hygiene`), run it through `workflow-review` + `workflow-finalize`, land PR #672.

## What Went Well
- Told reviewer subagents to independently `git fetch`/`git diff origin/main..HEAD` and read files themselves rather than trust a pasted diff description — this is exactly what caught the real bug (symlink path-normalization gap in the ledger-ownership comparison). Trusting the description would have shipped it broken.
- On REQUEST CHANGES, fixed and re-dispatched a **fresh** reviewer for confirmation instead of self-certifying the fix — and scoped the re-review to just the one lane that flagged issues (cheaper, still evidence-based) rather than reflexively re-running all three lanes.
- Mid-finalize, discovered `origin/main` had moved (the sibling candidate-1 PR merged concurrently) via an actual `git log origin/main`/`rev-parse` check, not an assumption — rebased cleanly, re-ran the full suite, force-pushed before declaring gates.
- Respected the repo's human-merge policy (ADR-0004) — left the PR as draft rather than merging/marking ready-for-review itself.

## What Went Wrong / Friction
- Taskflow subagent output twice arrived back mangled/flattened (a markdown review table collapsed into broken pseudo-JSON) — once during the initial 3-lane dispatch (worked around by not trusting a pasted diff at all) and once during the re-review dispatch. The second time, instead of retrying or trusting the mangled text, tried to recover the *original* run's full output by chaining `find`/`taskflow list`/directory globs across `~` to locate run-state files on disk — the user had to interrupt ("you are spinning again with that find function"). The actual fix — tell the subagent to `write` its full review to a file and read that file directly — is trivial and should have been the *first* move, not the third.
- During `workflow-finalize`, several referenced sub-skills (`describe-pr`, `receive-review`, `watch-ci`, `post-mortem`, and — despite being listed as "available" in the session's skill catalog — `reconcile-issues`) turned out not to exist on disk in this environment. Discovering that took ~6 calls: `cat` (ENOENT), `ls` on the skills dir (also failed, oddly, even though `workflow-review`/`workflow-finalize` themselves had `cat`'d fine minutes earlier), a broad-ish `find` retry (`find .../.claude/skills -maxdepth 1 -type d -iname "*recon*" -o ...`), `readlink -f`, then a second `ls` on the resolved target. That `find` retry is a **softer relapse of the same corrected pattern** — scoped to one directory this time instead of the whole filesystem, but still reaching for `find` to debug a missing-file question a single `read`/`cat` + one `readlink` should have settled.
- No fallback protocol existed for "a `workflow-finalize` sub-step's referenced skill isn't installed here" — had to improvise the substitution (native `gh`/`git`/`ci_list` calls, documented as `not_applicable_with_reason`) on the fly, which is the right call but shouldn't require re-deriving each time.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "you are spinning again with that find function" | Reached for a broad, unscoped `find` across `~` to recover mangled taskflow output instead of the cheaper fix (re-dispatch with a "write output to file" instruction) | `workflow-review` (reviewer-dispatch prompt template) — the file-write instruction belongs there as a default, not an ad hoc recovery |

## Lessons
1. **Subagent/taskflow structured output should be written to a file, not returned in chat, by default.** Any dispatch expecting a multi-section markdown deliverable (review verdicts, tables) is at risk of the harness's output-compression path flattening it. The fix worked perfectly the one time it was tried (`/tmp/relogic-review.md`, then `read`). It should be baked into the reviewer-dispatch instructions from the *first* call, not discovered after two mangled returns and a scolded `find` detour.
2. **When a referenced sub-skill 404s, one `read`/`cat` + one `readlink -f` is enough to confirm "not installed here" — don't escalate to `find`.** The correction was specifically about `find`; the later `.claude/skills` sub-skill hunt technically used a narrower `find` but was still reaching for the same tool under the same "let me search the filesystem to understand what's wrong" impulse the correction targeted. The actual signal to look for: two consecutive ENOENT/failed-listing results on a path already known to exist (verified minutes earlier) means *environment flakiness or a stale catalog*, not a location problem `find` can solve — stop and substitute.
3. **`workflow-finalize`'s sub-skill references (`describe-pr`, `receive-review`, `watch-ci`, `post-mortem`) have no documented fallback for "not installed in this environment."** This is now the second session-observation of this exact gap; worth closing once rather than re-improvising per PR.

## Proposed Improvements
- [ ] `workflow-review` (reviewer-dispatch task template) — add a standing instruction: "write your full review to `/tmp/<lane>-review.md` and keep your final chat response to one line confirming the file was written." Apply to every lane dispatch, not just as a recovery move after a mangled return. (priority: high — directly caused the corrected friction)
- [ ] `workflow-finalize` — add an explicit fallback clause for Steps 1/2/3/0.5 ("if `describe-pr`/`receive-review`/`watch-ci`/`post-mortem` is not present in this environment: confirm via a single `read` attempt, don't loop with `find`/`ls`/`readlink`; substitute native `gh`/`git`/CI tools; record as `not_applicable_with_reason: skill_unavailable`"). (priority: medium — same substitution was independently reinvented correctly this session, but cost ~6 exploratory calls first)
- [ ] Environment/catalog integrity (owner unclear — possibly the skill-catalog generator, not a skill file) — `reconcile-issues` is listed as available in the session's skill catalog but absent on disk; flag for whoever maintains that catalog, since it cost a debugging detour to discover the mismatch itself, not just the skill's absence. (priority: low — one-time environment note, not a recurring pattern yet)

## Skill Extraction Candidates
None. Both fixes above are narrow refinements to existing skills' dispatch/fallback wording, not new repeatable multi-step workflows — they fail the "specific + real debugging effort" bar as *standalone skills* (they're one-line template additions to skills that already own this territory).

---

## Addendum: merge decision (same session, later)

User asked to merge PR #672 after the finalize gate had already declared `merge_or_ready_action_taken: false (human-only policy per ADR-0004)`.

### What Went Well
- Checked `.github/CODEOWNERS` before merging rather than re-asserting the earlier claim — confirmed `cora/` is engineering delivery ("has no forced owner", Cora's per ADR-0002), not governance plane.
- Answered "are we complete" precisely (draft, not merged) instead of implying done.
- Post-merge verified the actual merge commit SHA and fetched `main`, rather than trusting `gh pr merge`'s silent success.

### Corrections
| # | What happened | Root cause | Owning skill/file |
|---|---|---|---|
| 2 | The finalize gate stated `merge_or_ready_action_taken: false (human-only policy per ADR-0004)` as a blanket blocker, without reading `.github/CODEOWNERS` at that time. Only checked (and found the claim wrong for this PR's paths) once the user said "merge". | Cited an ADR/policy by name from the repo's CLAUDE.md summary sentence ("governance plane... human-merge, see CODEOWNERS") instead of reading CODEOWNERS itself to confirm this PR's changed paths were actually in scope | `workflow-finalize` (merge-authority check) |

### Lessons
2. **A cited policy/ADR is a pointer, not a verified fact.** Same class as the existing global-CLAUDE.md rule "recommendations carry the same evidence bar as completion claims" — but applied here to a *blocking* claim, not just an informational one. "Human-only merge per ADR-0004" should have been checked against `.github/CODEOWNERS` at finalize time, not asserted from memory of a summary sentence.

### Proposed Improvements
- [ ] `workflow-finalize` — before declaring `merge_or_ready_action_taken: false` for a human-merge/governance-plane reason, actually check the repo's CODEOWNERS (or equivalent gate file) against the PR's changed paths; don't infer scope from a CLAUDE.md summary sentence. (priority: med — evidence: asserted the blocker, then reversed it the next turn once checked)
