# pr-review — Workflow

Full pipeline for reviewing a GitHub pull request against a standard.

## 1. Clarify the link role

If the user gives one URL with ambiguous framing (e.g. "review this PR, here is an example of the new standards"), stop and ask which is the review target and which is the reference standard. Do not infer.

Common patterns:

- "Review #X against #Y" — clear: X is target, Y is reference
- "Review this PR" + one link — clear: that link is the target, ask if a standard should be used
- "Here is the new standard, review this PR" + one link — ambiguous: link could be either, ask

## 2. Fetch the PR

```bash
# Metadata, file list, author, branches, body (PR description)
gh pr view <N> --json title,body,files,baseRefName,headRefName,author,additions,deletions

# Diff content
gh pr diff <N>

# Head SHA for permalinks
gh pr view <N> --json headRefName,headRefOid -q '.headRefName + " " + .headRefOid'
```

For files where line context matters, fetch the raw file from the PR branch:

```bash
gh api repos/<OWNER>/<REPO>/contents/<PATH>?ref=<HEAD_REF> \
  -H "Accept: application/vnd.github.raw"
```

## 2b. Read the PR description carefully

The `body` field from step 2 is not boilerplate — it contains context that should shape every comment. Before writing any review, extract:

- **Summary**: what the author thinks the PR does. If your read of the diff doesn't match the summary, that's a finding.
- **Test plan**: what's already been validated, with what numbers. Do not flag concerns that the test plan already proves are non-issues. If reconciliation tests have been verified against 100M+ rows of prod data, do not recommend the author add reconciliation tests — they exist and they pass.
- **Known issues / caveats**: things the author already acknowledges (e.g. "mypy is blocked locally by an existing environment conflict", "nonzero exit due to existing Elementary hook issue"). Surface these in the top-level summary so other reviewers don't waste cycles asking about them.
- **Verification evidence**: row counts, dashboard IDs, command output. Cite these in the summary to anchor the review ("agg row count reconciliation already confirmed against 589M rows across 47 month-end snapshots, so the singular test serves as ongoing guard rather than initial validation").
- **Out-of-scope / follow-up notes**: anything the author explicitly defers. Don't re-raise as a blocker; either accept the deferral or flag it in "worth a look".

Ground every comment in this context. A finding that contradicts the PR's verified test plan is either a misread of the diff or a higher-order concern (e.g. the test plan covers correctness but not performance). Be explicit about which.

## 3. Detect PR type and load standards

Look at `files[].path` patterns:

| Path pattern | Likely type | Standard to load |
|---|---|---|
| `dags/dbt*/models/**/*.sql` | dbt model | `dbt` skill + `sql-standards` skill + `pr-review/references/naming-conventions.md` |
| `dags/dbt*/snapshots/*.sql` | dbt snapshot | `dbt` skill + `dbt/references/snapshots.md` + `sql-standards` skill + `pr-review/references/naming-conventions.md` |
| `dags/dbt*/**/*.yml` | dbt schema yaml | `dbt` skill + `sql-standards` skill (YAML001/002, KEY001) + `pr-review/references/naming-conventions.md` |
| `dags/dbt_snapshots/*.py` | snapshot Airflow DAG | `airflow` skill + `dbt/references/snapshots.md` |
| `dags/*.py` (other) | Airflow DAG | `airflow` skill |
| `*.py` (non-dag) | Python utility | `python` skill |

Multiple types → load each.

### Always load `sql-standards` for any dbt SQL or YAML touched

The `sql-standards` skill (at `.agents/skills/sql-standards/` in the astronomer repo) defines enforceable rules: CFG001–CFG008, JOIN001–002, CASE001, FINAL001–003, CTE001–002, IGN001–002, YAML001–002, KEY001, DATE001. Load `references/rule-catalog.md` and `references/standards.md` from that skill before reviewing any dbt SQL.

If the skill isn't merged to main yet (check `gh pr list --search 'sql-standards skill'`), fetch it from the open PR:

```bash
gh pr view <skill-pr-N> --json headRefName -q .headRefName
git fetch origin pull/<skill-pr-N>/head:pr-<skill-pr-N>
git show pr-<skill-pr-N>:.agents/skills/sql-standards/references/rule-catalog.md
```

### Always load `naming-conventions.md` for any dbt SQL or YAML touched

`references/naming-conventions.md` in this skill is the **locked-in standard** for column and table naming. When reviewing dbt SQL or schema yml:

