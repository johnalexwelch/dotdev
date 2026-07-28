# Scan lenses, C3 ranking, false-positive guard

Four read-only lenses. Each returns findings as `file:line` + verbatim snippet + a one-line signal — never a prose conclusion (subagent summarization is a hallucination surface). Dispatch on Sonnet, parallel.

## deepen — add depth (delegates to improve-codebase-architecture)

Run the `improve-codebase-architecture` exploration (its Step 1). Looking for:

- shallow modules (interface nearly as complex as implementation)
- pure functions extracted for testability while the real bugs hide in how they're called (no locality)
- tightly-coupled modules leaking across seams
- interfaces you can't test through

Apply the **deletion test**: would deleting the module concentrate complexity (earning its keep) or just move it (pass-through)? "Concentrates" is the signal. Never collapse a **trust seam** (validation/authz/sanitization/rate-limit) — it looks like a pass-through but is load-bearing.

## cut — remove bloat (delegates to ponytail audit + debt)

Run the `ponytail` audit prompt over the whole tree (not a diff), one line per finding ranked biggest cut first, tags:

- `delete` — dead code / speculative feature
- `stdlib` — reinvented standard library
- `native` — dependency doing what the platform does
- `yagni` — abstraction with one implementation
- `shrink` — same logic, fewer lines

Also harvest `ponytail:` markers (the `ponytail-debt` prompt): each names a ceiling + upgrade trigger; markers with **no trigger** rot silently — flag them.

## debt — tooling + AI-slop hunt

**Do not rebuild lint/typecheck.** Run the repo's existing gates via `pi-lens`:

```
lens_diagnostics mode=full refreshRunners=all
```

This folds in knip (unused exports/deps), jscpd (copy-paste), madge (circular deps), dead-code, gitleaks (secrets), govulncheck/trivy (CVEs). Take those as given evidence.

Then spend judgment on the **AI-slop failure modes** generic linters miss (GitClear / USENIX '25 evidence):

- **duplication** — grew 8× 2021→2024; jscpd flags text, you flag duplicated *knowledge*.
- **oversized functions** — AI commits pushed mean function size 142→267 lines, complexity 4.2→8.1. Flag > ~50 lines or complexity spikes on high-churn files.
- **catch-all handlers** that swallow errors (broad `except`/`catch` with no re-raise/log).
- **fake-success returns** — hardcoded/fixture values returned to make a test pass. Highest-severity: silent correctness debt.

Every debt finding carries **severity + effort estimate** (from `tech-debt-skill`), not just a location.

## perf — profiler-driven only

The weak link (PERFOPT-Bench, Optimas: LLMs without profiling context produce wrong "optimizations"). Rules:

- **Evidence required, captured up front.** No perf finding without a profiler trace or benchmark showing the cost. **Go get the baseline during this scan, before ranking — never surface an unmeasured perf item as a recommendation.** A perf candidate is one of three things, never a vague "blocked, needs baseline":
  1. **Measured now** → it carries real before-numbers and can be ranked as an actionable finding.
  2. **Baseline capturable but not yet run** → run it in this step; don't defer it into the recommendation.
  3. **Baseline genuinely not capturable here** (no harness, can't reproduce the hot path, needs prod data) → park it `needs_human` whose `unblock:` is the **exact command/steps to capture the baseline**, plus the pros/cons of doing the measurement. It is a request-for-measurement, not a recommendation.
- Auto-detect the harness (pytest-benchmark, criterion-rs, JMH, benchmarkjs, `go test -bench`, catch2 — see github-action-benchmark for the cross-language set). Capture a **baseline** and track it in the ledger over time.
- **Don't hard-fail on one noisy run** (shared-runner variance; Otava caveat). Compare against tracked history; a change must beat noise, not a single sample.
- A finding where a **known-good state exists** (a regression) is not this skill's job — route it to `diagnose` (regression mode: git bisect the delta).
- Never regress a hot path for the sake of a refactor: capture before/after, the after must stay within the before budget.

## C3 ranking

For each finding, gather the leverage signal:

```bash
# Churn: high-churn shallow/debt-laden files are the highest-leverage targets
git log --format= --name-only --since="6 months ago" | sort | uniq -c | sort -rn | head
```

- **Churn** = commits touching the file (above).
- **Complexity** = cyclomatic complexity / size on that file (from the debt lens tooling).
- **Coverage** = test coverage on that file (from the repo's coverage report; treat missing as 0 → boosts the score, untested churn is the scariest).

Score = **(churn × complexity ÷ (coverage + 1)) × benefit ÷ effort**, where benefit/effort are the `improve-codebase-architecture` estimates (S/M/L effort, concrete payoff for benefit). Rank descending. This is the same C3 idea as PrioSpot / repo-drift / Hotspots — churn + complexity + coverage — you can shell out to `repo-drift` (zero-config local) instead of hand-rolling if it's installed.

## "Looks bad but is actually fine" (false-positive guard)

Borrowed from `tech-debt-skill`. Before ranking, drop findings that only *look* like debt: intentional duplication for decoupling, a "shallow" wrapper that's actually a trust seam, a long function that's a flat data table, a slow path that's cold. Record each rejection **with its reason in the ledger** so tomorrow's run doesn't re-raise it. A candidate with no measurable signal is `rejected`, never `deferred`.
