# OpenWiki — our setup

OpenWiki is an LLM agent that generates and maintains a repo's `openwiki/`
docs tree (architecture, workflows, ops, integrations) plus two tiny pointer
stubs at the repo root: `AGENTS.md` and `CLAUDE.md`. Don't hand-edit anything
under `openwiki/` or those two stubs — they get regenerated. Edit source
docs/code instead and let the next `--update` pick it up.

## Commands

| Command | Use |
| --- | --- |
| `openwiki code --init --print` | first-time generation for the current repo |
| `openwiki code --update --print` | regenerate from current repo state |
| `openwiki` | interactive chat mode (needs a TTY) |
| `openwiki cron list` | connector schedules — **personal mode only**, not code-mode repo docs |

No `openwiki config` subcommand and no per-repo config file exists (checked
`dist/*.js` — there's no `.openwikiignore`/exclude mechanism either). The
only knobs are env vars (`OPENWIKI_PROVIDER`, `OPENWIKI_MODEL_ID`,
`ANTHROPIC_API_KEY`/provider key) and CLI flags (`--modelId`, `--mode
personal|code`). Credentials/model prefs persist in `~/.openwiki/` (outside
any repo, never git-tracked).

## Important: it can revert hand-edits in its scope

`--update` is a fresh agent pass, not a template diff. It treats
`.github/workflows/openwiki-update.yml` as part of its own managed output
(it's literally in `create-pull-request`'s `add-paths`) — running
`--update` once **reverted our hand-hardened workflow** (re-enabled the
disabled cron, un-pinned the actions, dropped `persist-credentials: false`)
back to its default scaffold, with no exclude flag to stop it.

Ceiling: there's no durable way to tell OpenWiki "never touch this file
again" short of passing a steering message on every single invocation
(`openwiki code --update --print "keep the CI cron disabled and actions
pinned"`) or deleting the file so there's nothing to revert.

**The scheduled path is already immune** — `openwiki-scheduled.sh` only ever
stages `openwiki/ AGENTS.md CLAUDE.md` before committing, and additionally
runs `git checkout -- .github/workflows/openwiki-update.yml` right after
the openwiki call to hard-restore it inside the throwaway worktree, which
then gets deleted regardless. A stray revert can never reach the PR.

**Manual/interactive runs on the live checkout still need discipline** —
if you ever run `openwiki code --update` (or the interactive `openwiki`
chat) directly in this repo, re-check `git diff
.github/workflows/openwiki-update.yml` before committing and `git
checkout -- <path>` if it regressed. Cheaper than fighting the tool for an
action this infrequent. Also re-check that `AGENTS.md`/`CLAUDE.md` still
point at `docs/agents/habits.md` — the scheduled job restores that pointer
automatically; a manual live-checkout run does not.

## Agent Habits (durable, not OpenWiki-owned)

Hand-tuned agent policy lives in `docs/agents/habits.md` (repo-local; not
under `openwiki/`). `AGENTS.md` and `CLAUDE.md` only carry a short pointer
to that file. The nightly `openwiki-scheduled.sh` re-appends
`habits-pointer.md` after `--update` if OpenWiki wiped the stubs — so a
refresh cannot silently drop the link. Edit habits in `docs/agents/habits.md`;
never put the full list back into the stubs.

## Our recurrence: local launchd, not GitHub Actions

OpenWiki's own docs assume CI-based recurrence (`openwiki code` help text:
"...using GitHub Actions for recurrence"), and `--init` scaffolds
`.github/workflows/openwiki-update.yml` for exactly that. We disabled its
`schedule:` trigger (kept `workflow_dispatch` for manual runs) because it
needs `OPENROUTER_API_KEY`/`LANGSMITH_API_KEY` repo secrets we haven't set
up — re-enable it only after adding those.

Instead, `dotfiles/.config/openwiki/openwiki-scheduled.sh` (driven by
`com.alexwelch.openwiki.plist` via launchd, nightly at 3am, missed runs
fire on wake) runs `openwiki code --update` per repo listed in
`repos.conf`, in a throwaway git worktree, and pushes an `openwiki/update`
branch + opens a PR (best-effort, GitHub only) — never touches your live
checkout. Requires `~/.openwiki/.env` (chmod 600, outside any repo) holding
`ANTHROPIC_API_KEY`, since launchd doesn't inherit shell env/PATH.

Check status: `launchctl list | grep openwiki`. Trigger now:
`launchctl start com.alexwelch.openwiki`. Logs: `/tmp/openwiki-scheduled.log`.
Add a repo: append its path to `repos.conf`.
