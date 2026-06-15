# Numeric Claims Ledger

Load this during the numeric check and numeric claims audit whenever the document depends on quantitative claims.

## Ledger Fields

| Field | Meaning |
|-------|---------|
| Claim | The sentence or implication the document wants to make |
| Number | The metric value, trend, percentage, count, or comparison |
| Source | Dashboard, query, data pull, transcript, or doc where it came from |
| Definition | Metric definition, denominator, cohort, and grain |
| Date range | Time period and comparison window |
| Filters | Segments, exclusions, and joins |
| Status | Verified, directional, needs caveat, mismatch, or unverified |
| Notes | Caveats, follow-up questions, or reproduction steps |

## Validation Rules

- Verify against the original source, query, dashboard, or exported data whenever possible.
- Check date ranges, filters, denominators, cohorts, and apples-to-apples comparisons.
- Distinguish correlation from causation.
- If Iris and the source disagree, trust the source and flag the discrepancy.
- Block finalization on unverified, mismatch, or needs-caveat numbers unless the memo explicitly labels them as directional.

After drafting, extract every number and quantitative comparison from the memo back into this ledger. Re-check any number introduced during writing. Do not let polishing or synthesis create new numeric claims without validation.
