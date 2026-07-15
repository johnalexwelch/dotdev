# pr-review — Posting Comments to GitHub

Load this reference only when the user explicitly asks to post the drafted comments to GitHub. By default the skill drafts to a local file and stops.

## The fast feedback workflow

The ideal workflow:

1. Skill generates each finding as a **suggestion block** anchored to a specific line in the diff (one-click apply in the GitHub UI).
2. Post as a **single pending review** via `gh api`. All comments stay invisible to the author until you submit.
3. You open the PR in the GitHub UI, click "Commit suggestion" on each one you want, comment on or dismiss the ones you don't, then click "Finish your review" → Comment.

Total author-facing time: zero until you submit. Total your time: one `gh api` call + the click-through.

## Suggestion-block format

GitHub renders a fenced `suggestion` block inside a review comment as a one-click "Commit suggestion" button. The replacement text goes inside the suggestion fence; everything else in the comment body is the explanation.

````markdown
Per `pr-review/references/naming-conventions.md`, surrogate keys use the `_pk` suffix.

```suggestion
    md5(...) as parent_active_growth_accounting_monthly_pk,
```
````

Rules for the suggestion fence to work:

- The comment must anchor to the **exact line(s)** the suggestion replaces. For a multi-line suggestion, use `start_line` + `line` and the suggestion block must contain exactly that many lines of replacement text.
- The suggestion block contents must be the **full replacement text** for the anchored line(s), including indentation. Do not include the original text or a diff format — just the new line(s).
- One suggestion block per comment. If the same finding needs multiple disjoint edits, use multiple comments.
- Markdown explanation goes outside the suggestion fence (above or below).

When a finding is not mechanically applicable as a suggestion (e.g., "add a schema yml description"), write a normal review comment without a suggestion block.

## Pre-post humanizer check (mandatory)

Before building the `gh api` call, run the humanizer's `check_tells.py` on the comment bodies and review body. PR comments are the highest-visibility AI-tell surface in the workflow; one em-dash or one "let me know if" in a posted review makes the rest of the work look like a chatbot wrote it.

Extract the bodies from the JSON payload and run the check:

```bash
python3 -c "
import json
d = json.load(open('/tmp/pr-<N>-review.json'))
out = [d.get('body', '')]
out.extend(c['body'] for c in d.get('comments', []))
open('/tmp/pr-<N>-bodies.md','w').write('\n---\n'.join(out))
"

python3 ~/dotdev/dotfiles/.claude/skills/humanizer/scripts/check_tells.py /tmp/pr-<N>-bodies.md
```

The check must return `TOTAL: 0` before posting. If it returns any hits:

1. Identify each match (em dashes, chatbot artifacts, hedges, third-person abstractions, bolded list headers, rule-of-three).
2. Rewrite the offending comment bodies in the JSON payload.
3. Re-run `check_tells.py` until clean.

Do not post a review that hasn't passed the check. The cost of fixing a posted review is higher than the cost of fixing the JSON: each comment requires a separate `PATCH repos/{owner}/{repo}/pulls/comments/{id}` call, the review body requires `PUT repos/{owner}/{repo}/pulls/{N}/reviews/{review_id}`, and the author may see the original before edits land.

Common AI tells in PR comments specifically:

- Em-dashes anywhere (`—`). Replace with periods, colons, or parentheses.
- "Let me know if you want the diff" / "Want me to also...". Direct ask or no ask. Banned by `CHATBOT` patterns.
- "Per the [naming-conventions.md] / Per the column conventions table" repeated across comments. State the rule directly. Link to the doc once in the review body, not in every comment.
- Bolded inline headers like `**\`growth_state\` → \`growth_status\`** (not a one-click — column is produced upstream)`. Lead with the change as a sentence, not as a header-plus-parenthetical.
- "Same as above" / "Same issue as `region` above". Each comment must stand on its own; GitHub renders them in a separate file/line context where "above" doesn't anchor.
- Meta-prose about the review workflow itself ("Posting the findings as a pending review so you can click..."). The user knows how GitHub works.

## Confirmation gate

Before any posting, confirm with the user:

