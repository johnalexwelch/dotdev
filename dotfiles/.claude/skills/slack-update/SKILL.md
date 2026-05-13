---
name: slack-update
description: Generate and send a Slack engineering update summarizing merged PRs from the prior day. Triggers on "slack update", "send update", "engineering update", "daily update", "PR summary". Groups PRs by theme with mrkdwn formatting and sends via Slack API.
user_invocable: true
codex-compatible: false
---

## Contract

Consumes: merged PRs from prior day (via gh), project-to-channel mapping
Produces: formatted Slack message summarizing PR activity
Requires: gh, Slack MCP (or SLACK_BOT_TOKEN)
Side effects: sends Slack message to configured channel
Human gates: message preview shown for approval before sending

## Context

Typical workflows: daily engineering updates (standalone)
Pairs well with: write-to-obsidian

# Slack Engineering Update

Generate a formatted Slack update from merged PRs and send it via the Slack API.

## Configuration

- **Channel mapping:** `~/.claude/slack-update-channels.json` maps project names to Slack channel IDs
- **Bot token:** `SLACK_BOT_TOKEN` from the project's `.env` file. Falls back to Iris project's `.env` at `~/projects/iris/.env`
- **Timeframe:** Prior day (midnight to midnight UTC)

## Workflow

### Step 1: Resolve project and channel

1. Determine project name from the current git remote (`gh repo view --json name -q .name`) or directory basename
2. Read `~/.claude/slack-update-channels.json` and look up the channel ID
3. If no mapping exists, ask the user for the channel ID and offer to save it

### Step 2: Load bot token

1. Check for `SLACK_BOT_TOKEN` in the current environment
2. If not set, try `grep SLACK_BOT_TOKEN .env` in the project root
3. If not found, try `grep SLACK_BOT_TOKEN ~/projects/iris/.env` as global fallback
4. If still not found, ask the user

### Step 3: Fetch merged PRs

Run:

```bash
gh pr list --state merged --search "merged:>=$(date -u -v-1d +%Y-%m-%d)" --json number,title,body,mergedAt --limit 50
```

If no PRs found, tell the user and stop.

### Step 4: Compose the update

Group PRs into thematic sections by analyzing conventional commit prefixes and PR body content. Use these section patterns:

| Emoji | Section | Commit types / signals |
|-------|---------|----------------------|
| :wrench: | Developer Tooling | `chore`, `build`, tooling, CLI, scripts, config, docs |
| :brain: | Query Intelligence | `feat`/`fix` touching agent, eval, dspy, prompts, accuracy |
| :building_construction: | Architecture | `refactor`, consolidation, cleanup, module restructuring |
| :zap: | Slack | anything touching slack/ |
| :rocket: | Features | `feat` not fitting other categories |
| :bug: | Bug Fixes | `fix` not fitting other categories |
| :gear: | CI & Automation | `ci`, workflows, GitHub Actions |
| :shield: | Security | auth, permissions, security headers |
| :art: | Frontend | `feat`/`fix` touching frontend/ |

Rules:

- Only include sections that have PRs. Don't show empty sections.
- Merge sections with only 1 PR into the closest related section if it makes sense.
- Each PR is a bullet point: `• *Title* (<https://github.com/{owner}/{repo}/pull/{number}|#{number}>) — Description`
- PR descriptions should be concise (2-3 sentences max) summarizing what changed and why, drawn from the PR body
- Title line format: `*{Project} Update — {date range}*` followed by a one-line summary of the batch
- Use em dashes (—) not hyphens for separators

### Step 5: Preview and send

1. Show the composed message to the user in the terminal
2. Ask: "Send to #{channel_name}?" (use `conversations.info` to resolve channel name)
3. On confirmation, send via the Slack API:

```python
import asyncio, os
import httpx

async def send(token, channel_id, text):
    async with httpx.AsyncClient(base_url="https://slack.com/api", headers={"Authorization": f"Bearer {token}"}, timeout=15) as c:
        r = await c.post("/chat.postMessage", json={
            "channel": channel_id,
            "text": text,
            "unfurl_links": False,
            "unfurl_media": False,
        })
        data = r.json()
        if data.get("ok"):
            print("Message sent successfully")
        else:
            print(f"Error: {data.get('error')}")

asyncio.run(send(token, channel_id, message_text))
```

4. Report success or failure to the user.

## Formatting Reference

Slack mrkdwn (NOT markdown):

- Bold: `*text*` (single asterisks)
- Italic: `_text_`
- Code: `` `text` ``
- Links: `<https://url|display text>` (only works via API, not paste)
- Bullets: `•` character (Unicode \u2022), not `-` or `*`
- Emoji: `:emoji_name:`
- No heading syntax — use bold + emoji for section headers

## Example Output

```
*Iris Update — March 12–13*
6 PRs merged. Follow-up queries fixed, fast_orchestrator fully removed, and Slack deep links working.

:wrench: *Developer Tooling*

• *Asana-first task management* (<https://github.com/classdojo/iris/pull/128|#128>) — Replaced td as source of truth with new iris-tasks CLI. 8 commands write to Asana first and mirror to td.

:brain: *Query Intelligence*

• *Follow-up queries fixed* (<https://github.com/classdojo/iris/pull/130|#130>) — Prior SQL now included in conversation history so Claude sees real table names. New table-error retry path with discovery permission.
```
