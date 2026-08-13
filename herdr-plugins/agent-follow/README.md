# agent-follow

Neovim follows along as a pi agent edits files in the same herdr workspace.

This is the mirror of [`herdr-context.nvim`](https://github.com/makyinmars/herdr-context.nvim):
that sends context from Neovim to an agent, this sends edits from an agent back
to Neovim.

## What it does

When pi finishes an `edit` or `write`, Neovim opens that file and puts the
cursor on the first changed line — unless you are mid-keystroke, in which case
it stays out of your way.

If a [`hunk`](https://hunk.dev) review session is open on the same repo, it is
moved too, so the review viewer and the editor both land on the change as it
happens. Both targets are optional and independent — whichever is running gets
moved, and neither can block or fail the agent's turn.

Review itself is deliberately **not** implemented here. `hunk diff --watch` is
the better review surface (multi-file, built for agent-authored changesets,
refreshes on filesystem events, and carries inline comments an agent can read
back with `hunk session comment list --type user`). For accept/reject,
`gitsigns.nvim` gives you per-hunk `stage_hunk`/`reset_hunk` against the index.

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
                                          ┌─► nvim --remote-expr
                                          │        │
pi tool_result ──► toFollowEvent ──► {path,│line}  ▼
   (edit/write)      (src/normalize.ts)    │  policy.decide(event, editor_state)
                                          │        │
                                          │   jump │ move_cursor │ skip
                                          │
                                          └─► hunk session navigate
                                                   (src/targets/hunk.ts)
```

`toFollowEvent`, `policy.decide` and `hunkCommand` are pure and hold all the
judgement; the socket write, the buffer manipulation and the subprocess are thin
adapters around them.

The two targets want opposite path shapes, which is why resolution lives behind
the seam rather than in either adapter: Neovim needs an **absolute** path (or it
resolves against its own cwd), while `hunk session navigate` rejects absolute
paths outright — `No diff file matches` — and needs one **relative to the repo
root**.

`tool_result.input` carries the model's **raw** tool arguments — pi's edit tool
resolves the path into a local that never reaches the event — so the path can
be relative or `~`-prefixed. `toFollowEvent` resolves it against the agent's
`ctx.cwd`, which is what stops Neovim from resolving it against its own cwd
and opening the wrong file.

Emitters find Neovim through `~/.herdr/nvim-servers/$HERDR_WORKSPACE_ID`, which
Neovim writes on startup and removes on exit. **One Neovim per workspace** — if
two register in the same workspace, the last to start wins.

`hunk` needs no registry: it addresses live sessions by repo path, so the git
worktree root (cached per cwd) is the whole address. When no session is open the
command simply fails and is swallowed.

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
