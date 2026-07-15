# Repo Audit Lanes

Load this index during `/repo-audit` Step 1 before dispatching discovery agents.

Use `shared-preamble.md` for every lane, then append the relevant lane file below. Each dispatched Explore agent must use thoroughness `very thorough`, stay inside `<path>`, and write to:

`docs/audits/.fact-packs-<date>[-<path-slug>]/<NN>-<slug>.md`

## Lanes

| N | Slug | Reference |
|---|------|-----------|
| 01 | built-vs-planned | `01-built-vs-planned.md` |
| 02 | module-inventory | `02-module-inventory.md` |
| 03 | entry-points | `03-entry-points.md` |
| 04 | legacy-vs-new | `04-legacy-vs-new.md` |
| 05 | tests | `05-tests.md` |
| 06 | config-secrets | `06-config-secrets.md` |
| 07 | integrations | `07-integrations.md` |
| 08 | doc-drift | `08-doc-drift.md` |
| 09 | operability | `09-operability.md` |
| 10 | security-depth | `10-security-depth.md` |
| 11 | user-surface | `11-user-surface.md` |
| 12 | onboarding | `12-onboarding.md` |
| 13 | ci-workflows | `13-ci-workflows.md` |

## Prompt Assembly

For each lane, assemble:

```markdown
<shared preamble from shared-preamble.md>

Your question: **<lane question from the lane file>**

Output file: `docs/audits/.fact-packs-<date>[-<path-slug>]/<NN>-<slug>.md`

Structure your fact-pack as:

- `## Summary` (1 paragraph)
- `## Findings` (headed sub-sections with evidence)
- `## Evidence` (file paths, line counts, command outputs cited in findings)
- `## Open questions` (things you couldn't determine)

Do not editorialize about overall repo quality — that's the synthesizer's job. Report only what falls inside your question's scope and within `<path>`.
```

If `focus` is set, dispatch only the lane files whose questions apply.
