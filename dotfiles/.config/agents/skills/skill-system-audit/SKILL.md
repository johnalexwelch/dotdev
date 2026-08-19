---
name: skill-system-audit
model: sonnet
reasoning: high
description: Evaluate whether skills and workflows are actually working. Audits recent agent transcripts, GitHub PRs/issues, and execution artifacts for skipped steps, missing subagents, unresolved review comments, weak handoffs, and routing gaps.
codex-compatible: true
---

# Skill System Audit

## Purpose

Measure whether the skill system is producing the behavior it promises. This is a governance and feedback-loop skill: it finds places where workflows were invoked but required steps were skipped, degraded silently, or produced weak outcomes.

Use this when the user asks:

- "Are these skills working?"
- "Evaluate workflow effectiveness"
- "Find gaps in our workflows"
- "Why did this workflow skip a step?"
- "Audit recent agent transcripts"
- "Did PRs merge with unresolved review comments?"

## Contract

Consumes: recent agent transcripts, skill files, GitHub PR/issue state, docs/executions artifacts, optional CORA findings
Produces: workflow effectiveness scorecard, gap findings, recommended skill/workflow fixes
Requires: git
Side effects: none by default; may create follow-up issues only with approval
Human gates: approval before editing skills, creating issues, or applying labels

## Context

Typical workflows: skill library governance, weekly workflow retro, post-incident review after agent misses
Pairs well with: skill-maintenance, reconcile-issues, receive-review, workflow-router

## Load References

Load only the references needed for the step in progress:

- Step 2 (expected traces): `references/expected-traces.md` — per-workflow required trace table.
- Step 4 (gap patterns): `references/gap-patterns.md` — the numbered checklist of known gap patterns.

## Workflow Progress Reporting

Follow `../_docs/step-ledger.md` (step-ledger protocol): emit the `WORKFLOW_STEPS` ledger before executing or dispatching any step, update it at every status transition, and include the final ledger in every halt, handoff, and completion response.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

## Process

### 1. Define audit window

Default to the most recent 7 days or the latest 20 parent transcripts. If the user names a repo, PR, issue, or workflow, scope to that.

Collect evidence from:

- Parent agent transcripts only for user-facing behavior. Use subagent transcripts as supporting evidence, but cite parent transcript IDs to the user.
- `~/.claude/skills/` and `~/.codex/skills/` for the current skill definitions.
- `docs/executions/` artifacts: phase runs, handoffs, CI runs, PR bodies, retros.
- GitHub PRs/issues via `gh` when available.
- CORA findings when CORA is available.

### 2. Build expected workflow traces

Load `references/expected-traces.md` and, for each workflow invocation, derive the expected trace from its per-workflow table.

Mark each required step as:

- `done`: evidence exists
- `skipped-with-reason`: explicitly skipped with a valid reason
- `skipped-silently`: expected step missing and no reason recorded
- `failed`: attempted but did not complete
- `unknown`: evidence missing or ambiguous

### 3. Score effectiveness

Produce a scorecard with these dimensions:

| Dimension | What to measure |
|-----------|-----------------|
| Routing accuracy | Did the router pick the right workflow for the user request? |
| Step compliance | Were required workflow steps completed or explicitly skipped? |
| Review coverage | Did `workflow-review` choose the right `review_profile` and produce independent review evidence for required lanes? |
| Review resolution | Were PR review comments fixed, replied to, waived, or followed up before merge? |
| Issue hygiene | Were Closes/Fixes/Addresses dispositions used correctly? |
| Verification quality | Were tests/CI/lints actually run and evidenced? |
| Handoff quality | Did halts and completions produce usable handoff artifacts? |
| Autonomous backlog safety | Did module PRDs/issues preserve provenance, candidate confidence, grill-with-docs module answers, MODULE_GRILL_CONSENSUS artifacts, CONTEXT/ADR updates when needed, scoped second-pass decisions, rollback expectations, queue approval, outage-risk controls, AFK execution-chain evidence (including `tdd` or explicit non-applicability), post-auto-merge follow-through evidence when applicable, and all gate blocks per PR? |
| Sync health | Did Claude/Codex skill copies and Stow source remain aligned? |

Use a simple rating:

- `green`: no material misses
- `yellow`: minor gaps or justified skips
- `red`: required step skipped, unsafe merge behavior, or lost context

### 4. Detect known gap patterns

Load `references/gap-patterns.md` and always check for every numbered pattern in that checklist.

### 5. D-006 scoreboard (metrics)

