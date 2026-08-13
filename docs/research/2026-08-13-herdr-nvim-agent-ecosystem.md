# Research: Agent → Editor Integration in the herdr + Neovim Ecosystem

**Question:** What already exists for following and reviewing an agent's code changes from Neovim, and which ideas should `agent-follow` steal?
**Date:** 2026-08-13
**Confidence:** High (for what exists and how it works); Medium (for maturity/maintenance judgements, which rest on README signals rather than commit metrics)
**Sources consulted:** 14

## Summary

The herdr + Neovim ecosystem is crowded but lopsided. At least seven plugins connect Neovim to herdr, and several handle the **editor → agent** direction well (send selection, send comments, stage context). Almost nothing handles **agent → editor as a push**. Every tool found either makes the human pull (press a key, open a picker, refresh a pane) or polls on a timer. `agent-follow`'s niche — the editor moves the instant the agent writes, driven by a typed agent event — appears genuinely unoccupied.

That is the narrow good news. The wider finding is that the *review* half of the original goal is solved far better elsewhere than by the `gitsigns`-against-the-index approach `agent-follow` assumes. Two mature plugins implement real in-editor diff approval: `claudecode.nvim` (WebSocket MCP, the same protocol as the official VS Code extension) and `agentic.nvim` (ACP, which **explicitly lists Pi as a supported provider**). Both let you see a proposed change and accept or reject it before or after it lands. Neither needs anything built.

The most consequential single finding is a **defect in `agent-follow` itself**, surfaced by comparing against `sidekick.nvim`'s `watch = true` option. `agent-follow`'s `move_cursor` path — taken whenever the agent edits the file you are already viewing, which is the common case — moves the cursor without reloading the buffer. Verified empirically: with `OLD-2` in the buffer and `AGENT-EDITED-LINE-2` on disk, following placed the cursor on line 2 of the stale content. The feature is at its most confidently wrong exactly where it is most likely to be used.

## Key Findings

### Finding 1: Nothing in the ecosystem does push-follow

Seven herdr/Neovim plugins were examined [1][2][6][7][12][13][14]. Every one is pull- or poll-based:

- `herdr-nvim` [1] "mines edits from the agent's session log and adds uncommitted git changes," falling back to "scrapes recent pane output" for untracked agents. The user must press `prefix+o`. It subscribes to no herdr events.
- `herdr-reviewr` [4] polls the worktree, 2 s by default, and refresh is manual (`r` or toggle). Its README concedes that "a turn that starts and finishes inside one poll is missed."
- `herdr-context.nvim` [6], `herd.nvim`, `herdr.nvim`, `herdr-splits.nvim` [2] are editor → agent, or navigation only.

So `agent-follow`'s push mechanism is not duplicated work. But note the ecosystem's revealed preference: multiple independent authors chose pull. That is weak evidence that push may be less wanted than it seems — an unprompted cursor jump is intrusive, which is precisely why `policy.decide` gates on mode and modified state.

### Finding 2: `agent-follow` fails to reload the buffer — verified defect

`sidekick.nvim` ships `watch = true`, documented as "notify Neovim of file changes done by AI CLI tools," and states plainly: "Automatically reloads files in Neovim when they are modified by AI tools" [5].

`agent-follow` does this only by accident. The `jump` branch calls `vim.cmd.edit`, which reloads. The `move_cursor` branch calls only `nvim_win_set_cursor`. Empirically confirmed on this branch: file open in Neovim showing `OLD-2`, disk rewritten to `AGENT-EDITED-LINE-2`, follow event for line 2 → cursor moved to line 2, buffer still showed `OLD-2`.

Neovim's `autoread` does not fix this on its own; it "only reads the file when Vim performs an action," so the established pattern is an explicit `:checktime` on `FocusGained`, `BufEnter`, `CursorHold` [11]. A follow event is a strictly better trigger than any of those, since it is a positive signal that *this specific file* just changed.

Conflict handling matters too: `autoreload.nvim` "detects conflicts when disk changes collide with unsaved buffer edits" [11]. `agent-follow` already skips on `modified`, so it sidesteps the conflict case rather than resolving it — acceptable, and worth stating as deliberate.

### Finding 3: ACP is real, maintained, and already supports pi

`agentic.nvim` supports "Claude, Gemini, Codex, OpenCode, Cursor Agent, Copilot, Auggie, Mistral Vibe, Cline, Goose, Kiro, Pi, and any future ACP-compatible provider" [10]. It offers "Rich diff preview — When editing files, if your provider asks for permission, you can see a diff preview side-by-side or inline," with `]c`/`[c` navigation and numeric accept/reject [10]. CodeCompanion implements ACP protocol version 1, with the caveat that "the terminal family of methods are not implemented" [9]. Zed publishes a Neovim ACP client page [8].

This corrects an earlier claim made during design that no nvim ACP client could be verified. One exists and names pi.

The tradeoff is unchanged, though: ACP makes **Neovim the host of the agent**. No pi TUI, no herdr agent pane, and `herdr-context.nvim` becomes redundant. It is a different product, not a cleaner build of this one.

### Finding 4: claudecode.nvim's discovery and accept/reject idioms are better than ours

`claudecode.nvim` "creates a WebSocket server that Claude Code CLI connects to, implementing the same protocol as the official VS Code extension," writing connection metadata "to a lock file at `~/.claude/ide/[port].lock`" and setting env vars to point the CLI at it [3]. Diffs open as "a native Neovim diff view"; accept is `:w`, reject is `:q` [3].

Two transferable ideas:

