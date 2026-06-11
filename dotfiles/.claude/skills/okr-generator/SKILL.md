---
name: okr-generator
model: sonnet
description: >-
  Draft OKRs that are decisions, not wish-lists — objectives that name the bet, and 3-5 key
  results that are real metrics with a baseline and a target. Forces each KR through a
  Goodhart / gameability check so the set can't be hit while the goal is missed. Use when
  someone says "write OKRs", "draft our objectives and key results", "set quarterly goals",
  "turn this strategy into OKRs", or "are these OKRs any good?" (review mode).
---

# OKR Generator

An OKR is a commitment, so the failure mode isn't "badly worded" — it's "fully achievable while the thing we actually wanted doesn't happen." This skill exists to prevent that. Objectives state the bet; key results are the metrics that prove it; and every KR is pressure-tested for how it could be gamed.

## Start from the bet, not the template

Before drafting, get (or infer and confirm) three things: **the bet** (what change in the business are we trying to cause this period?), **the timebox**, and **the owner**. If the input is just "make OKRs for the team," ask what outcome would make the quarter a success. OKRs written from a template instead of a bet are the thing this skill is meant to avoid.

## Objectives (1-3)

- Qualitative, memorable, and **directional** — a state of the world, not a metric ("Parents rely on the weekly digest", not "Raise digest opens 20%").
- Each maps to a real bet; if you can't say what decision or strategy it serves, cut it.
- Cap at 3. More objectives = no priority.

## Key results (3-5 per objective)

Each KR is a metric with `baseline → target` and a clear measurement window. Because a KR **is** a metric, hold it to the metric bar:

> For any KR that is new, unusual, or load-bearing, **follow `metric-design`** to nail its precise definition (what counts / what's excluded), a stable denominator, the Goodhart check, and a falsifier. Don't reinvent that rigor here — delegate to it.

Then apply the OKR-specific tests:

- **Outcome, not output.** "Ship feature X" is a task, not a KR. The KR is the *effect* X is supposed to have. (Track tasks separately as initiatives.)
- **Baseline present.** A target with no baseline ("reach 40%") is unjudgeable — from what?
- **Gameability check (mandatory).** Ask: "What's the laziest way to hit this number while betraying the objective?" If an obvious one exists, add a paired counter-KR (a guardrail that must hold) or redefine. Example: "increase signups" → pair with "and 7-day activation rate does not fall."
- **Attributable & ambitious.** The team can meaningfully move it; ~70% is a strong result (sandbag check: if you're confident of 100%, it's too easy).

## Counter-KRs / guardrails

At least consider one guardrail per objective — the metric that must NOT degrade while you chase the KRs. This is the single biggest defense against Goodharted OKRs and the thing most drafts omit.

## Review mode

Given existing OKRs, run each through the tests above and return a findings list (severity-tagged) + a rewritten set. Lead with any KR that can be hit while the objective fails — that's always the top finding.

## Output

Markdown: per objective → the bet it serves (one line) → KR table (`KR · baseline → target · window · owner`) → guardrails → flagged risks. A reference rubric + worked example: `references/okr-rubric.md`.

## Contract

Consumes: a strategy/bet (or a draft OKR set to review) + timebox + owner
Produces: a structured, gameability-checked OKR set (markdown), or a review + rewrite
Requires: follows `metric-design` for KR definitions
Side effects: none
Human gates: targets/ambition level are a human call — propose, don't impose

## Context

Pairs well with: metric-design (KR definition + Goodhart), metric-council (stress-test a KR set), decision-log (record the bet), report-metrics (read out attainment)