Compute and report all four metrics every run (D-006 #15). Recipes are commands, run from the repo root of the opted-in repo (dotdev unless the audit is scoped elsewhere).

**Golden-eval pass rate** — bar: >= 95%. Compare against the baseline history in `docs/executions/plans/` (`2026-08-19-router-eval-baseline.md`) and report the delta.

```bash
./test/routing-eval.sh --model sonnet   # --dry-run for schema-only when no API key
```

**Gate coverage + override rate + route-evidence coverage** — one loop over merged PR heads computes all three. Route-evidence coverage (D-006 Phase 5b): % of merged runs whose snapshot carries a top-level `route:` field; trend toward 100% as runs init through workflow-router, and report it alongside gate coverage. Gate coverage: % of merged PRs since the last audit whose head snapshot carries a `stamps.finalize` entry; target 100%. Deps PRs are filtered in the loop; docs-only PRs (same classification as `scripts/finalize-stamp-check.sh`) must be excluded by hand before comparing to the 100% bar. Override rate: `overrides[]` entries plus active stamp overrides across the same heads, reasons verbatim; healthy ~0-2/month with real reasons — a spike means fix the gate, not the metric.

```bash
SINCE=<last-audit-date>   # YYYY-MM-DD
gh pr list --state merged --search "merged:>=$SINCE" --json number,headRefName \
    --jq '.[] | "\(.number) \(.headRefName)"' |
    while read -r pr ref; do
        case "$ref" in
            renovate/* | dependabot/*)
                echo "PR #$pr: exempt (deps branch $ref)"
                continue
                ;;
        esac
        git fetch -q origin "pull/$pr/head" || {
            echo "PR #$pr: head unfetchable"
            continue
        }
        # Per-run snapshots (2026-08-19): the PR's run files are the
        # docs/executions/runs/*.yaml it changed vs its base. The legacy
        # shared state.yaml fallback applies ONLY to pre-migration heads
        # (no runs/ tree at the head) — an unconditional fallback would read
        # the frozen legacy stamp and score unstamped post-migration PRs as
        # "stamped", inverting the metric. Post-migration heads with no run
        # file are UNSTAMPED, full stop.
        head_sha=$(git rev-parse FETCH_HEAD)
        base_sha=$(git merge-base "$head_sha" origin/main)
        # :(glob) pathspecs keep '*' from crossing '/' — nested run files are
        # never kernel-authored and must not enter the loop. Non-squash-merged
        # heads (merge-base == head, empty diff) read UNSTAMPED — the
        # conservative direction; verify those by hand.
        run_files=$(git diff --name-only "$base_sha" "$head_sha" -- ':(glob)docs/executions/runs/*.yaml' ':(glob)docs/executions/runs/*.yml')
        if [ -z "$run_files" ] && ! git cat-file -e "$head_sha:docs/executions/runs" 2>/dev/null; then
            run_files="docs/executions/state.yaml"
        fi
        if [ -z "$run_files" ]; then
            echo "PR #$pr: UNSTAMPED (no run snapshot changed)"
            continue
        fi
        # Unquoted word-split is safe: run_ids reject whitespace (kernel
        # allowlist), so run-file paths never contain spaces.
        for f in $run_files; do
            git show "$head_sha:$f" 2>/dev/null |
                "${LEDGER_PYTHON:-python3}" -c '
import sys, yaml
pr = sys.argv[1]
doc = yaml.safe_load(sys.stdin) or {}
stamps = doc.get("stamps") or {}
print(f"PR #{pr} [{sys.argv[2]}]:", "stamped" if "finalize" in stamps else "UNSTAMPED")
print(f"PR #{pr} route:", doc.get("route") or "ABSENT")
for e in doc.get("overrides") or []:
    print(f"PR #{pr} overrides[]:", e)
for gate, s in stamps.items():
    o = (s or {}).get("override") or {}
    if o.get("active"):
        print(f"PR #{pr} {gate} override:", o.get("reason", ""))
' "$pr" "$f"
        done
    done
```

**Repo activity — count the remote-tracking default branch, after a fetch, over an absolute window.** Activity figures decide which repo an audit prioritises, so the method has to be pinned or the priority order is an artefact of the command. Five ways to get this wrong, all observed in the 2026-08-19 cross-repo audit, each one silent:

- **Local branch instead of remote-tracking ref.** `git log main` counts the checkout, not what landed. chorus's local `main` was 102 commits behind `origin/main`; the local count read 7 against a true 13. Never strip the `origin/` prefix off the resolved ref.
- **No fetch.** A remote-tracking ref last updated days ago under-counts by however much has landed since, and reports it as fact.
- **Assuming the default branch is `main`.** `taro`'s `origin/HEAD` is `origin/staging`; counting `main` gave 2 where the gated branch had 30. Treat `origin/HEAD` as the suggestion and confirm it against the repo's actual convention.
- **`--all` when the claim is about gates.** All-refs counts bot branches and every local worktree: dotdev read 38 on its default branch and 449 across all refs as of 2026-08-19 17:00 (all-refs drifts every time any worktree commits — 451 within the hour, which is why an all-refs figure needs an as-of stamp to mean anything). Use `--all` only for "how much agent activity happened", and label it that way.
- **Relative windows.** `--since="7 days ago"` is unreproducible; a later re-run cannot tell drift from error. Record an absolute boundary.

Getting this wrong is not a rounding error. The same audit, same window, ranked its repos ml-models 20 / delphi 9 / chorus 7 / taro 2 on local branches — and taro 30 / ml-models 20 / chorus 13 / delphi 10 once the refs were fetched and resolved correctly. The leader changed, and the repo the audit had dismissed as negligible was the most active one. Report every figure as `N commits on <ref> since <absolute timestamp>`, naming the ref.

```bash
SINCE="2026-08-12 17:00"   # absolute window open; never "7 days ago"
AS_OF="2026-08-19 17:00"   # when refs were fetched; report it with every figure
for repo in "$@"; do
    git -C "$repo" fetch -q --prune --all   # stale tracking refs under-count silently
    ref="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
    ref="${ref:-origin/main}"  # assign-then-default: `| sed … || echo main` never
                               # fires, because sed exits 0 whatever git returned
    # Every remaining silent-zero door is the same shape: a ref name that looks
    # fine and resolves to nothing. `git log` prints nothing, `wc -l` prints 0.
    # `continue`, never `exit` — an abort here drops every later repo from the
    # sweep while printing one line that looks like a handled edge case.
    git -C "$repo" rev-parse --verify --quiet "$ref" >/dev/null || {
        echo "$repo: default ref $ref does not resolve — figure withheld"
        continue
    }
    n="$(git -C "$repo" log "$ref" --since="$SINCE" --oneline | wc -l | tr -d ' ')"
    echo "$repo: $n commits on $ref since $SINCE (refs as of $AS_OF)"
done
```

Confirm the withheld repos are a short, explained list before reporting coverage — a sweep that silently measured 2 of 14 reads exactly like one that measured 14.

**Corpus lint** — both linters clean; report the layer-rule warning count as a trend (untagged skills stay warn-level until tagged).

```bash
./dotfiles/.config/agents/skills/lint-skill-refs.sh
./dotfiles/.config/agents/skills/lint-skill-suite.sh   # count warn lines for the layer trend
```

Report raw numbers, the bar, and the delta vs the previous audit in the scorecard.

### 6. Output

Return:

```markdown
# Skill System Audit

## Scope
- Window:
- Sources:
- Workflows audited:

## Scorecard
| Dimension | Rating | Evidence | Recommended fix |
|-----------|--------|----------|-----------------|

## D-006 Scoreboard
| Metric | Value | Bar | Delta vs last audit |
|--------|-------|-----|---------------------|
| Golden-eval pass rate | | >= 95% | |
| Gate coverage | | 100% (exempt-adjusted) | |
| Override rate | | ~0-2/month, real reasons | |
| Corpus lint | | failures=0; warn-count trend | |

## Findings
### RED
- Finding, evidence, why it matters, proposed fix

### YELLOW
- Finding, evidence, proposed fix

### GREEN
- What is working as intended

## Repeated Corrections
- User correction pattern -> workflow/skill to update

## Autonomous Backlog Gate Matrix
| PR/Issue | Module PRD provenance | Confidence | Module grill | Rollback | Human review | AFK queue approval | Risk policy result | Draft PR state | Worktree gate | Review gate | Finalize gate | Result |
|----------|-----------------------|------------|--------------|----------|--------------|--------------------|--------------------|----------------|---------------|-------------|---------------|--------|

## Follow-up Work
- Skill edits recommended
- Issues to create
- CORA/sync checks to run
```

## Rules

- Findings require evidence. Cite transcript IDs, PR numbers, issue numbers, or artifact paths.
- Do not cite subagent transcript IDs to the user; cite the parent transcript ID.
- Do not create issues or edit skills unless the user asks for fixes or approves the proposed change list.
- Prefer changing the narrowest skill that owns the failure. Example: unresolved PR comments belong in `receive-review`, `workflow-finalize`, `watch-ci`, and `reconcile-issues`, not in every workflow.
- Treat green CI as insufficient evidence for reviewer-comment resolution.
