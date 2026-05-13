---
name: repo-audit
description: Map-reduce state-of-the-repo audit. Fans out 13 parallel Explore subagents to gather evidence across code, tests, docs, integrations, ops, CI/workflows, security, UX, and onboarding; then runs one synthesizer that validates evidence and produces stable finding IDs, risks, patterns, and next steps.
triggers:
  - "audit this repo"
  - "state of the repo"
  - "where are the gaps"
  - "what's fragile here"
  - "/repo-audit"
persona: Staff Engineer running a structured codebase audit
inputs:
  - name: context
    type: string
    default: ""
    description: One-sentence description of the project (who it's for, what it does). If empty, infer from README.
  - name: focus
    type: string
    default: "all"
    description: Optional narrower scope — e.g. "tests", "integrations", "security", "onboarding". If set, skip discovery questions not relevant.
  - name: path
    type: string
    default: "."
    description: Subtree to audit, relative to repo root. Default "." audits the whole repo. Use e.g. "apps/web" or "services/auth" for monorepos. Agents must stay inside this path.
  - name: keep_facts
    type: boolean
    default: false
    description: If true, do not delete the intermediate fact-packs after synthesis.
writes:
  - docs/audits/<date>[-<path-slug>]-repo-audit.md
  - docs/audits/.fact-packs-<date>[-<path-slug>]/*.md (intermediate, deleted unless keep_facts=true)
---

## Contract
Consumes: entire codebase (or scoped subtree via path param), README, CLAUDE.md, spec docs
Produces: audit report with stable FIND-NN IDs (docs/audits/<date>-repo-audit.md)
Requires: git
Side effects: writes audit file and intermediate fact-packs (fact-packs deleted by default)
Human gates: none

## Context
Typical workflows: audit-loop (entrypoint for refactor-scale work, before /design-plan)
Pairs well with: design-plan, post-mortem, improve-codebase-architecture

# /repo-audit — Map-Reduce State-of-the-Repo Investigation

## Purpose

Give the user an evidence-based picture of where a repo (or a subtree of a
monorepo) actually is — not what its docs claim. Built for projects in
transition (mid-refactor, inherited codebases, systems that have been
running unattended). The audit is structured as map-reduce: thirteen
parallel discovery agents each produce an auditable fact-pack, then one
synthesizer validates the evidence and produces judgment — findings with
stable IDs, risks, patterns, and recommended next steps.

## Step 0: Preflight

- Confirm you are in a git repo. If not, abort.
- Compute today's date as `<YYYY-MM-DD>`.
- Resolve `<path>`. If `path != "."`, verify the subdirectory exists;
  abort with a clear message and list of valid siblings if it doesn't.
  Compute `<path-slug>` by replacing `/` with `-` (e.g. `apps/web` →
  `apps-web`). If `path == "."`, `<path-slug>` is empty and output paths
  omit it.
- Create the scratch directory:
  `mkdir -p docs/audits/.fact-packs-<date>[-<path-slug>]`.
- Read `README.md`, `CLAUDE.md`, and any `*_SPEC.md` or `PLAN.md` at repo
  root (always root, even when scoped) to set shared context.
- If `context` is empty, infer the project's purpose from `README.md` in
  one sentence. Use that as `<context>` in all downstream prompts.
- If `focus` is not `"all"`, determine which of the thirteen discovery
  questions apply and skip the rest.

## Step 1: Map — fan out discovery agents in parallel

Send **one message with thirteen concurrent `Agent` (Explore subagent)
tool calls** (fewer if `focus` is set). Do not serialize them. Each agent
is scoped to one question and one path, and writes its findings to
`docs/audits/.fact-packs-<date>[-<path-slug>]/<NN>-<slug>.md`.

For each agent, use thoroughness `very thorough` and the prompt template
below, substituting the question-specific text.

**Shared preamble for every agent:**

> You are one of thirteen parallel investigators auditing this repo. Your
> scope is narrow — investigate ONLY the question below, and ONLY within
> the subtree `<path>`. Do not investigate files outside `<path>`. Do not
> attempt the whole audit. Be concrete — cite file paths (relative to
> repo root), line counts, and commands run. Output your findings as
> structured markdown (headers + prose, not bullet walls) to the exact
> file path given. Do not speculate beyond what you can observe. Context:
> <context>

**The thirteen discovery questions:**

| N | Slug | Scope |
|---|------|-------|
| 01 | built-vs-planned | What's built vs. what's planned. Read every planning/spec doc at root and compare to actual directory contents in `<path>`. List the delta — planned but missing, built but undocumented, phases incomplete. |
| 02 | module-inventory | Major modules/components inside `<path>`: for each, lines, maturity, quality, dependencies, whether spec matches code. |
| 03 | entry-points | What's a user actually meant to run? Which entry points work, which are stubs, which are abandoned? Include slash commands, CLIs, scripts, cron/launchd jobs. |
| 04 | legacy-vs-new | Anything in a half-refactored state? Which code is load-bearing vs. superseded-but-not-deleted? Identify the critical path for core workflows. |
| 05 | tests | Do tests actually run against current code? Run the test command and report the real count, coverage, and any claims in docs that don't match reality. |
| 06 | config-secrets | Anything committed that shouldn't be (tokens, keys, .env)? Machine-specific paths hardcoded? Secrets referenced vs. embedded? Check `.env.example` drift. |
| 07 | integrations | External services this talks to. For each: auth method, wired vs. aspirational, failure mode, rate-limit handling. |
| 08 | doc-drift | Every doc at repo root and in `docs/`. Flag contradictions, stale claims, and docs that describe a future that isn't reality. |
| 09 | operability | How do you know when this is broken? Where do errors and logs go? What happens on dependency failure — graceful degrade, silent miss, or cascade? What runs unattended, and who is notified on failure? |
| 10 | security-depth | Beyond config-secrets: PII in logs or artifacts, token scope minimization, dependency pinning and known vulns, data retention policy, permissions model. Check git history for previously-committed secrets (`git log -p -- '*.env'` and similar). |
| 11 | user-surface | Full list of user-facing commands/UIs. Do they behave consistently on errors? Is the voice/style coherent across them? What does a user see when something fails? |
| 12 | onboarding | If someone new cloned this repo tomorrow, how long until they could run the core workflow? What's undocumented but load-bearing — hardcoded paths, unwritten norms, tribal knowledge, required machine-local state? |
| 13 | ci-workflows | CI/CD pipeline, build scripts, pre-commit hooks, release process. Inspect `.github/workflows/`, `.gitlab-ci.yml`, `Makefile`, `package.json` scripts, `.pre-commit-config.yaml`, etc. Flag: required checks that don't run, secrets in CI env, stale runner images, flaky jobs, missing deploy rollback, manual release steps that should be automated. |

**Prompt template (fill in per agent):**

> <shared preamble>
>
> Your question: **<question scope text from table>**
>
> Output file: `docs/audits/.fact-packs-<date>[-<path-slug>]/<NN>-<slug>.md`
>
> Structure your fact-pack as:
> - `## Summary` (1 paragraph)
> - `## Findings` (headed sub-sections with evidence)
> - `## Evidence` (file paths, line counts, command outputs cited in findings)
> - `## Open questions` (things you couldn't determine)
>
> Do not editorialize about overall repo quality — that's the synthesizer's
> job. Report only what falls inside your question's scope and within
> `<path>`.

If `focus` was set, drop agents whose questions don't apply.

## Research Guardrail

During evidence gathering (fact-pack generation), sub-agents follow this constraint:

**Document what IS, not what SHOULD BE.**

- Describe current state, not desired state
- Report measurements, not judgments
- List what exists, not what's missing
- Findings describe reality; recommendations come only in the synthesis phase

This separation prevents premature solutioning. The research phase builds an accurate map; the synthesis phase interprets it.

## Step 2: Wait for map phase

After dispatching all agents, wait for every fact-pack to be written.
Verify each expected file exists. If any is missing, retry the single
missing agent rather than rerunning the whole map phase.

## Step 3: Reduce — spawn one synthesizer

Spawn a single `Agent` (general-purpose) subagent with this prompt:

> You are the synthesizer for a repo audit. Read every file in
> `docs/audits/.fact-packs-<date>[-<path-slug>]/`. Based ONLY on what
> those fact-packs contain, produce a consolidated audit report.
>
> Context: <context>
> Scope: <path>
>
> **Before drafting, validate evidence.** Pick 5–10 of the most
> load-bearing citations across the fact-packs (file paths, line counts,
> command outputs) and re-verify them against the actual repo using
> Read, Grep, or Bash. If any citation fails to reproduce, flag the
> finding as unverified in `## Open questions / unverified claims` and
> lower its severity by one level. Do not silently drop citations —
> surface the discrepancy.
>
> **Assign stable finding IDs.** Every distinct finding gets an ID of
> the form `FIND-NN` (zero-padded, e.g. FIND-01, FIND-02, ...), assigned
> once and used consistently throughout the report. Order IDs by
> severity, most severe first. Findings are the contract between this
> report and downstream plans/post-mortems — they must be individually
> referenceable.
>
> Save the report to
> `docs/audits/<date>[-<path-slug>]-repo-audit.md`, with this structure:
>
> ```
> # Repo Audit — <repo name>
> **Date:** <YYYY-MM-DD>
> **Context:** <context>
> **Scope:** <path>
> **Focus:** <focus>
>
> ## Overall state
> <1 paragraph. The honest summary — is this subtree healthy, fragile,
> or unclear? No hedging.>
>
> ## Findings
> <Every distinct finding as a numbered entry. For each:
>   - **FIND-NN — <short title>**
>   - Severity: critical | high | medium | low
>   - Category: one of the 13 discovery slugs
>   - Evidence: file paths + line counts + command outputs (cited from
>     fact-packs, validated by the pass above)
>   - Impact: one sentence on why it matters
> Findings must be individually actionable. Downstream plans will
> reference them by ID.>
>
> ## Top three
> <The three most critical findings by severity. Reference by ID. One
> paragraph each expanding on the finding entry.>
>
> ## Detailed findings by question
> <One subsection per fact-pack question. Summarize the fact-pack, note
> which FIND-NN IDs were extracted from it.>
>
> ## Biggest gaps and risks
> <Your independent judgment across the full set of fact-packs.
> Reference finding IDs. What's the most fragile piece? What's the
> biggest architectural concern? What would break first?>
>
> ## Implementation patterns
> <What's the best-built piece in this repo, and what pattern should
> new work follow? Cite the specific example.>
>
> ## Recommended next steps
> <Priority-ordered list. Each item: what to do, which FIND-NN it
> addresses, rough effort. No more than 8 items — action list, not
> wishlist.>
>
> ## Open questions / unverified claims
> <Anything the evidence-validation pass couldn't confirm. Also anything
> the fact-packs couldn't determine. Also citations that didn't
> reproduce.>
> ```
>
> Be concrete. Cite file paths and line counts. Do not invent findings
> not present in the fact-packs. If fact-packs contradict each other,
> surface the contradiction rather than resolving it silently.

## Step 4: Surface the top three

After the synthesizer writes the report, read it and present to the user
in chat:

- The one-paragraph `## Overall state`.
- The three findings from `## Top three`, one line each, with their IDs.
- A pointer to the saved report.

Do not repeat the full report inline — the file is the artifact.

## Step 5: Cleanup

Unless `keep_facts` is true, delete the scratch dir:
`rm -rf docs/audits/.fact-packs-<date>[-<path-slug>]/`.

If `keep_facts` is true, leave the directory and note its path in the
chat output.

## Output Format

**Final report:** standard markdown with the structure defined in Step 3,
saved to `docs/audits/<date>[-<path-slug>]-repo-audit.md`. Findings
carry stable `FIND-NN` IDs that downstream skills (`/design-plan`,
`/post-mortem`) reference.

**Intermediate fact-packs:** one markdown file per discovery question
in `docs/audits/.fact-packs-<date>[-<path-slug>]/`. Deleted by default.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort with a clear message. |
| Scoped `path` doesn't exist | Abort. List valid subdirectories of repo root. |
| No README or spec docs | Proceed; note in the report that context was inferred. |
| Test command fails | The tests fact-pack records the failure as a finding. Do not block the audit. |
| A discovery agent returns empty or malformed output | Retry that single agent once. If it fails again, write a placeholder fact-pack noting the failure and proceed to synthesis. |
| Evidence validation fails on >50% of spot checks | Pause synthesis, surface to user — fact-packs may be hallucinating. Do not ship an unvalidated report. |
| Synthesizer output is missing a required section | Rewrite that section with a focused follow-up call. |
| Parallel dispatch is rate-limited | Fall back to three serial batches (5+5+3). Note the downgrade in the report. |

## Example Invocation

```
User: /repo-audit
Claude: [preflight] [creates .fact-packs-2026-04-20/]
        [dispatches 13 Explore agents in one message, parallel]
        [~3 minutes pass; 13 fact-packs written]
        [spawns synthesizer; validates 8 cited file paths against repo;
         all reproduce; assigns FIND-01 through FIND-14 by severity]
        [writes docs/audits/2026-04-20-repo-audit.md]
        [deletes scratch dir]

        Overall state: Mid-refactor, functioning but fragile. Legacy
        scripts still load-bearing despite being marked for deletion,
        no alerting on scheduled jobs, and CI has a required check
        that hasn't run in 60 days.

        Top three:
        - FIND-01 (critical): 3,946 lines of "replaced" legacy code
          still run production (scripts/daily-briefing.js,
          scripts/meeting-prep.js).
        - FIND-02 (critical): No observability on scheduled jobs —
          launchd failure is silent.
        - FIND-03 (high): Required CI check `integration-tests` has
          not run successfully in 60 days; auto-merge is disabled.

        Full report: docs/audits/2026-04-20-repo-audit.md
```

Scoped example:

```
User: /repo-audit path=apps/web
Claude: [writes docs/audits/2026-04-20-apps-web-repo-audit.md]
```

## Tuning notes

- For repos under ~20K lines, consider dropping parallel agents by
  merging related questions — e.g. 01+04 (legacy-vs-planned), 06+10
  (security), 03+11 (user-surface) — down to about seven parallel
  agents. Keep 13 (ci-workflows) as its own agent; CI config is
  usually independent of product code.
- For monorepos, always run scoped. Auditing the whole tree at once
  produces a report too coarse to act on.
- For greenfield/small repos, set `focus` to skip questions 01
  (built vs. planned), 04 (legacy vs. new), and 08 (doc drift) —
  they'll be no-ops.
- For mature production codebases, consider an additional `ops-load`
  focus that adds performance and cost questions.
- For libraries and SDKs, add a question about top API rough edges a
  new consumer would hit.
- Pair this skill with the rest of the core loop:
  `/design-plan` (turns findings into a phased plan; also accepts
  a `brief` for bug/feature-scale work without an audit),
  `/execute-phase` (runs each phase with scoped subagents, commits
  with ID citations from any scheme — `FIND-NN`, `REQ-NN`, ticket
  slugs), `/review` (workspace reviewer subagent, in-loop fresh
  context), `/post-mortem` (closes the loop with a retro citing
  `NEW-NN` discoveries — runs before `/describe-pr` so the PR body
  can cite the retro), `/describe-pr` (produces deviation-aware PR
  bodies), and `/watch-ci` (post-PR-open: polls CI, applies bounded
  auto-fixes, runs `/security-review`, submits Approve when clean).
  Plus `/setup-worktree` as an on-demand side-car for resolving
  `[human]` gates in isolated checkouts. `/repo-audit` is the
  refactor-scale entrypoint; brief-mode `/design-plan` is the
  bug/feature entrypoint and skips this skill. All seven share ID
  vocabulary (`FIND-NN`, `REQ-NN`, `NEW-NN`, ticket slugs, phase
  numbers) and artifact conventions under `docs/audits/`,
  `docs/plans/`, and `docs/executions/` (including the hidden
  `.phase-runs/` subdir written by `/execute-phase` and `.ci-runs/`
  written by `/watch-ci`).