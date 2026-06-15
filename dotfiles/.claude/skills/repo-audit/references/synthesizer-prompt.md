# repo-audit — synthesizer prompt & report structure

Spawn one general-purpose Agent with the prompt below. Load this file only at Step 3.

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
> ## Module candidates
> <Evidence-backed candidates for new or extracted modules. For each:
>   - Candidate ID: MOD-NN
>   - Classification: discard | needs-human | research-spike | module-prd-ready
>   - Current pain and evidence
>   - Affected areas
>   - Proposed ownership boundary
>   - Public interface shape
>   - Testability opportunity
>   - Migration, rollout risk, and rollback expectation
>   - Confidence: high | medium | low
>   - Provenance evidence: fact-pack filenames plus concrete file/line or command evidence
>   - Why it is or is not ready for `workflow-autonomous-backlog`.
> Do not invent candidates without fact-pack evidence.>
>
> ## Recommended next steps
> <Priority-ordered list. Each item: what to do, which FIND-NN it
> addresses, rough effort, vertical slice path, and recommended next
> workflow. Prefer `workflow-roadmap`, `grill-with-docs`, `to-prd`,
> `to-issues`, or `triage`. Recommend `design-plan` only for repo-wide
> refactors, migrations, or multi-phase remediation that cannot yet be
> expressed as independently verifiable vertical issue slices. No more
> than 8 items — action list, not wishlist.>
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
carry stable `FIND-NN` IDs that downstream skills reference in roadmaps,
PRDs, issues, triage notes, design plans, and retros.

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
| Parallel dispatch is rate-limited | Fall back to serial batches sized to the active lane count. Note the downgrade in the report. |

## Example Invocation

```
User: /repo-audit
Claude: [preflight] [creates .fact-packs-2026-04-20/]
        [dispatches standard merged Explore lanes in one message, parallel]
        [~3 minutes pass; fact-packs written]
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

## Output format

The primary artifact is always the markdown report at `docs/audits/`. When running in Cursor IDE, also produce a **canvas** (`.canvas.tsx`) for the audit summary — the findings table, severity breakdown, and risk heatmap render significantly better as an interactive artifact than as a markdown table in chat. Use the Cursor `canvas` skill pattern: create a `canvases/<date>-repo-audit.canvas.tsx` file with the structured findings data.

Skip the canvas when running headless (Codex AFK, CI, non-IDE context).

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
- Pair this skill with the current workflow:
  - Product/feature gaps: `workflow-roadmap` → `grill-with-docs` →
    `decision-log` → `to-prd` → `to-issues` → `triage`.
  - Clear implementation slices: `to-issues` or `triage` directly.
  - Refactor-scale or migration work that needs phases: `design-plan`
    → `execute-phase` → `workflow-review` → `post-mortem` →
    `workflow-finalize`.
  `/repo-audit` supplies evidence and `FIND-NN` IDs. It does not choose
  the old phase-execution lane by default.
