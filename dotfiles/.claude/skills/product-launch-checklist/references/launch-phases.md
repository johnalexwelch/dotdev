# Launch Phases — Detail & Worked Example

Companion to `product-launch-checklist/SKILL.md`. Expanded gate menus per phase (pick what applies to the tier) and a worked T2 example.

## Gate menus (superset — prune to the tier)

### Phase 1 — Plan / readiness
- Success metric named, with a target and an owner (use `metric-design`).
- Guardrail / counter-metrics named, each with a "do not breach" threshold.
- Audience defined (all users? cohort? %? geo? internal-first?).
- Rollout mechanism chosen (feature flag, staged %, dark launch, hard cutover).
- Risk register: top risks × likelihood × impact × mitigation × owner.
- Privacy/legal/compliance review (mandatory if child data, consent, contracts).
- Dependencies confirmed (upstream services, third parties, data backfills).
- Rollback path written and feasible (flag off? revert? data migration reversible?).

### Phase 2 — Pre-launch / go-no-go
- Instrumentation verified actually emitting the success + guardrail events.
- Dashboards/alerts live and watched by a named owner.
- Support / CS / community briefed; FAQ + known-issues doc shipped.
- User-facing comms drafted & approved (in-app, email, release notes, store text).
- Internal announcement ready (who hears about it, when).
- On-call / launch owner named for the launch window with escalation path.
- Go/no-go decision explicitly recorded with the deciders (`decision-log`).

### Phase 3 — Launch
- Staged ramp plan (e.g. 1% → 10% → 50% → 100%) with a hold-and-watch gate between stages.
- Guardrails checked against thresholds at each stage before widening.
- A single named person owns the abort/rollback call.
- Comms sent on schedule; support watching inbound.

### Phase 4 — Post-launch / close
- Success metric read out: absolute + vs-goal + YoY where it exists (`report-metrics`).
- Guardrails reviewed over the watch window (not just launch day).
- Flag state finalized: fully rolled out, held, or rolled back — with the reason.
- Retro scheduled; route to `post-mortem` if there was an incident or a miss.
- Learnings fed back to `workflow-roadmap` / the next launch.

## Worked example — T2: "Parent weekly digest email"

**Tier:** T2 standard (existing parents, reversible via flag). Touches parent contact data → privacy check required, so treat the privacy gate as mandatory.

| Phase | Gate | Owner | Pass condition |
|------|------|-------|----------------|
| Plan | Success metric | PM | digest open-rate ≥ X%; target set with metric-design |
| Plan | Guardrail | PM | parent email unsubscribe rate must not rise > 0.5pp; support tickets flat |
| Plan | Privacy | Legal | confirmed no child PII in digest body |
| Plan | Rollback | Eng | flag `parent_weekly_digest` off = full stop, no data cleanup needed |
| Pre | Instrumentation | Eng | open/click/unsub events verified in dashboard |
| Pre | Comms | PMM | in-app heads-up + first-send subject line approved (dojo-copywriting) |
| Pre | Go/no-go | PM | recorded go with eng+legal sign-off |
| Launch | Ramp | Eng | 5% cohort → hold 48h → watch unsub guardrail → 100% |
| Post | Readout | PM | open-rate vs goal reported; unsub guardrail clean over 2 wks |
| Post | Retro | PM | scheduled; no incident → light retro |

Guardrails breached → abort owner (Eng) flips the flag; PM opens `post-mortem` only if the unsub spike was an incident.
