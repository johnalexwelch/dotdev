# Session Reflection: Wayfinder on Linear (Compliance Copilot chart)

**Date**: 2026-07-28
**Goal**: Adapt wayfinder to keep tickets off GitHub, install the Linear MCP, and chart the "Compliance Copilot" map (SQL/dbt/data-model compliance orchestrator).

## What Went Well
- Verified ground truth before acting: confirmed the Linear MCP endpoint via web search before editing config; read the real `mcp.json` schema from imported configs instead of guessing; `stat`'d the astronomer skills dirs and found `.agents/skills` == `.claude/skills` (**same inode 174976314**) — contradicting the compacted memory that claimed two drifting copies. Killed a phantom ticket.
- Held wayfinder discipline: named the destination first, grilled one question at a time, fixed the v1 boundary before fanning out, parked the rest as fog.
- Native Linear blocking (`blockedBy`) + Project-as-map gave a clean frontier without hand-rolling anything.

## What Went Wrong / Friction
- **Over-claimed "must restart pi."** After editing `mcp.json`, the gateway's cached server list didn't show `linear`, so I told the user a restart was required with "no in-session reload path." Next turn, `mcp auth-start` triggered discovery and connected with **no restart**. I trusted the cached list (proxy) over testing the auth path (authoritative).
- **Bash tool mangled multi-line constructs.** `for` loops and heredocs failed twice (`hypa: An error occurred trying to start process 'for'`) — the hypa-wrapped bash flattens newlines. Had to rewrite as single-line `python3 -c`.
- **Wayfinder is GitHub-hardcoded.** Every tracker primitive (map issue, sub-issues, blocking, claim, decision-log mirror) assumes GitHub. Supporting Linear meant improvising the whole adapter (Project=map, `wayfinder:*` labels, `blockedBy` relations, frontier query, claim=assignee) with no guidance. It worked, but nothing in the skill anticipated a non-GitHub tracker.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "issues and tickets should be kept local and out of git" | wayfinder hardcodes GitHub; no tracker-adapter seam | wayfinder |
| 2 | "team doesn't use github issues… leverage Linear?" | same — no multi-tracker guidance, no Linear ops doc | wayfinder |

## Lessons
1. **Test the capability, don't read the cache.** A tool gateway's cached inventory is a proxy; an auth/connect attempt is authoritative. Try the action before asserting a restart is needed.
2. **Wayfinder needs a tracker-adapter contract.** The skill's value (map → children → blocking→frontier → claim → decision index) is tracker-agnostic; only the *bindings* are GitHub. Naming the contract lets Linear/Jira/local slot in without reinvention.
3. **The `write` tool beats the handoff skill's shell dance.** The handoff skill spends paragraphs warning about `mkdir`/`cp` newline-flatten and `~`-non-expansion footguns. Writing the file with the native `write` tool auto-creates parents and is immune to both — I used it for the mirror and hit zero hazards.

## Proposed Improvements
- [ ] `dotfiles/.config/agents/skills/wayfinder/SKILL.md` — add a **"Tracker adapters"** subsection defining the tracker-agnostic contract (shared map, child tickets, blocking→frontier, claim=assignee, comments, decision index) and noting GitHub is the *default* adapter (in `issue-tracker.md`); other trackers need an equivalent ops doc. (priority: high)
- [ ] `dotfiles/.config/agents/skills/wayfinder/SKILL.md` — soften the mandatory `docs/decision-log.md` mirror to "record decisions in the effort's decision store — `decision-log` by default; for out-of-git trackers, the tracker's own comment + map index *is* the record." (priority: med)
- [ ] `dotfiles/.config/agents/skills/handoff/SKILL.md` — lead the storage section with "prefer the `write` tool to create both handoff copies (auto-creates parent dirs, immune to the shell newline-flatten and `~`-expansion bugs)"; keep the `mkdir`/`cp` guidance as a shell-only fallback. (priority: med-high — removes a whole documented footgun class)
- [ ] `docs/agents/habits.md` — add: "In this env the bash tool routes through hypa and mangles multi-line `for` loops / heredocs. Prefer single-line commands or `python3 -c`." (priority: low-med)
- [ ] `docs/agents/habits.md` — add: "Adding an MCP server: after editing `mcp.json`, try `mcp auth-start`/`connect` before claiming a pi restart is required — the gateway re-reads config on an auth attempt." (priority: low)
- [ ] **(different repo — needs approval)** `classdojo/astronomer` `docs/agents/issue-tracker.md` — add a **"Wayfinding operations (Linear)"** section capturing the exact adapter built this session (Project=map, `wayfinder:*` labels, `blockedBy` relations, frontier = project + `assignee:null` + status Backlog/Todo + no open blocked-by, claim=assignee, decisions as comments indexed in the Project description). (priority: med)

## Skill Extraction Candidates
- **Proposed skill**: `install-pi-mcp` · **target**: `dotfiles/.config/agents/skills/install-pi-mcp/` · **invocation**: user ("install the X mcp")
  - **Trigger / leading word**: "install \<vendor\> (pi) mcp"
  - **Inputs**: vendor name; official MCP endpoint (verify via search); `~/.pi/agent/mcp.json`
  - **Steps**: (1) verify the official endpoint URL + transport via web search [checkable: cited source]; (2) read `mcp.json` schema from existing entries [checkable: schema shape known]; (3) add `{type:"http",url,lifecycle:"keep-alive"}` (or command form) [checkable: `python3 -m json.tool` parses]; (4) `mcp auth-start` → hand user the OAuth URL → `auth-complete` with the redirect [checkable: "authentication successful"]; (5) `mcp connect` + a read tool call to confirm live [checkable: real data returned].
  - **Success criteria**: server connected, a live read tool returns workspace data.
  - **Constraints / pitfalls**: no pi restart needed — `auth-start` triggers discovery; remote OAuth servers need no token; never assume `~` expands in the bash tool.
  - **Verification evidence**: this session connected Linear (62 tools) via exactly these steps and listed real teams.
  - **Quality gate**: googleable=No (pi-specific `mcp.json` + auth-start/complete flow + no-restart behavior) · specific=Yes (pi harness) · real-effort=Yes (schema + no-restart discovery)
  - **Open questions**: whether the payoff justifies a full skill vs. a short reference in an existing pi/MCP doc — it's only ~5 steps. Recommend deciding at approval time.

---
*Presented for approval. No skills, habits docs, or issues edited. Canonical edits target `~/dotdev/dotfiles/.config/agents/skills/…`; after any approved edit run `sync-codex-skills.sh --apply`.*
