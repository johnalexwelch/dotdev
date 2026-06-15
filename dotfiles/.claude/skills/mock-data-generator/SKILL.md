---
name: mock-data-generator
model: sonnet
reasoning: high
description: >-
  Generate realistic, referentially-consistent mock datasets from a schema — CSV, JSON, or
  SQL INSERTs — with foreign keys that actually resolve, constraints, and dialect-aware SQL.
  Use when someone needs test fixtures, demo/seed data, sample rows to prototype a dashboard
  or query against, or says "generate fake/mock/sample/test data", "seed this table", or
  "I need rows that look real with valid foreign keys".
---

# Mock Data Generator

Produces fake-but-plausible data that holds together: child rows reference real parent keys, types and constraints are honored, and the output drops straight into a CSV import, a JSON fixture, or a SQL seed. Use the bundled script — it's deterministic with a seed and handles FK integrity, which is the part hand-rolled fakes get wrong.

## Quick start

Define a schema (Python dict or JSON), then run the generator:

```bash
python scripts/gen_mock_data.py --schema schema.json --out ./fixtures --format sql --dialect postgres --seed 42
```

Schema shape:

```json
{
  "tables": [
    {"name": "users", "rows": 100, "fields": {
      "id":    {"type": "sequence", "start": 1},
      "email": {"type": "email"},
      "name":  {"type": "name"},
      "plan":  {"type": "choice", "values": ["free", "plus"], "weights": [0.8, 0.2]},
      "created_at": {"type": "date", "start": "2024-01-01", "end": "2025-12-31"}
    }},
    {"name": "orders", "rows": 300, "fields": {
      "id":      {"type": "sequence", "start": 1},
      "user_id": {"type": "fk", "table": "users", "field": "id"},
      "amount":  {"type": "float", "min": 5, "max": 200, "round": 2},
      "status":  {"type": "choice", "values": ["paid", "refunded"], "weights": [0.9, 0.1]}
    }}
  ]
}
```

Supported field types: `sequence`, `int`, `float`, `bool`, `choice` (optional `weights`), `name`, `first_name`, `email`, `uuid`, `date`, `pattern` (`"###-??"` → digits/letters), `fk`. If `faker` is installed it's used for richer `name`/`email`; otherwise built-in providers are used (no dependency required).

## How it works (the part that matters)

- **FK integrity**: tables are topologically sorted by their `fk` references; parents generate first, children sample real parent keys. A cycle is reported as an error, not silently broken.
- **Determinism**: `--seed` makes runs reproducible.
- **Dialect-aware SQL**: `--dialect postgres|mysql|sqlite` controls identifier quoting and value escaping; strings are escaped, NULLs emitted as `NULL`.

Outputs one file per table (`<table>.csv` / `.json` / `.sql`) in `--out`.

## When to reach for it vs. not

Use it for fixtures, demos, dashboard prototyping, and seeding a dev DB. Pair with `data-readiness-check` / `sql-review` to validate the generated set, and `experiment-design` when you need simulated samples. It is **not** a production data tool and not a substitute for anonymized real data when distributions matter — say so if the ask is really "data that matches our true distribution."

## Contract

Consumes: a schema (JSON/dict) describing tables, rows, fields, and FKs
Produces: per-table CSV / JSON / SQL fixtures with resolved foreign keys
Requires: python3 (faker optional, auto-detected)
Side effects: writes fixture files to the chosen output dir
Human gates: none

## Context

Pairs well with: data-readiness-check, sql-review (validate the output), experiment-design (simulated samples)
