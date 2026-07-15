# Naming Conventions

Locked-in standard for column and table naming in dbt projects. Use this as the authoritative reference during PR reviews. When a PR diverges, link to this doc rather than re-deriving the rule.

These conventions are pulled from established analytics-engineering best practices:

- [dbt Labs — How We Style Our SQL](https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql)
- [dbt Labs — How We Structure Our dbt Projects](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview)
- [Brooklyn Data dbt SQL Style Guide](https://github.com/brooklyn-data/co/blob/main/sql_style_guide.md)
- Kimball dimensional modeling (for `fct_*` / `dim_*` prefixes)

Where guides disagree, the option chosen is the more explicit one (e.g., `_pk` over `_id` for surrogate keys), because the goal is conventions that are self-documenting at read time.

---

## Column naming conventions

| Pattern | Type / meaning | Examples | Notes |
|---|---|---|---|
| `<entity>_id` | Natural ID from source system (a real identifier that exists outside the warehouse) | `parent_id`, `school_id`, `class_id`, `order_id` | One identifier per entity. Never abbreviate (`pid` → `parent_id`). |
| `<entity>_pk` | Surrogate primary key (typically `md5()` or `dbt_utils.generate_surrogate_key()`) | `parent_active_monthly_pk`, `subscription_pk` | Replaces legacy `_key` suffix. Pairs cleanly with `_fk` below. |
| `<entity>_fk` | Surrogate foreign key — points to a `_pk` on another table | `parent_pk_fk`, `subscription_pk_fk` | Only used when the FK is itself a surrogate. Natural FKs stay as `<entity>_id`. |
| `is_<predicate>` | Boolean (true/false) | `is_active`, `is_paid_subscriber`, `is_current_period_active` | Never store booleans as 0/1 ints or 'Y'/'N' strings. |
| `has_<thing>` | Boolean for existence/possession | `has_logged_in`, `has_teacher_connection` | Alternative form for booleans where `is_` reads awkwardly. |
| `<event>_at` | Timestamp with timezone (UTC) | `signed_up_at`, `created_at`, `subscription_started_at` | Always timestamptz, always UTC. |
| `<event>_date` | Date (no time component) | `month_end_date`, `signup_date`, `report_date` | Use when the value is intrinsically a calendar date, not a truncated timestamp. |
| `<metric>_count` | Non-negative integer count | `teacher_connection_count`, `active_days_count` | Replaces ambiguous `num_*` / `n_*` / pluralized names. |
| `<metric>_amount` | Monetary value in a single currency | `subscription_amount_usd`, `revenue_amount_usd` | Suffix the currency explicitly when multi-currency is possible. |
| `<metric>_pct` | Percentage, stored 0–100 | `conversion_pct`, `churn_pct` | Pick one of `_pct` or `_rate` and use it consistently. dbt Labs uses `_pct`. |
| `<metric>_rate` | Ratio, stored 0–1 | `conversion_rate`, `retention_rate` | Distinct from `_pct`. Document the convention once and stick to it. |
| `<metric>_<unit>` | Duration or magnitude with explicit unit | `session_duration_seconds`, `days_since_signup`, `tenure_months` | Unit is part of the name. Never assume the reader knows. |
| `<entity>_code` | Short machine-readable code | `country_code`, `currency_code`, `state_code` | Always paired with a `_name`. |
| `<entity>_name` | Human-readable display string | `country_name`, `district_name`, `plan_name` | Always paired with a `_code`. |
| `<entity>_status` | Enum string for a state | `subscription_status`, `enrollment_status`, `connection_status` | Document the allowed values in the schema yml `accepted_values` test. |
| `<entity>_type` | Enum string for a kind/category | `user_type`, `event_type`, `device_type` | Same as `_status` but for taxonomy rather than lifecycle state. |
| `<entity>_category` | Higher-level grouping above `_type` | `product_category`, `engagement_category` | Use only when there's a real hierarchy. |
| `<source>_<entity>` (last-resort prefix) | Disambiguates the same concept from different sources | `salesforce_account_id`, `stripe_customer_id` | Avoid unless two columns would otherwise collide. |
| Lowercase string enums | All categorical values lowercase, no spaces | `'active'`, `'churned'`, `'unknown'`, `'cd error: ...'` | Never `'Unknown'`, `'N/A'`, `'NULL'` strings. Use real `NULL` for missing. |

### Anti-patterns to retire

| Avoid | Use instead | Why |
|---|---|---|
| `_key` for surrogate keys | `_pk` | "Key" is ambiguous — could be PK, FK, business key, or composite. `_pk` is unambiguous. |
| `num_*`, `n_*`, plural noun (`parents`, `messages`) as a column name | `<noun>_count` | Counts read as counts at every site. |
| `flag_*`, `*_flag` | `is_*` / `has_*` | Predicate-style names read naturally inside `WHERE` clauses. |
| `dt_*`, `*_dt`, `*_ts`, `*_timestamp` | `_at` (timestamp) or `_date` (date) | Two suffixes, two types, no ambiguity. |
| `created`, `updated` (bare) | `created_at`, `updated_at` | Always carry the type suffix. |
| `signup_year_cohort` (year-as-cohort) | `signup_year` (the value), or a real cohort id if the column maps to a cohort table | `_cohort` should mean "cohort identifier," not "the year." |
| Mixed casing in enum values (`'Unknown'`, `'UNKNOWN'`, `'unknown'`) | Always lowercase | Defensive `coalesce()` and `lower()` calls disappear downstream. |
| Inline column abbreviations (`cust_id`, `prod_cat`) | Full words (`customer_id`, `product_category`) | Saves the reader from a lookup. The column name is read 100× per write. |

---

## Table naming conventions

Built on dbt Labs' layered model structure plus Kimball prefixes for marts.

| Layer | Prefix / pattern | Purpose | Examples |
|---|---|---|---|
| Source (raw) | `raw_<source>__<table>` | Untouched landings from DMS, Fivetran, S3 ingest. Read-only. | `raw_production__class`, `raw_stripe__charges` |
| Staging | `stg_<source>__<entity>` | One model per source table. Renames columns to standard conventions, casts types, applies light cleaning. No joins. Singular entity. | `stg_production__parent`, `stg_stripe__subscription` |
| Intermediate | `int_<entity>_<verb_or_qualifier>` | Reusable logic between staging and marts. Plural verb describes what's happening. | `int_parents_joined_to_districts`, `int_orders_pivoted_to_users` |
| Fact (mart) | `fct_<entity>` | Transactional / event grain. One row per event/transaction. Plural entity. | `fct_orders`, `fct_plus_trials_and_bookings`, `fct_subscription_events` |
| Dimension (mart) | `dim_<entity>` | Descriptive attributes of entities. SCD type 1 or 2. Singular entity. | `dim_parents`, `dim_schools`, `dim_dates` |
| Aggregate (mart) | `agg_<grain>_<entity>` | Pre-aggregated facts at a coarser grain. Grain is part of the name. | `agg_daily_user_active`, `agg_weekly_subscription_starts` |
| Snapshot | `snp_<entity>` or `snapshot_<entity>` | dbt snapshots capturing SCD2 history of a source. | `snp_dim_parents`, `snapshot_subscriptions` |
| Reporting / cube | `<entity>_<period>_<purpose>` (no prefix) | Reporting-shaped, often denormalized, sometimes wide. Name by what's reported. | `parent_active_growth_accounting_monthly`, `cube_weekly_retention_parents` |
| Reconciliation / DQ tests | `<table>_<check_name>_reconciliation` or `dq_<table>_<check>` | Singular-purpose data-quality models or tests that compare counts/sums across tables. | `parent_active_growth_accounting_monthly_row_count_reconciliation` |

### Cross-cutting table-naming rules

| Rule | Rationale |
|---|---|
| **Singular for staging and dimensions** (`stg_production__parent`, `dim_parent`) | Each row is one of the entity. Convention in Kimball + dbt Labs. |
| **Plural for facts and aggregates** (`fct_orders`, `agg_daily_user_actives`) | Each row is one of many events. |
| **Double underscore (`__`) only between source and table in staging**: `stg_<source>__<entity>` | Makes source explicit and visually distinct from the entity name. Used nowhere else. |
| **Grain is always in the name when it's not obvious**: `daily`, `weekly`, `monthly`, `per_user`, `per_session` | Removes the "what's a row in this table?" question. |
| **Prefix once, never compound**: `fct_orders`, not `fct_dim_orders` or `agg_fct_orders` | Each model belongs to exactly one layer. |
| **Schema mirrors layer**: staging → `staging` schema, marts → `analytics` / `reporting_*` schemas | Layer is discoverable from the FQN, not just the name. |
| **No environment, no author, no date in the table name** (`fct_orders_v2`, `fct_orders_alex`, `fct_orders_2024`) | Use git, version columns, or `_history` snapshots instead. |
| **Don't put the column type in the table name** (`subscriptions_table`, `dim_parents_view`) | Materialization can change without a rename. |

### Layer routing rule of thumb

> If a model has `ref()` calls to **only** staging/sources → it's `int_*`.
> If a model has `ref()` calls to intermediates and is consumed by the BI tool / downstream domains → it's `fct_*`, `dim_*`, or `agg_*`.
> If a model is the BI tool's direct view onto a slice for a specific report → reporting-layer name, no prefix required.

---

## How to use these conventions in a PR review

1. **All new code must follow these conventions from day one.** Flag every deviation in new files (new models, new columns, new tests).
2. **Deliver each finding as a GitHub suggestion block** anchored to the exact line. One-click apply means the author doesn't have to translate prose into a code change. See `references/posting.md` for the suggestion-block format and the pending-review post call.
3. **Do not recommend follow-up sweep PRs for legacy naming.** If a legacy file has the same deviation, mention it as context in the top-level summary, but do not block the current PR on a separate rename effort. The current PR fixes what it can; legacy renames happen when someone is already editing that file.
4. **Link to this doc** in each finding so the policy is discoverable:
   > Per `pr-review/references/naming-conventions.md`, surrogate keys use the `_pk` suffix.
5. **Anchor recommendations to a specific row** in the tables above, not to the reviewer's preference.

## Adoption status (project-specific)

This doc is the locked standard. The astronomer repo currently has some legacy conventions in older files (`_key` for surrogate keys, mixed `'Unknown'` / `'unknown'` enum casing, `signup_year_cohort` for plain year values). New PRs apply the locked conventions inline. Legacy files migrate opportunistically when they're already being edited for another reason.

The `sql-standards` skill (at `.agents/skills/sql-standards/` in the astronomer repo) should grow rules that enforce the highest-value conventions over time:

- Booleans must be `is_*` or `has_*` (catches `_flag` / int booleans)
- Timestamps must end in `_at`, dates in `_date` (catches `_dt` / `_ts`)
- Surrogate keys must end in `_pk` (catches `_key`)
- Enum string defaults must be lowercase (catches `'Unknown'`)
- Counts must end in `_count` (catches `num_*` / `n_*`)

When proposing additions to `sql-standards`, link the rule back to the table row in this doc as the policy source.
