# Session Reflection: A10 example/tutorial dbt model removal

**Date**: 2026-07-23
**Goal**: Finish A10 — remove disabled example/tutorial dbt models from analytics gold, preserve the onboarding scaffold, prove no orphaned tables, open a housekeeping PR.

## What Went Well
- Re-verified pre-conditions before deleting (both still `enabled=false`, zero `ref()` dependents, not in any yml) rather than trusting the audit SHA blindly.
- Caught that the task's suggested docs path (`.agents/skills/dbt/references/`) was locally git-excluded (`.git/info/exclude`) via `git check-ignore` before committing a file that would never land — relocated to a tracked path.
- Deferred the warehouse read-only check honestly when `REDSHIFT_URL` was unset instead of fabricating a result; ran it for real once creds appeared (0 rows, clean).
- Ran `receive-review` judgment on both bot nits; both were cheap in-file improvements so actioned rather than deferred.

## What Went Wrong / Friction
- **Command-wrapper mangled `grep` and piped output repeatedly.** `grep -rn "example_model" ...` and `... | grep` returned bogus repo-wide dumps ("35953389 matches in 95679 files") instead of the scoped result. Cost several wasted calls before switching to the native `grep` tool, which worked first try.
- **`psql` heredoc stdout swallowed 3×** (empty output) — the wrapper / "never pipe output" path ate it. Only `psql -o <file>` / `-f <file>` + reading the file worked.
- Both above are environment-level (rtk/hypa/caveman wrapping) but recurred enough to be a real drag.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "you can switch to my work gh account" | Abandoned `gh pr create` after one 404/SSO error without running `gh auth status` to check for other authenticated accounts — the work account was already logged in | pr-responder / git-guardrails |
| 2 | "you can in herdr" | Said "no side-pane tool here" while a loaded `herdr` skill does exactly split-pane review; dismissed a capability without checking loaded skills | herdr |

## Lessons
1. **On a gh 404 / "could not resolve repository", enumerate accounts before giving up.** `gh auth status` lists all authed accounts; org repos often need a different one via `gh auth switch`. A 404 is frequently an auth/SSO scope problem, not a missing repo.
2. **Check loaded skills before declaring "no tool for that."** A `herdr` skill was active the whole session; "open in a side pane" maps directly to `herdr pane split` + `pane run`. Reflex: scan available affordances before answering "can't."
3. **Under the output wrapper, prefer native tools over `grep`/piped shell.** The native `grep` tool and file-redirect + read are reliable; `grep -rn`/`cmd | grep` in bash are not.

## Proposed Improvements
- [ ] `pr-responder` / `git-guardrails` — add: "If `gh` returns 404 / 'could not resolve repository', run `gh auth status` and try `gh auth switch` to an alternate authed account before falling back to manual PR creation." (priority: med)
- [ ] `herdr` — add a trigger note: user asks to "open / review / show X in a side pane / split" → `herdr pane split <focused> --direction right --no-focus` then `herdr pane run`. (priority: med)
- [ ] `redshift` — add to Troubleshooting: "If psql prints nothing (output wrapper swallows heredoc stdout), use `psql -f query.sql -o out.txt` and read the file." (priority: low)
- [ ] Personal habit doc — "Before answering 'no tool for that', scan currently-loaded skills." (priority: low)

## Skill Extraction Candidates
<!-- none: no new repeatable multi-step workflow cleared the quality gate; findings fold into existing skills -->
