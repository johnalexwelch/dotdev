# Cognitive Bias Catalog

Reference for the `bias-auditor` persona (and any analysis-council member). Each entry: what it is · the **detection signal** in a document · the **de-biasing move** that would settle it. Cite the entry name when you raise a finding (e.g. `[MED] anchoring`).

A bias is only a *finding* when it is **load-bearing** — i.e. the conclusion depends on the biased step. Quote the locus; name the catalog entry; give the de-biasing move. Tag severity per `council-scaffolding` (`[HIGH]/[MED]/[LOW]`).

## Evidence-gathering biases

- **Confirmation bias** — evidence is collected to support a held belief. *Signal:* every cited fact points one way; no "we looked for X and didn't find it." *De-bias:* name the strongest disconfirming evidence and whether it was sought.
- **Motivated reasoning** — the author benefits from the conclusion. *Signal:* the recommended option is also the author's/team's preferred or prior-committed one. *De-bias:* have someone with the opposite incentive argue the case.
- **Availability** — easy-to-recall instances drive the estimate. *Signal:* "we keep seeing…", recent or vivid anecdotes as the evidence base. *De-bias:* pull the actual frequency / denominator.
- **Survivorship** — only the cases that made it to view are counted. *Signal:* studying winners (shipped features, retained users) to explain success. *De-bias:* find the ones that dropped out before the dataset.

## Estimation biases

- **Anchoring** — judgments cling to an initial number or plan. *Signal:* targets are ±small% off a prior figure that was never itself justified. *De-bias:* estimate from a blank slate or a reference class, then compare.
- **Base-rate neglect / inside view** — reasoning from this case's specifics, ignoring how similar efforts go. *Signal:* a detailed success path with no "projects like this usually…". *De-bias:* build the reference class (outside view) and start from its base rate.
- **Planning fallacy** — timelines/costs assume the best case. *Signal:* a single estimate, no range, no buffer, no failure modes. *De-bias:* run a pre-mortem; estimate P50/P90.
- **Overconfidence** — stated certainty exceeds the evidence. *Signal:* point estimates with no interval; "clearly," "obviously." *De-bias:* ask for the confidence interval and what would move it.

## Interpretation biases

- **Narrative fallacy** — a clean causal story imposed on noisy events. *Signal:* a tidy "X happened because Y" with no counterexample. *De-bias:* check whether the story would also "explain" the opposite outcome.
- **Hindsight** — past events look more predictable than they were. *Signal:* "we always knew," post-hoc inevitability. *De-bias:* reconstruct what was actually knowable at the time.
- **Framing / loss aversion** — the same facts read differently as gains vs. losses or default vs. opt-in. *Signal:* persuasion leans on one framing. *De-bias:* re-state the choice in the opposite frame and see if the recommendation holds.

## Commitment & social biases

- **Sunk cost / escalation** — past investment justifies continued investment. *Signal:* "we've already spent…", "too far to stop." *De-bias:* ask the forward-looking question — would we start this today, knowing what we know?
- **Status-quo / default bias** — the current state gets a free pass. *Signal:* alternatives must clear a bar the status quo never had to. *De-bias:* subject "do nothing" to the same scrutiny as the proposal.
- **Groupthink** — agreement mistaken for evidence. *Signal:* unanimous support, no recorded dissent. *De-bias:* assign a devil's advocate; gather views independently before discussion.
- **Authority / HiPPO anchoring** — a senior voice sets the anchor everyone adjusts from. *Signal:* the rationale traces to who said it, not what's shown. *De-bias:* have the most junior person estimate first.
