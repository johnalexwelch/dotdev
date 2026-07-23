# Session Reflection: Rename `workflow-effectiveness-audit`
**Date**: 2026-07-17
**Goal**: stop using the `workflow-` prefix for skills that do not orchestrate a multi-skill sequence.

## What Went Well
- Building the skill sequence DAG made the naming contract visible: `workflow-*` reads as "triggers/chains multiple skills."
- `workflow-effectiveness-audit` correctly appeared as a leaf (router dispatch in, no sequenced downstream skills), which exposed the misnomer.

## What Went Wrong / Friction
- The name implies an orchestrator (`workflow-feature`, `workflow-build-one`, `workflow-finalize`), but the skill is a **terminal governance audit**: scorecard + findings, no `## Flow` that invokes other skills.
- Soft "Pairs well with" / follow-up mentions (`skill-maintenance`, `reconcile-issues`, `receive-review`, `workflow-router`) are adjacency, not a pipeline — yet the prefix still trains agents/humans to expect a chain.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | `workflow-effectiveness-audit` has no downstream skills; rename so `workflow-` means multi-skill orchestration | Naming used `workflow-` as topical ("about workflows") instead of structural ("orchestrates a workflow") | `workflow-effectiveness-audit/SKILL.md` + `workflow-router` classification table |

## Lessons
1. **`workflow-` is a structural prefix, not a topic tag.** Reserve it for skills whose primary job is to sequence other skills (entry → steps → gates → exit).
2. **Terminal audits/governance skills should use `*-audit`, `*-insight`, or `skill-*` family names**, matching `repo-audit`, `docs-audit`, `session-insight`, `skill-evaluator`.
3. **DAG leaves that are only router targets should not look like pipeline siblings** — naming is part of the routing mental model.

## Proposed Rename

### Recommended
| From | To | Why |
|------|----|-----|
| `workflow-effectiveness-audit` | **`skill-system-audit`** | Matches what it does (audit the skill/workflow *system* for compliance). Sits with `skill-backlog` / `skill-evaluator` / `session-insight` as governance, not orchestration. Avoids implying a multi-skill run. |

### Alternates (if preferred)
| Candidate | Tradeoff |
|-----------|----------|
| `process-effectiveness-audit` | Clear "governance" signal; slightly vaguer about skill ownership |
| `agent-effectiveness-audit` | Emphasizes transcript/behavior audit; less clear it covers skill definitions + sync |
| `effectiveness-audit` | Shortest; too generic next to data/docs audits |
| `governance-audit` | Accurate role; less discoverable for "are the skills working?" triggers |

### Non-goals
- Do **not** invent fake downstream edges just to justify keeping `workflow-`.
- Do **not** rename true orchestrators (`workflow-review`, `workflow-finalize`, etc.) — those correctly own multi-skill sequences.

## Naming Contract (proposed durable rule)
Add to skill authoring / router docs:

> Use the `workflow-` prefix only when the skill's primary job is to orchestrate a sequenced multi-skill pipeline (has an ordered `## Flow` that loads/runs other skills). Single-skill audits, reviews, and governance tools use domain prefixes (`*-audit`, `skill-*`, `session-*`) instead.

## Blast Radius (known references to update)
If the rename is approved, update in one pass:

- Directory + frontmatter: `skills/workflow-effectiveness-audit/` → `skills/skill-system-audit/` (`name:` field)
- Router: `workflow-router/SKILL.md` (classification table, Follow-up audit, Learning Loop, Worktree Baseline note)
- Complements: `session-insight/SKILL.md` (purpose + pairs-well)
- Pairs-well: `run-backlog/SKILL.md`, `workflow-autonomous-backlog/SKILL.md`
- Indexes: `skills/_docs/skills-index.md`, `skills/_docs/SKILL-MANIFEST.md`, `skills/_docs/AUDIT_REPORT.md`
- Any Stow/runtime copies under `~/.claude/skills` / `~/.codex/skills` after Stow sync
- Optional: tldraw skill DAG node id/label

## Proposed Improvements
- [ ] Rename `workflow-effectiveness-audit` → `skill-system-audit` (directory, `name:`, description) — **priority: high**
- [ ] Update all in-repo references listed in Blast Radius — **priority: high**
- [ ] Add the Naming Contract bullet to `write-a-skill` / `workflow-skill` (or `_docs`) so new skills don't reuse `workflow-` as a topic tag — **priority: medium**
- [ ] Refresh router classification trigger wording: keep user phrases ("evaluate workflow effectiveness") but route to `skill-system-audit` — **priority: medium**
- [ ] After rename, treat optional follow-ups as soft edges only if desired: findings → `session-insight` / `skill-backlog` (do not invent a fake orchestrator flow) — **priority: low**

## Decision Needed
Approve **`skill-system-audit`** (recommended), or pick an alternate from the table above, before any file moves.
