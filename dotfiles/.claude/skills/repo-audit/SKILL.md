---
name: repo-audit
model: opus
reasoning: high
description: Map-reduce, evidence-based state-of-the-repo investigation. Use to get an honest picture of where a repo (or monorepo subtree) actually is — feeds workflow-roadmap, to-prd, to-issues, triage, or refactor-scale design-plan. Triggers on "audit the repo", "/repo-audit", "what's the real state of this codebase".
---

# /repo-audit — Map-Reduce State-of-the-Repo Investigation

## Model selection

Dispatch the discovery (Explore) agents on **Sonnet** (`model: sonnet`) — fact-gathering is parallel and cheap. Dispatch the single synthesizer on **Opus** (`model: opus`) — judgment and FIND-NN assignment benefit from the strongest model.

Give an evidence-based picture of where a repo actually is — not what its docs claim. Structured as map-reduce: parallel discovery agents each write an auditable fact-pack, then one synthesizer validates the evidence and produces findings with stable `FIND-NN` IDs. The audit is an *input* to the current workflow, not a standalone delivery loop.

## Contract

Consumes: codebase (or scoped subtree), README, CLAUDE.md, spec docs. Produces: audit report with stable FIND-NN IDs at `docs/audits/<date>-repo-audit.md`. Requires: git. Side effects: writes the audit + intermediate fact-packs (fact-packs deleted by default). Feeds: workflow-roadmap, to-prd, to-issues, triage, design-plan.

## Step 0 — Preflight

Confirm a git repo (else abort). Compute `<date>`. Resolve `<path>`; if `!= "."`, verify it exists (abort with valid siblings if not) and compute `<path-slug>` (`/`→`-`). `mkdir -p docs/audits/.fact-packs-<date>[-<path-slug>]`. Read root `README.md`, `CLAUDE.md`, any `*_SPEC.md`/`PLAN.md` for shared context; if `context` is empty, infer purpose in one sentence as `<context>`. If `focus != "all"`, keep only applicable discovery questions. If `audit_depth != deep`, merge related questions into the standard lane set (product+architecture, surface+UX, tests+CI, security+deps, integrations+ops, docs+handoff, data/storage/state).

## Step 1 — Map (fan out)

Send **one message with concurrent Agent (Explore) calls** — standard merged lanes by default, all thirteen lanes when `audit_depth=deep`, fewer if `focus` is set. Each agent is scoped to one lane + path, thoroughness `very thorough`, and writes to `docs/audits/.fact-packs-<date>[-<path-slug>]/<NN>-<slug>.md`. Assemble each prompt from `references/audit-lanes/index.md`: load `shared-preamble.md` for every agent plus the matching `<NN>-<slug>.md`.

**Research guardrail (every discovery agent):** document what IS, not what SHOULD BE — current state and measurements, not judgments or gaps. Recommendations come only in synthesis. This keeps the map accurate and defers solutioning.

## Step 2 — Wait

Wait for every fact-pack to be written; verify each expected file exists. If one is missing, retry just that agent — don't rerun the whole map phase.

## Step 3 — Reduce (synthesize)

Spawn a single general-purpose Agent using the synthesizer prompt in `references/synthesizer-prompt.md`. It re-verifies 5–10 load-bearing citations against the repo, assigns stable `FIND-NN` IDs ordered by severity, and writes `docs/audits/<date>[-<path-slug>]-repo-audit.md` with the structure that reference defines (Overall state, Findings, Top three, Detailed findings, Gaps/risks, Implementation patterns, Module candidates, Recommended next steps).
