---
name: deep-research
model: sonnet
reasoning: medium
description: "AFK background research against external sources (web, official docs, API references, GitHub repos). Produces a cited markdown summary as a linked asset. Complements repo-audit (internal) — deep-research handles everything outside the working directory. Triggers: \"research this\", \"investigate\", \"what does the ecosystem say about\", \"find out how X works\". Distinct from meta-skills:deep-research by engine: this one is Claude-native AFK web research with a cited markdown asset; the meta-skills twin drives the OpenAI Deep Research API — choose by engine."
codex-compatible: true
---

# /deep-research — External Source Investigation

## Purpose

Answer questions that require sources **outside the current repository**: official documentation, web search, API references, GitHub repos, knowledge bases. Produces a cited markdown file that can be linked from wayfinder tickets, grill sessions, or design docs.

**Hard boundary:** Do not research internal codebase state — that's `/repo-audit`. Deep-research is for external knowledge only.

## Contract

Consumes: research question or topic; optional scope constraints (e.g., "only official docs", "compare top 3 options")
Produces: cited research summary at `docs/research/<date>-<slug>.md`
Requires: web_search tool available
Side effects: writes the research summary; may create `docs/research/` directory
Human gates: none (AFK by default); escalate only if sources are paywalled, unavailable, or contradictory beyond resolution

Feeds: wayfinder (Research tickets), grill-with-docs (fact-gathering), design-plan, to-prd, workflow-roadmap.

## Source Priority

Query sources in this order; stop when the question is answered with sufficient confidence:

| Priority | Source | Use for | Trust level |
|----------|--------|---------|-------------|
| 1 | **Official documentation** | Canonical behavior, API contracts, configuration | High |
| 2 | **GitHub repos/READMEs** | Implementation patterns, version-specific behavior | High |
| 3 | **Web search (curated)** | Ecosystem patterns, comparisons, version differences | Medium |
| 4 | **Stack Overflow / Discussions** | Edge cases, workarounds, community consensus | Low (verify) |
| 5 | **Blog posts / tutorials** | Context, alternatives, opinions | Low (cite as opinion) |

**Trust calibration:** Higher-priority sources override lower ones. When sources conflict, note the conflict and prefer official docs unless evidence suggests docs are outdated.

## Output Format

```markdown
# Research: <Topic>

**Question:** <The research question being answered>
**Date:** <YYYY-MM-DD>
**Confidence:** High | Medium | Low
**Sources consulted:** <count>

## Summary

<2-3 paragraph answer to the research question>

## Key Findings

### Finding 1: <title>
<Detail with inline citations [1]>

### Finding 2: <title>
<Detail with inline citations [2]>

...

## Recommendations

<If the research supports a recommendation, state it. Otherwise: "No recommendation — this is informational research.">

## Open Questions

<Questions that emerged but couldn't be answered, or require internal codebase knowledge (→ repo-audit)>

## Sources

[1] <URL> — <title>, <date if known>, <trust level>
[2] <URL> — <title>, <date if known>, <trust level>
...

## Research Log

<Brief log of what was searched, what was found, what was discarded and why>
```

## Process

### Step 1 — Clarify scope

Parse the research question. Identify:

- **Core question**: What exactly needs to be answered?
- **Scope constraints**: Official docs only? Compare N options? Specific version?
- **Success criteria**: What would a complete answer look like?

If the question is ambiguous, ask one clarifying question before proceeding. In AFK mode (wayfinder dispatch), make a reasonable interpretation and note assumptions.

### Step 2 — Query sources

1. **Official docs first**: Search for official documentation. Use `fetch_content` to read relevant pages.
2. **GitHub repos**: If the topic involves a library/tool, check its README and relevant source files.
3. **Web search**: Use `web_search` with varied query angles (see below).
4. **Verify claims**: Cross-reference claims across sources. Note conflicts.

**Web search strategy:**

- Use 2-4 varied queries, not one broad query
- Example for "how does NextAuth handle session refresh":
  - `"NextAuth session refresh strategy official docs"`
  - `"NextAuth JWT vs database session comparison"`
  - `"NextAuth session maxAge behavior"`

### Step 3 — Synthesize

Write the research summary following the output format. Ensure:

- Every factual claim has a citation
- Conflicts between sources are noted
- Confidence level reflects source quality and agreement
- Open questions are captured for follow-up

### Step 4 — Save and link

1. Create directory if needed: `mkdir -p docs/research`
2. Write file: `docs/research/<date>-<slug>.md`
3. If called from a wayfinder ticket, comment on the ticket with the file path
4. Return the file path for linking

## Confidence Calibration

| Confidence | Criteria |
|------------|----------|
| **High** | Official docs + GitHub source confirm; no conflicting sources |
| **Medium** | Official docs confirm but edge cases unclear; or multiple credible sources agree |
| **Low** | No official docs; relying on community sources; or sources conflict |

## Escalation

Escalate to human (break AFK) only when:

- Primary sources are paywalled or require authentication
- Sources fundamentally contradict with no clear resolution
- The question requires internal knowledge (redirect to repo-audit)
- Search tools are unavailable or rate-limited

## Anti-patterns

- ❌ Researching internal codebase state (use repo-audit)
- ❌ Accepting blog posts over official docs
- ❌ Single-source answers without verification
- ❌ Uncited claims in the summary
- ❌ Mixing research with implementation (research informs; it doesn't build)

## Example Invocations

```
/deep-research "How does Stripe handle idempotency keys for payment intents?"

/deep-research "Compare top 3 React state management libraries for large apps" --scope="official docs + GitHub stars + bundle size"

/deep-research "What's the recommended way to handle refresh tokens in NextAuth v5?"
```

## Integration with Wayfinder

When wayfinder creates a Research ticket:

1. Ticket body contains the research question
2. Agent claims the ticket and invokes `/deep-research`
3. Research summary is written to `docs/research/`
4. Agent comments on ticket with file path and key findings
5. Ticket is closed with resolution summary

The research file becomes a **linked asset** — referenced from the ticket, not pasted into it.