1. Which PR (number and repo)
2. As a single pending review batch, or as individual comments?
3. Approve, request changes, or just comment?

Do not post without explicit confirmation on all three.

## Pending review batch (recommended)

A pending review groups all comments into one notification for the PR author, rather than spamming N separate comment notifications. Use this for any review with more than one or two comments.

```bash
gh api -X POST repos/<OWNER>/<REPO>/pulls/<N>/reviews \
  -f event=COMMENT \
  -f body="<top-level summary text>" \
  -F "comments[]=[{path,line,body}]"
```

The full call needs a JSON file because of the nested array:

```bash
cat > /tmp/review-payload.json <<'EOF'
{
  "event": "COMMENT",
  "body": "<top-level summary>",
  "comments": [
    {
      "path": "dags/dbt/snapshots/production_school_one_to_ones.sql",
      "line": 11,
      "body": "<comment body>"
    },
    {
      "path": "dags/dbt_iceberg/snapshots/snapshot.yml",
      "line": 62,
      "body": "<comment body>"
    }
  ]
}
EOF

gh api -X POST repos/<OWNER>/<REPO>/pulls/<N>/reviews \
  --input /tmp/review-payload.json
```

`event` values:

- **omit the field entirely**: leaves the review in PENDING state. The user opens the GitHub UI, reviews each comment, then clicks "Finish your review" to submit. **This is the default for the fast-feedback workflow** — use it unless the user explicitly asked to submit immediately.
- `COMMENT`: submits immediately as a comment review. Author gets a notification. Use only when the user said "post and submit" or equivalent.
- `APPROVE`: approves the PR. Requires explicit user confirmation.
- `REQUEST_CHANGES`: blocks the PR. Requires explicit user confirmation.

**Gotcha:** if `event` is set to anything (including `COMMENT`), the review is no longer pending. There is no way to un-submit. To create a true draft, the JSON payload must not contain an `event` key at all.

## Multi-line comments

For a comment that spans a range, include `start_line` and `start_side`:

```json
{
  "path": "...",
  "start_line": 4,
  "line": 12,
  "side": "RIGHT",
  "start_side": "RIGHT",
  "body": "..."
}
```

`side` is `RIGHT` for the head version (the change), `LEFT` for the base version. Default to `RIGHT` for comments on new/modified code.

## Top-level PR comment (not a review comment)

For comments that do not anchor to a specific line — e.g. the PR summary — use the issue comments endpoint:

```bash
gh api -X POST repos/<OWNER>/<REPO>/issues/<N>/comments \
  -f body="<top-level summary>"
```

But: if you are already posting a pending review, put the summary in the review `body` field instead. Do not double-post.

## Safety

- Always echo back the payload to the user before submitting
- Always confirm the PR number explicitly
- Never use `event=APPROVE` or `event=REQUEST_CHANGES` without the user saying those exact words
- If `gh api` returns an error, stop and report it — do not retry with modified payloads

## Re-posting after edits

If the user edits `/tmp/pr-<N>-review-comments.md` between draft and post, re-parse the file before building the payload. Do not cache the parsed comments across edits.

## Patching live comments after posting

If a humanizer issue slips through and a review is already live, patch the live comments rather than asking the user to recreate the review. The endpoints:

```bash
# Edit a single review comment body
gh api -X PATCH repos/<OWNER>/<REPO>/pulls/comments/<comment_id> \
  -f "body=<new body>"

# Edit the top-level review body
gh api -X PUT repos/<OWNER>/<REPO>/pulls/<N>/reviews/<review_id> \
  -f "body=<new review body>"
```

List the live comments to get ids:

```bash
gh api repos/<OWNER>/<REPO>/pulls/<N>/reviews/<review_id>/comments \
  --jq '.[] | {id, path: (.path | split("/") | last), line, body_preview: (.body[0:60])}'
```

For more than two or three patches, write a small Python script that iterates the rewrites rather than running individual `gh api` commands. Watch shell-escaping carefully when the body contains single quotes (use `-f "body=..."` with double quotes outside, never embed unescaped single quotes inside).
