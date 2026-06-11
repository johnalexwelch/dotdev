---
name: product-launch-checklist
model: sonnet
description: >-
  Turn a feature or product that's about to ship into a phase-gated launch plan — sized to
  the launch's blast radius, not a frozen 200-item list. Produces the gates, owners, comms,
  guardrail metrics, and rollback that have to be true before, during, and after go-live, plus
  a retro hook. Use when someone says "we're launching X", "build a launch plan / checklist",
  "are we ready to ship", "go-to-market checklist", or "what do we need before go-live".
---

# Product Launch Checklist

`workflow-roadmap` decides *what* to build; this decides *how it goes live without breaking*. The job is not to emit a generic checklist — it's to produce the *smallest* set of gates this specific launch needs, each with an owner and a pass condition, so "are we ready?" has a real answer.

## Step 0 — size the launch (do this first)

Pick the tier; it sets how heavy everything below is. When unsure, size up.

| Tier | Looks like | Rigor |
|------|-----------|-------|
| **T1 micro** | copy/UI tweak, internal tool, flagged to a small %, fully reversible | gates as a short list; skip formal phases |
| **T2 standard** | a real feature to existing users, reversible with effort | all four phases, light |
| **T3 major** | new product/surface, pricing, data model, anything touching child data, or a one-way door | all phases + explicit rollback + named launch owner + go/no-go meeting |

State the tier and *why* in one line. For ClassDojo, treat anything touching **under-13 data, parent consent, or school-district contracts** as T3 regardless of size.

## The four phases (gates, not tasks)

Each gate is `owner · pass condition`. Drop gates that don't apply; never pad. Detail and a worked example: `references/launch-phases.md`.

1. **Plan / readiness** — success metric + guardrail metrics defined (decide these with `metric-design`; if it's a goal, it has a target); audience & rollout mechanism (flag %, cohort, geo) chosen; risks registered with mitigations; legal/privacy review done if T3; rollback path written *before* launch.
2. **Pre-launch (go/no-go)** — instrumentation verified emitting; guardrail dashboards live; support/CS briefed with FAQ; comms drafted (lean on `dojo-copywriting` for user-facing copy); on-call/owner named for the launch window; explicit go/no-go decision recorded (`decision-log`).
3. **Launch** — staged ramp with a hold-and-watch step between stages, not all-at-once; guardrails watched against thresholds set in phase 1; one named person owns the abort call; rollback rehearsed-or-trusted.
4. **Post-launch / close** — did the success metric move (report it the `report-metrics` way: absolute + vs-goal); guardrails clean; flag fully rolled out or rolled back and *why*; retro scheduled. Hand the retro to `post-mortem` if anything went wrong, and the results readout to `report-metrics`.

## Guardrails (the part teams skip)

Every launch declares **counter-metrics** with thresholds *before* go-live — the things that must NOT get worse (latency, error rate, churn, support volume, a sibling funnel). A launch with only a success metric has no abort condition. If you can't name what would make you roll back, you're not ready.

## Output

A markdown plan: tier + rationale → per-phase gate tables (`owner · pass condition · status`) → guardrails with thresholds → rollback steps → open risks → retro date. Mark every gate ☐/☑. The plan is ready when every T-applicable gate has an owner and a checkable pass condition.

## Contract

Consumes: a feature/product about to ship + its rollout intent
Produces: a tier-sized, phase-gated launch plan (markdown) with owners, guardrails, rollback, retro hook
Requires: nothing (richer with metric-design, dojo-copywriting, report-metrics, decision-log)
Side effects: none
Human gates: the go/no-go decision in phase 2 is a human call

## Context

Pairs well with: metric-design (success + guardrail metrics), report-metrics (readout), post-mortem (if it went wrong), dojo-copywriting (user comms), workflow-roadmap (upstream)