1. **Port-keyed lock files** instead of one file per workspace. `agent-follow` keys on `HERDR_WORKSPACE_ID`, which forces "one nvim per workspace, last to start wins." A directory of instance-keyed files removes that limit.
2. **Accept = `:w`, reject = `:q`.** No new keymaps, no new muscle memory. This is the strongest UX idea found anywhere in the survey.

### Finding 5: "last-turn diff" is a better review unit than all-uncommitted

`herdr-reviewr` offers three diff scopes — uncommitted, branch, and **last turn**, "changes made in a worktree since its most recent turn started" [4]. It also drops line-range comments as inline cards and sends them all to the agent in one keystroke [4].

Last-turn is a materially better review unit than `agent-follow`'s implicit "everything uncommitted," which mixes the agent's work with the human's. And `agent-follow` can implement it *better than the source*: `herdr-reviewr` polls at 2 s and admits missing short turns, whereas pi emits `turn_end` as a typed event. The same feature, event-driven, without the missed-turn caveat.

### Finding 6: Redundancy and a concrete keymap collision

`herdr-nvim`'s annotations feature [1] overlaps `herdr-context.nvim` [6], which is already installed. Both bind under `<leader>a`, and both claim **`<leader>ac`** specifically — `herdr-nvim` for comment-line, `herdr-context.nvim` for `compose()`. Installing both without remapping produces a silent conflict where the later spec wins.

## Recommendations

Ranked by value per unit of work:

1. **Fix the reload defect.** Add `:checktime` (or an explicit `edit!`) to the `move_cursor` path. Two lines, closes a silent-wrong-content bug in the most common code path. Blocking for PR #152.
2. **Adopt `agentic.nvim` for review and approval.** It gives pi-backed diff preview with accept/reject today. This is a straight substitute for the deferred "gate-before-write" idea, and better than building it.
3. **Steal accept = `:w` / reject = `:q`** if any diff surface is ever built here. Zero new bindings.
4. **Re-key the registry per instance**, not per workspace, following the `[port].lock` pattern. Removes the one-nvim-per-workspace limit.
5. **Do not build the deferred layout slices.** `herdr-nvim` already does sidebar, per-tab daemons, and a diff-stat file picker; `herdr-splits.nvim` and `herdr.nvim` handle navigation. Adopt rather than build.

Deliberately *not* recommended: adding a `last-turn` diff scope to `agent-follow`. It is a good idea (Finding 5) but it is the review half, which `agentic.nvim` and `herdr-reviewr` already own. Keep `agent-follow` to follow.

## Open Questions

- Does `agentic.nvim` work when pi is already running in a herdr pane, or does it insist on spawning its own pi? This decides whether it composes with the current setup or replaces it. Needs hands-on trial, not more reading.
- Star counts, commit recency, and license for `agentic.nvim` and `herdr-reviewr` were not retrievable from raw READMEs; maturity above is inferred from documentation quality. Verify before depending on either.
- Does `herdr-nvim`'s session-log mining generalise to claude-code and codex without per-agent work? If so it beats writing an emitter per agent — but it is a weaker signal than a typed event (no `firstChangedLine`).
- Whether push-follow is actually wanted day-to-day, given that every other author chose pull. Answerable only by using it.

## Sources

[1] https://github.com/ChmaraX/herdr-nvim — herdr-nvim, README fetched 2026-08-13, High
[2] https://github.com/yigitkonur/awesome-herdr — awesome-herdr ecosystem index, High
[3] https://github.com/coder/claudecode.nvim — claudecode.nvim, High
[4] https://github.com/persiyanov/herdr-reviewr — herdr-reviewr, High
[5] https://github.com/folke/sidekick.nvim — sidekick.nvim, High
[6] https://github.com/makyinmars/herdr-context.nvim — herdr-context.nvim (installed locally), High
[7] https://github.com/ctbaum/herdr-agents.nvim — herdr-agents.nvim, Medium
[8] https://zed.dev/acp/editor/neovim — Zed, Neovim ACP client, High
[9] https://codecompanion.olimorris.dev/agent-client-protocol — CodeCompanion ACP support, High
[10] https://github.com/carlos-algms/agentic.nvim — agentic.nvim, High
[11] https://neovim.discourse.group/t/a-lua-based-auto-refresh-buffers-when-they-change-on-disk-function/2482 and https://github.com/ccntrq/autoreload.nvim — Neovim external-change reload patterns, Medium
[12] https://github.com/UN-9BOT/sidekick_herdr — herdr backend for sidekick.nvim, Medium
[13] https://github.com/smarzban/herdr-file-viewer — read-only diff/file TUI in a herdr split, Medium
[14] https://github.com/edmundmiller/herdr-plugin-hunk — Hunk diff viewer launcher, Medium

## Research Log

- Started from the user-supplied `ChmaraX/herdr-nvim` and verified its pull-based nature with a second targeted fetch, quoting the README rather than trusting a summary.
- Used `awesome-herdr` as the ecosystem index — this is what a prior-art check should have started from and did not.
- Fetched `claudecode.nvim`, `herdr-reviewr`, `sidekick.nvim`, `agentic.nvim` READMEs directly (raw.githubusercontent) to avoid summary drift.
- Two web searches for ACP/Neovim status and for Neovim external-file-reload practice.
- Reproduced the reload defect locally with headless Neovim before recording it, rather than inferring it from reading `init.lua`.
- Discarded: `herdr-file-viewer`, `herdr-plugin-hunk`, `herdr-worktree-lifecycle`, `herdr-event-hook`, `herdr-flist` — real but orthogonal (read-only viewers, worktree lifecycle hooks, cwd-synced sidebars). Noted in sources for completeness, not analysed.
- Not retrieved: commit metrics and licenses, which raw READMEs do not carry. Flagged as an open question rather than guessed.
