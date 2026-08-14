# Session Reflection: Verify infra ground truth before locking a decision

**Date**: 2026-08-06
**Goal**: Resolve AE-158 (drift tooling) on the Delphi ML Ops wayfinder map, then handle a follow-up substrate question.

## What Went Well

- Tool/runtime half of AE-158 was grounded in real research (2025 SQL-first consensus; caught that SageMaker Model Monitor closed to new customers 2026-07-30) and held up unchanged through the later reversal.
- When the user pointed at the repo, the verification was thorough and decisive: cloned `classdojo/astronomer`, found `dags/dbt_iceberg` (dbt-trino/athena, Glue), the `wr.athena.to_iceberg` helper, `iceberg_monitoring/`, and — critically — that the drift *inputs* are Redshift-native (`teacher_predictions` joined in the Redshift dbt project; `district_churn_prediction_scores` via Redshift COPY).
- The reversal was clean and honest: all 6 durable records (AE-158 comment, AE-153 map ×2 spots, AE-164, AE-169, decision log, handoff) were reverted, and the resolution comment kept an explicit "substrate correction" trail instead of silently rewriting history.

## What Went Wrong / Friction

- **Locked a substrate recommendation (Iceberg) on a proxy, then wrote it to durable state before verifying against ground truth.** The recommendation rested on a general prior ("Iceberg is transparently warehouse-queryable, so it removes no data and adds no leg") plus the user's "we do have iceberg" — neither of which was the authoritative source. The repo showed the opposite: the Iceberg lakehouse is a *separate Trino/Athena engine* (Spectrum reads deliberately avoided) and the inputs are Redshift-native, so Iceberg would have *added* the cross-engine seam AE-157 was built to remove. The repo was clonable the whole time; nothing forced the guess.
- Cost of the miss: a full six-record reversal (Linear comment rewrite, two map patches, two delivery-ticket patches, decision-log + handoff edits, a second commit, a re-synced mirror). All avoidable by a ~2-minute repo check before the first write.
- **Linear description patching is fiddly and error-prone** where descriptions contain rendered `<issue …>` link tags. Editing text that spans a tag required awkward "tag-free span" gymnastics, and one `edit` call failed on an exact-whitespace mismatch, forcing a re-read.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "you can look at astronomer" → the repo reversed the Iceberg substrate call | Locked + wrote an infra/substrate decision from a proxy (general prior + user's verbal "we have iceberg") without checking the repo, which was the authoritative and readily available source | `grill-with-docs` (+ a `habits.md` ground-truth line) |

## Lessons

1. **A decision with a checkable in-repo answer must be checked in-repo before it is locked or written to durable state.** "We have X" and "X is generally good" are proxies. When a substrate/infra/integration choice hinges on *how* a thing is actually wired (same engine? co-located inputs? read path?), the running repo is ground truth and it beats priors every time. The tool decision (well-researched) survived; the substrate decision (assumed) did not — the difference was verification, not confidence.
2. **Order of operations for reversible-but-costly writes: verify → then fan out to durable records.** Writing to 6 places first turned a cheap correction into an expensive one. If a decision has an open verification question, hold the durable fan-out until it's closed (or write it explicitly flagged as provisional).

## Proposed Improvements

- [ ] `grill-with-docs/SKILL.md` — add a pre-lock gate: *before locking a decision whose correctness depends on how something is actually implemented (substrate, engine, integration, data location, read/write path), verify against the authoritative repo/running state — not against general best-practice priors or the user's verbal summary. If the repo is available and the question is checkable there, check it before writing the resolution.* (priority: high)
- [ ] `docs/agents/habits.md` — one durable line: *Proxy (spec/prior/verbal "we have X") vs ground truth (repo/running state) — when a decision hinges on how something is wired, read the repo before locking. Don't fan a decision out to multiple durable records while a checkable verification question is still open.* (priority: med)
- [ ] (optional, low) A `decision-log`/wayfinder note that infra-substrate resolutions should cite the repo evidence path that grounds them, so a later reader can tell verified-fact from prior. (priority: low)

<!-- No Skill Extraction Candidates: this is an enhancement to existing grill/decision-log flow, not a new repeatable multi-step workflow. -->
