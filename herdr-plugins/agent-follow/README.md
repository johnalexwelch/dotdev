# agent-follow

Neovim follows along as a pi agent edits files in the same herdr workspace.

This is the mirror of [`herdr-context.nvim`](https://github.com/makyinmars/herdr-context.nvim):
that sends context from Neovim to an agent, this sends edits from an agent back
to Neovim.

## What it does

When pi finishes an `edit` or `write`, Neovim opens that file and puts the
cursor on the first changed line — unless you are mid-keystroke, in which case
it stays out of your way.

Review is deliberately **not** part of this plugin: the agent writes to the
working tree, so `gitsigns.nvim` already gives you per-hunk
`stage_hunk`/`reset_hunk`/`preview_hunk` against the index.

## Requirements

- Neovim 0.10+, running in a herdr pane (needs `HERDR_WORKSPACE_ID`)
- pi 0.84+
- The pi pane and the Neovim pane must be in the **same git worktree**

## Install

Neovim side (lazy.nvim):

```lua
{
  dir = vim.fn.expand("~/dotdev/herdr-plugins/agent-follow"),
  name = "agent-follow",
  cond = vim.env.HERDR_ENV == "1",
  lazy = false,
  config = function()
    require("agent-follow").setup()
  end,
}
```

pi side — symlink the `src` directory into pi's extensions directory, which pi
auto-discovers by loading `<dir>/index.ts`:

```sh
ln -s ~/dotdev/herdr-plugins/agent-follow/src ~/.pi/agent/extensions/agent-follow
```

Not `pi install`: that route is for `npm:` / `git:` package sources and records
them under `packages` in `settings.json`. Extensions dropped into
`~/.pi/agent/extensions/` are picked up without touching settings — the same way
`scrub-secrets` (also a directory with an `index.ts` and sibling modules) is
loaded.

To try it without installing anything:

```sh
pi -e ~/dotdev/herdr-plugins/agent-follow/src/index.ts
```

## How it fits together

```
pi tool_result ──► toFollowEvent ──► {path, line} ──► nvim --remote-expr
   (edit/write)      (src/normalize.ts)                        │
                                                               ▼
                                              policy.decide(event, editor_state)
                                                               │
                                          jump │ move_cursor │ skip
```

`toFollowEvent` and `policy.decide` are pure and hold all the judgement; the
socket write and the buffer manipulation are thin adapters around them.

`tool_result.input` carries the model's **raw** tool arguments — pi's edit tool
resolves the path into a local that never reaches the event — so the path can
be relative or `~`-prefixed. `toFollowEvent` resolves it against the agent's
`ctx.cwd`, which is what stops Neovim from resolving it against its own cwd
and opening the wrong file.

Emitters find Neovim through `~/.herdr/nvim-servers/$HERDR_WORKSPACE_ID`, which
Neovim writes on startup and removes on exit. **One Neovim per workspace** — if
two register in the same workspace, the last to start wins.

## Test

```sh
make test        # lua + ts
make typecheck
make lint        # stylua
```

## Not built yet

- Gate-before-write. pi's `tool_call` event fires *before* execution and can
  return `{block: true}`, so approve-before-apply is possible on the same seam.
- Auto-focusing the Neovim pane on `pane.agent_status_changed` (herdr plugin).
- Emitters for claude-code (`PostToolUse`) and codex. The wire format and the
  Neovim receiver are already shared; only the emitter is per-agent.
