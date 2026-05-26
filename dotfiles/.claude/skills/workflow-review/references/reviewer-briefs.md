# Workflow Review Reviewer Brief Index

Use this index to load only the prompt templates for active reviewer lanes. Do not read every reviewer brief unless every lane is active.

## Shared Placeholders

- `<diff_summary>`: concise summary of changed files and intent
- `<diff>`: full or scoped diff
- `<changed_files>`: file list
- `<context>`: relevant `CONTEXT.md`, ADRs, conventions, or local notes
- `<acceptance_criteria>`: issue/PRD acceptance criteria, if any
- `<verification>`: commands already run and results

## Shared Output Contract

Every reviewer brief returns:

```markdown
## <Lane Name> Review

### Findings
| Severity | Confidence | File/Area | Finding | Evidence | Recommendation |
|----------|------------|-----------|---------|----------|----------------|

### Clean Checks
- [What was inspected and found clean]

### Skipped Checks
- [Check skipped + reason]

### Verdict
APPROVE | REQUEST CHANGES | NEEDS HUMAN
```

Report only issues the author should fix. Do not list generic best practices, style preferences, or speculative concerns below 70% confidence.

## Template Map

| Reviewer lane | Template |
|---------------|----------|
| Security Auditor | `references/reviewer-briefs/security-auditor.md` |
| Logic & Edge-Case Reviewer | `references/reviewer-briefs/logic-edge-case-reviewer.md` |
| TDD/Test Coverage Agent | `references/reviewer-briefs/tdd-test-coverage-agent.md` |
| Syntax/Style Guide Expert | `references/reviewer-briefs/syntax-style-guide-expert.md` |
| Performance Specialist | `references/reviewer-briefs/performance-specialist.md` |
| Documentation Reviewer | `references/reviewer-briefs/documentation-reviewer.md` |
| Architecture Reviewer | `references/reviewer-briefs/architecture-reviewer.md` |
| Backward Compatibility Reviewer | `references/reviewer-briefs/backward-compatibility-reviewer.md` |
| Concurrency & State Reviewer | `references/reviewer-briefs/concurrency-state-reviewer.md` |
| Observability Reviewer | `references/reviewer-briefs/observability-reviewer.md` |
| Release/Rollback Reviewer | `references/reviewer-briefs/release-rollback-reviewer.md` |
| Dependency/Supply-Chain Reviewer | `references/reviewer-briefs/dependency-supply-chain-reviewer.md` |
| Product/Acceptance Reviewer | `references/reviewer-briefs/product-acceptance-reviewer.md` |
| Frontend/UX/A11y Reviewer | `references/reviewer-briefs/frontend-ux-a11y-reviewer.md` |

## Loading Rule

1. Determine active reviewer lanes from `workflow-review/SKILL.md`.
2. Read this index.
3. Read only the template files for active lanes.
4. Instantiate placeholders and append the shared output contract if the lane file does not repeat it.
5. If an active lane's template file is missing, halt with `NEEDS HUMAN`.
