# Humanizer — Code Review Voice

Load this reference when the text being humanized is a GitHub PR review comment, code review feedback, or inline annotation. Default humanizer output drifts toward blog or docs voice, which reads wrong in a review thread.

## Why code review voice is different

A reviewer is a coworker, not a tutorial author. The reader already has context: they wrote the code, they know what file it lives in, they understand the codebase. Reviewer comments that explain too much, summarize too much, or signpost too much come across as either condescending or AI-generated.

Code review comments should:

- Lead with the failure mode the change prevents, not the rule it cites
- Show the fix as a code block, not as prose describing the fix
- Cite one supporting link, not a `References:` footer
- Use natural senior-IC voice: short, direct, occasionally informal
- Use proper grammar and capitalization unless the reviewer's established voice is different
- Speak in first person plural ("we") about the codebase. We own this code together. Avoid third-person framings ("the author", "the reviewer", "the next person", "downstream consumers", "anyone editing this") when first-person plural says the same thing more directly
- Be direct, not hedging. "Add a guardrail." Not "It might be worth adding a guardrail."

## Voice anchors

### Senior IC review voice

- "The `timestamp` strategy assumes `updatedat` gets touched on every write. For MySQL tables driven by app code, that assumption breaks silently."
- "Confirm the DMS mode here. If it's incremental, the flag does nothing."
- "Batch this with a style sweep instead."
- "Same DAG-level feedback as the redshift sibling. See that comment for the reasoning."
- "We pick one casing and apply it everywhere."

### AI-template review voice (avoid)

- "**Critical:** This PR introduces a significant risk that warrants careful consideration."
- "The `timestamp` strategy serves as a foundational mechanism that relies on the upstream system's reliability, underscoring the importance of validating this assumption."
- "**1. Strategy concern.** **2. Naming convention.** **3. Testing gap.**"
- "Reference: dbt snapshots strategies documentation. Reference: SQL standards rule catalog. Reference: PR #8909 exemplar."

## Patterns specific to review comments

### 1. No bolded inline numbered headers in a single comment

A single review comment is one thought. If you have three thoughts about one location, write three comments anchored separately. Stuffing them into one comment with `**1.** ... **2.** ... **3.** ...` reads as AI structure.

**Bad:**
```
**1. Strategy.** The timestamp strategy is fragile.
**2. Naming.** Rename to snap_*.
**3. Tests.** Add a uniqueness test.
```

**Good (three separate comments on three different lines):**
```
[on the config block]
The timestamp strategy is fragile here because updatedat is app-managed...

[on the snapshot name]
We've been moving toward snap_<schema>__<table>_history for new snapshots...

[on the yml entry]
Worth adding a uniqueness test on the SCD2 grain...
```

### 2. No "References:" footer

The link belongs inline where it supports the point, not collected at the bottom.

**Bad:**
```
The timestamp strategy assumes the source updates the column reliably.

References:
- dbt snapshot strategies
- PR #8909 example
- SQL standards rule catalog
```

**Good:**
```
The timestamp strategy assumes the source updates the column reliably.
See [snap_production__district_history.sql](link) for the check-strategy
pattern, and [dbt docs](link) for background.
```

### 3. No principle-first openings

Open with the concrete failure mode in this specific file, not the abstract principle. The principle can follow if it adds context.

**Bad:**
```
Snapshots should declare a target_schema that adapts to the dbt target
to support local development workflows. Hardcoding the schema name
means dev runs cannot operate in isolation, which is an anti-pattern.
Currently this file hardcodes 'history'.
```

**Good:**
```
target_schema='history' is hardcoded, so anyone running this snapshot
in a dev target writes to the shared production schema. A Jinja
conditional fixes it:

    target_schema=target.schema ~ '_history' if target.name == 'dev' else 'history',
```

### 4. No "Let me know if..." closers

Review threads are conversational by default. Adding "let me know if you have questions" or "happy to discuss" is collaborative-communication-artifact territory.

### 5. Ban hedging phrases

The following phrases hedge instead of recommending. They read as AI-template politeness or as the reviewer not actually having a position. Replace with direct recommendations:

| Hedge | Direct |
|---|---|
| "Worth confirming X." | "Confirm X." |
| "Worth a look at X." | "X is wrong because Y." or "Check X." |
| "Worth adding X." | "Add X." |
| "Worth pulling into a helper." | "Pull this into a helper." |
| "Worth opening an issue." | "Open a follow-up issue for X." |
| "Worth a sentence in the description." | "Add a sentence to the description." |
| "OK to defer to a follow-up." | "Defer to a follow-up." or just drop |
| "Could be a CTE." | "Lift this into a CTE." |
| "Might want to consider X." | "Do X." |
| "Probably fine to leave." | "Leave as-is." or drop |

Acceptable status statements (these are factual, not hedges):

- "Not blocking." (stating a severity)
- "OK to merge as-is." (stating an approval)
- "Confirmed by the test plan." (citing evidence)

The distinction: status statements describe the comment's weight. Hedges describe the reviewer's confidence. We have confidence; we don't perform confidence.

## Worked example

### AI-template version

> ## Snapshot Configuration Issue
>
> **Summary:** The current configuration relies on the `timestamp` strategy, which is a pivotal decision that warrants careful consideration.
>
> **The Problem:**
> - 🔴 The `timestamp` strategy depends on reliable `updated_at` column maintenance
> - 🔴 For application-managed columns, this assumption may not hold
> - 🔴 Failures are silent and difficult to detect after the fact
>
> **The Solution:** Adopt the `check` strategy with explicit `check_cols`:
>
> ```sql
> strategy='check',
> check_cols=['col_a', 'col_b'],
> ```
>
> **Benefits:**
> - Eliminates the dependency on application behavior
> - Provides deterministic change detection
> - Aligns with our established best practices
>
> **References:**
> - dbt snapshot strategies documentation
> - PR #8909 exemplar implementation
> - SQL standards rule catalog
>
> Let me know if you'd like to discuss this further!

### Senior IC version

> The `timestamp` strategy assumes `updatedat` gets touched on every write. For MySQL tables driven by application code rather than `ON UPDATE CURRENT_TIMESTAMP`, that assumption breaks silently. When a code path mutates a row without updating the column, the snapshot skips that change. History ends up wrong with no error to alert us.
>
> Switch to the `check` strategy, which diffs the business columns row-by-row:
>
> ```sql
> strategy='check',
> check_cols=['district_name', 'district_email_domain', ...],
> ```
>
> See [snap_production__district_history.sql](link) for the pattern.

## Final check

Before shipping review comments, run `scripts/check_tells.py` on the output. The mechanical tells (em dashes, curly quotes, AI vocab, bolded list headers) should be at zero. A few `rule_of_three` or `title_case_headings` hits are usually fine in this context — many engineering concepts naturally come in threes ("config, source, tests") and many file paths are title-case-like.
