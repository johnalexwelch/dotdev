# Session Reflection: deep-dive ledger reconciliation gap
**Date**: 2026-07-29
**Goal**: Wrap the deep-dive delivery loop — cleanup-delivery + answer "what's still open?" — after FIND-4 shipped.

## What Went Well
- `cleanup-delivery` classification held: trusted **PR state over git ancestry** (all 5 merged `deep-dive/*` branches were squash-merges that `git branch -d` would refuse; confirmed MERGED via `gh pr view` before `-D`). Kept the current-checkout branch and all unrelated worktrees untouched.
- Honored the isolated destructive gate: user said "approved" to the plan but hadn't picked a query-extract option, so I deleted the local branch (closed PR, superseded) and **held the remote deletion** until an explicit "prune" — then re-checked #1588 was CLOSED immediately before `git push --delete`.

## What Went Wrong / Friction
- **Latent ledger defect only surfaced because the user probed.** The user asked "how do I know the open findings if they're not in the survivors list?" — that question, not my own diligence, exposed that the ledger had two run-sections with **independent per-run FIND-N numbering** and the 2026-07-28 section's verdicts (FIND-2/3/4/5) were never flipped when the same issues shipped under the 2026-07-29 renumbering. The ledger was silently lying about 4 "open" findings that were all merged. I should have caught this during the Step-5 ledger update, not on a user question.
- Repeated `gh auth switch --user alexwelch-dojo` defensively before nearly every `gh` call (default account 404s the repo). Already flagged in the prior reflection's session-insight; recurring.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| — | (none — questions were clarifying, but one exposed a real defect below) | | |

## Lessons
1. **Per-run finding numbering + a per-run ledger-append = stale-verdict rot.** `deep-dive-review` numbers findings `FIND-N` *per run* and Step 5 only writes *this run's* processed findings. A finding carried across runs gets a new number and a new section; its old section's verdict is never reconciled. Over runs the ledger accumulates `deferred`/`needs_human` entries that no longer reflect reality — and Step-0 loop-check reads those verdicts. The ledger already has a **stable fingerprint** (`lens:file:line:signal`) used for loop detection; that, not `FIND-N`, should be the reconciliation key.
2. **"What's open?" is a first-class query with no affordance.** The survivors HTML is ephemeral (tmpdir, per-run); the durable list is the ledger, but nothing documents how to read open state between runs.

## Proposed Improvements
- [ ] `deep-dive-review/SKILL.md` Step 5 — add a **reconciliation pass**: before appending this run's findings, match each against prior-section entries by fingerprint; when a prior `deferred`/`needs_human` finding is now shipped/rejected, flip its old verdict to `SUPERSEDED → <new state>` in place (or key the ledger by fingerprint so there's ONE entry per issue, updated, not a new numbered copy). Cite: this session had to hand-reconcile 4 stale 07-28 verdicts. (priority: **high** — corrupts loop-detection input)
- [ ] `deep-dive-review/SKILL.md` — document the between-runs open-findings query: `grep -cE 'verdict: (needs_human|deferred|parked)' ~/.deep-dive/<slug>.md` (and note the survivors HTML is ephemeral, ledger is source of truth). Optionally a `--status` read-only mode. (priority: med)
- [ ] `deep-dive-review/SKILL.md` Step 0 preflight — assert `gh repo view <origin>` resolves (switch/abort early) so finalize/cleanup gh calls don't need per-call account juggling. (priority: low — dup of prior reflection; promote if it recurs a third time)

<!-- No Skill Extraction Candidates: all fixes belong inside deep-dive-review; no new repeatable standalone workflow emerged. -->
