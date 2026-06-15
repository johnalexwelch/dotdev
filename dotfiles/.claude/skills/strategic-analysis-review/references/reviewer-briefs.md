# Strategic Analysis Reviewer Brief Index

Load this index before dispatching reviewers. Then load only the templates for active lanes.

## Shared Inputs

Each reviewer receives:

- `<draft>`: the analysis, memo, excerpt, or proposed narrative
- `<audience>`: intended reader, inferred if missing
- `<decision_or_goal>`: decision, alignment, action, or belief the draft should drive
- `<source_context>`: evidence, notes, tables, links, caveats, or "not provided"
- `<constraints>`: length, tone, sensitivity, format, or "none stated"

## Shared Output Contract

Each reviewer returns:

```markdown
## <Lane Name>

### Strengths
- <What works and should be preserved>

### Weaknesses
- <Argument, evidence, structure, or wording problems>

### Enhancements
- <What to add, reframe, caveat, or clarify>

### Cut Or Compress
- <What to remove, demote, or shorten>

### Rewording
- Before: <original phrase/sentence>
- After: <executive-ready alternative>
- Why: <strategic effect>
```

## Template Map

| Lane | Template |
|------|----------|
| Argument Strategist | `references/reviewer-briefs/argument-strategist.md` |
| Pyramid/SCQA Architect | `references/reviewer-briefs/pyramid-scqa-architect.md` |
| Evidence & Precision Auditor | `references/reviewer-briefs/evidence-precision-auditor.md` |
| Executive Language Editor | `references/reviewer-briefs/executive-language-editor.md` |
| Insight / So-What Reviewer | `references/reviewer-briefs/insight-so-what-reviewer.md` |
| Counterargument / Red-Team Reviewer | `references/reviewer-briefs/counterargument-red-team-reviewer.md` |
| MECE / Grouping Reviewer | `references/reviewer-briefs/mece-grouping-reviewer.md` |
| Quant / Scenario Reasoning Reviewer | `references/reviewer-briefs/quant-scenario-reasoning-reviewer.md` |
| Source-to-Claim Traceability Reviewer | `references/reviewer-briefs/source-to-claim-traceability-reviewer.md` |
| Stakeholder/Risk Reviewer | `references/reviewer-briefs/stakeholder-risk-reviewer.md` |
| Decision/Actionability Reviewer | `references/reviewer-briefs/decision-actionability-reviewer.md` |
| Removal Pass | `references/reviewer-briefs/removal-pass.md` |

## Synthesis Rule

After all active lanes return, synthesize the findings into a single ranked review. Do not paste every lane output verbatim unless the user asks. Lead with the highest-leverage changes.