1. Scan every new column the PR introduces against the column conventions table. Flag deviations (`_key` instead of `_pk`, `flag_*` instead of `is_*`, `_ts`/`_dt` instead of `_at`/`_date`, plural noun instead of `_count`, etc.).
2. Scan every new table/model name against the table conventions table. Flag wrong prefix layer (`fct_*` for a dimension, missing grain in an aggregate, compound prefixes like `fct_dim_*`).
3. **Apply the family-consistency rule from §3b**: if the new model is in a family that uses legacy naming (e.g., adding a `_monthly` model when the existing `_weekly` uses `_key`), prefer matching the legacy convention for the new model and recommend a sweep PR. Don't ship asymmetric naming.
4. Link to the specific row in `naming-conventions.md` when flagging. Anchor recommendations to the policy, not to the reviewer's preference.

## 3b. Consistency check against sibling/predecessor files

Before flagging structural or convention issues on a new file, check whether the new file mirrors an existing in-repo pattern (e.g., a monthly model copied from a weekly sibling).

```bash
ls <dir-of-changed-file>/
git show main:<sibling-path> | head -50
```

Use the sibling check to inform tone and context, not to defer the fix:

- **Fix the new code in this PR.** Every deviation in the new files gets a suggestion block anchored to the exact line.
- **Note sibling parity once** in the top-level summary: "the existing `<sibling>.sql` has the same pattern; this PR fixes only the new files, sibling stays on legacy naming until someone edits it for another reason."
- **Do not recommend follow-up sweep PRs.** They never get prioritized. Legacy files migrate opportunistically when they're already being edited.
- **Do not block on asymmetry.** The new files conforming to the locked standard is strictly better than the new files copying the legacy pattern, even if the family is temporarily mixed.

The `sql-standards` baseline (`sql_standards.py baseline`) can quantify how many files currently violate each rule. Useful for prioritizing which rules to add enforcement on, not for deferring individual fixes.

## 4. Compare against the standard

For each changed file, identify violations or gaps. For each, capture three things:

1. **What** is wrong (file + line + concrete issue)
2. **Why** it matters (the failure mode the fix prevents)
3. **How** to fix it (a code snippet showing the change)

Drop findings that are stylistic preferences with no failure mode behind them, unless the user explicitly asked for style review.

## 5. Per-file comment blocks

Use the format in `comment-format.md`. Each comment is one thought, anchored to one file and one line (or short range). Split multiple thoughts on the same file into separate comments anchored to different lines.

**Line numbers are mandatory.** Every comment heading must include `(line N)` or `(lines X–Y)`. Resolve line numbers against the PR head, not local main:

```bash
git fetch origin pull/<N>/head:pr-<N>
git show pr-<N>:<path> > /tmp/<basename>
grep -n '<distinctive snippet>' /tmp/<basename>
```

If the agent's local repo has uncommitted changes blocking checkout, `git show pr-<N>:<path>` reads files from the PR ref without touching the working tree.

## 6. Top-level PR summary

Group asks by severity:

- **Fix before merge**: blocking issues with real failure modes
- **Can batch**: style / convention issues that could land in a follow-up sweep
- **Worth a look**: questions or possible improvements, not blocking

The summary should be skimmable in 30 seconds. Detail belongs in the per-file comments, not the summary.

## 7. Build the JSON payload

Write the review as a JSON payload at `/tmp/pr-<N>-review.json`. This is the primary output format. Each finding becomes one of:

- **Suggestion block**: single-line mechanical change (rename, suffix fix, casing). GitHub renders it as a one-click "Commit suggestion" button. See `posting.md` for the suggestion-block format and the fence rules.
- **Regular comment**: multi-site renames, judgment calls, anything that needs a decision before a diff can be written.

JSON shape:

```json
{
  "commit_id": "<head SHA>",
  "event": "COMMENT",
  "body": "<top-level review summary>",
  "comments": [
    {
      "path": "<repo-relative file path>",
      "line": <line number on the RIGHT side>,
      "side": "RIGHT",
      "body": "<comment body, may contain a suggestion block>"
    }
  ]
}
```

For multi-line suggestions, add `"start_line"` and `"start_side": "RIGHT"` to span lines.

Omit `"event"` entirely to keep the review in PENDING (draft) state. Setting `"event": "COMMENT"` submits immediately. See `posting.md` for the full gotcha.

**Fallback:** if the user prefers manual pasting, also write `/tmp/pr-<N>-review-comments.md` in markdown-paste format (4-backtick outer fences around each comment body). The JSON payload is preferred.

## 8. Check, then offer to post

Run the tells check on the JSON payload bodies and offer to post. Both are documented in `posting.md` — the check command, the `gh api` call, and the pending-vs-submitted event gotcha. Do not post without explicit confirmation.

The check must return `TOTAL: 0` before posting.
