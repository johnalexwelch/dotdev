# D-006 soak-end flip readiness — 2026-08-25

**Verdict: 0 of 4 ready today.** Each has a concrete, small unblock. Read-only investigation; no flips made.

Soak window: 2026-08-18/19 → 2026-08-25.

---

## Next action (<2 min)

Nothing to flip. The single highest-leverage unblock is shipping the repo allowlist that gates entry enforcement — start it by creating the file the design already named:

```bash
mkdir -p ~/dotdev/docs/executions/external && \
  echo "/Users/alexwelch/dotdev" > ~/dotdev/docs/executions/external/repos.txt
```

That is step 1 of flip #1's unblock (the guard still has to *read* it — see below).

---

## 1. `LEDGER_ENTRY_ENFORCE=block` — **NOT-READY**

**Blocker: the repo allowlist never shipped, and the flip cannot be scoped to `dotdev`.**

Three verified facts combine into a brick:

1. **Opt-in is still directory presence.** `dotfiles/.claude/hooks/workflow-guard.sh` rule 4 tests `[ -d "$repo_top/docs/executions" ]` — no allowlist lookup anywhere in the guard or the kernel. `docs/executions/external/repos.txt` does not exist.
2. **Seven repos still carry that directory** with no kernel-shaped ledger state — verified present today in `chorus`, `delphi`, `bookmarks`, `pergamon`, `alexandria`, `circuit`, `insta-scrape`. Multi-repo adoption (`decision-log.md:207`) records that external-root mode and the allowlist are **designed but unshipped**, and that all seven return `exit=1 MISSING: no live ledger state`.
3. **The flip mechanism is machine-global by rule.** `decision-log.md:201` forbids per-session export precisely so enforcement isn't a session lottery — so there is no way to turn this on for `dotdev` only.

Net: setting `LEDGER_ENTRY_ENFORCE=block` in `dotfiles/.claude/settings.json` hard-blocks every tracked-code Edit/Write in seven repos that structurally cannot satisfy the gate — including `chorus` (13 commits in the window) and `delphi` (10). That is D-006 #5's exact rejection case, not a forcing function.

**Unblock (concrete, small):** implement multi-repo adoption item 2 — an explicit allowlist as the *sole* opt-in signal, with directory presence removed from rule 4 entirely (leaving it as a fallback re-arms the trap on the next `/handoff`, which is how all seven acquired the directory).

**Two documentation gaps found while checking this:**

- **No Phase 5a entry-enforcement preconditions exist anywhere.** `decision-log.md:196` asserts they "live in ci.yml comments + PR #175's body" — both were read in full; both are finalize-stamp only. Flip #1's only recorded precondition is decision **#18** (`decision-log.md:124`): "warns (week 1), then exits 2 … warn-first, opted-in repos only." Week 1 has elapsed, so by that line alone #1 would read ready — the allowlist gap is what actually blocks it, and it is recorded in a different entry.
- **Init coverage is not measurable post-hoc.** Entry enforcement fires on absent *init*, and live state lives per-worktree at `.git/ledger/state.yaml`, which is destroyed when a worktree is pruned. Only **1** live state file survives (`worktree-silver-meadow-da6f`) — a lower bound, not a rate. So "how often did the warn fire during the soak" cannot be answered, because the hook writes to stderr only and nothing durable counts it. If you want that instrument before any future flip, it's a small change to `workflow-guard.sh` rule 4.

---

## 2. Router golden eval → required check — **NOT-READY**

**Gap A — the flake is real and still unmitigated. Median-of-3 never landed.** `grep -i median test/routing-eval.sh` → no match. Scoring is still a single run at `PASS*100 >= TOTAL*95` (`test/routing-eval.sh:343`).

Measured oscillation on one branch (`feat/per-run-ledger-snapshots`), successive shas, no meaningful router change:

| run | sha | result |
|---|---|---|
| 32280553867 | 16a7674c | 45/48 = **93% FAIL** (cases 20, 34, 41) |
| 32284044264 | c1024381 | 46/48 = 95% PASS |
| 32286404401 | 38325856 | 46/48 = 95% PASS |
| 32288240524 | 08f257f2 | 46/48 = 95% PASS |
| 32290272122 | 43014c36 | 47/48 = 97% PASS |
| 32290900934 | 9fa9a8d6 | 46/48 = 95% PASS |

48 cases against a 95% bar puts the pass line at 46/48. **The check is one case wide,** and runs land on both sides of it. Case 41 (`expected=decision-log got=direct`) is the same case flagged on 2026-08-19 — neither fixed nor quarantined.

**Gap B — the "all green" evidence was never real.** `gh run list --workflow=routing-eval.yml` reports **65/65 success** because `continue-on-error: true` sits at *job* level, which reports a failed job as a successful run. Step-level truth: **10 of 64** full-eval runs FAILED (Aug 18: 4, Aug 19: 2, Aug 20: 1, Aug 21: 3), plus one dry-run schema failure. Real pass rate ≈ **84%**.

**Gap C — a paths-filtered workflow cannot be a required check.** `routing-eval.yml` triggers only on `workflow-router/**`, `test/routing-eval.sh`, and its own file. Marked required, every PR not touching those paths shows the check permanently pending and can never merge. The flip PR needs an always-reporting skip job.

**Unblock:** median-of-3 (or best-of-3) scoring; fix or quarantine case 41; add the skip job; then re-soak.

---

## 3. Finalize-stamp CI check → required — **NOT-READY (hardest of the four)**

**Gap A — it currently fails on nearly every PR.** Every step conclusion reads `success` because `continue-on-error` sits at *step* level. Scraping the actual verdict line from job logs and collapsing to the latest run per branch, 2026-08-20 → 2026-08-24 (24 PR branches; 45 runs):

- **21 branches FAIL** (87.5%)
- **3 PASS-WITH-NOTE** (docs-only / renovate exemptions: `fix/habits-checklist`, `fix/inline-routing-gate`, `renovate/oxfmt-0.x`)
- **0 genuine gated PASS**

Dominant failure: `FAIL — no run snapshot (docs/executions/runs/*.yaml) changed vs base — the delivery never stamped, or the run file was not committed`. Failing branches include merged PRs #210 (`arch/c1-zed-tests`), #214 (`docs/reflection-test-discovery-gap`), #215 (`worktree/silver-meadow-da6f`), #207, #206, #201, #195. Making this required today blocks ~88% of PRs.

**Gap B — both preconditions recorded at `ci.yml:85-99` are unimplemented,** and they were written as "must be addressed in the flip PR, not after" — so this is not a one-line flip:

1. *Env-breakage-reads-green* — no python3/PyYAML assertion step in the `finalize-stamp` job (the `setup-python` at `ci.yml:16` belongs to Lint), and nothing refuses the warn-permit when `LEDGER_PYTHON` is set. Kernel exit 10 would show a passing required check on a broken runner.
2. *Self-graded gate* — checker, kernel, and workflow file all still come from the PR head. `FINALIZE_CHECK_LEDGER_SH` is unused in `ci.yml`; there is no base-ref copy of `scripts/finalize-stamp-check.sh`; and **no CODEOWNERS file exists** (checked `.github/CODEOWNERS`, `CODEOWNERS`, `docs/CODEOWNERS`).

Also note PR #175's precondition text predates the per-run snapshot migration (#191) — it still says `docs/executions/state.yaml`. Re-read it against the per-run shape before writing the flip PR.

**Unblock:** raise stamp compliance first, then land the two hardening items, then flip.

---

## 4. `LEDGER_REQUIRE_ROUTE=block` — **NOT-READY**

Preconditions at `decision-log.md:196-201`. All four checked:

| # | Precondition | Status |
|---|---|---|
| 1 | Route coverage at/near 100% across an audit window | **FAIL** — only 6 committed run snapshots exist on `origin/main` against 56 merged PRs since 2026-08-18. All 6 *do* carry `route:` (100% of those that exist); the denominator is the problem. |
| 2 | All init call sites pass `--route` | **FAIL** — the named blocker |
| 3 | AFK route provenance decided | **FAIL** — no decision recorded |
| 4 | Flip via machine-global env | mechanism available |

**Precondition 2, verified by grep as the task specified:**

- `workflow-router/SKILL.md:141` — **threads `--route`** ✅
- `workflow-deliver/SKILL.md:21,60` — `ledger.sh init … --workflow workflow-deliver --kind <k> --steps <csv>`, **no `--route`** ❌
- `execute-prd/SKILL.md:156` — references `ledger.sh init --kind bug`, **no `--route`** ❌
- `run-backlog/SKILL.md:148` — references `ledger.sh init --kind bug`, **no `--route`** ❌

Flipping today would exit-11 every `workflow-deliver` init not reached through the router — bricking delivery at init time, the exact failure D-006 #5 rejects.

**Unblock:** thread `--route` through those three SKILL.md init call sites; decide AFK route provenance; re-measure coverage.

---

## The through-line

The soak measured the *warn surfaces*, and the honest reading is that two of them were never measurable and two were measured wrong:

- **Both CI checks' green history was an artifact of `continue-on-error`,** at job level for the eval and step level for finalize-stamp. Anyone reading `gh run list` during the soak saw 65/65 and 89/89 green. The truth is ~84% and ~12.5%.
- **Entry-enforcement's warn had no telemetry at all,** and its blast radius turns out to be seven other repos rather than `dotdev`.

Two of the four flips (#3, #4) share a root cause — deliveries are not reliably stamping run snapshots. That is upstream of every threshold decision here.

## Evidence commands (reproducible)

```bash
# eval: step-level truth, not run-level (job-level continue-on-error masks it)
gh api repos/johnalexwelch/dotdev/actions/runs/<id>/jobs \
  -q '.jobs[].steps[] | select(.name|test("Full routing eval")) | .conclusion'

# finalize-stamp: verdict line, not step conclusion (step-level continue-on-error masks it)
gh run view <run_id> --job <finalize_job_id> --log | grep -o 'FINALIZE_STAMP_CHECK: [A-Z-]*'

# route coverage
git ls-tree -r --name-only origin/main -- docs/executions/runs/ | grep -E '\.ya?ml$'

# entry-enforcement blast radius
grep -n -A12 'Rule 4: entry enforcement' dotfiles/.claude/hooks/workflow-guard.sh
for r in chorus delphi bookmarks pergamon alexandria circuit insta-scrape; do
  [ -d "$HOME/projects/$r/docs/executions" ] && echo "$r: opted in by directory presence"; done
```
