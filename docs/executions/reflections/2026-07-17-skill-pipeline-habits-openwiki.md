# Session Reflection: Skill pipeline design, backlog harvest, durable habits
**Date**: 2026-07-17
**Goal**: Evaluate skill-authoring options, build a suggestion→harvest→implement pipeline, land durable Agent Habits that survive OpenWiki regen, commit/push.

## What Went Well
- Evaluated overlapping authoring skills MECE-style before building; split producer (`session-insight`+skillify) from consumer (`skill-backlog` → `workflow-skill`) instead of one mega-skill.
- First `skill-backlog` run included a ruthless process critique — ground-truth probe caught 10/18 ghost proposals; folded that critique back into the skill same session.
- OpenWiki/habits decision landed cleanly: durable file + stub pointer + scheduled restore (same pattern as workflow-file restore).
- Scoped commit: only workstream files; left unrelated dirty tree alone.

## What Went Wrong / Friction
- Early ranking by owning-skill frequency was a lie until filesystem ground-truth — almost shipped a backlog of already-fixed items.
- Shell carried iris worktree `GIT_*` env (`GIT_DIR`, Iris Developer author) — broke `git status` and almost committed as the wrong author; had to unset + amend before push.
- Claude runtime activation still broken (`~/.claude/skills` → missing target); only Codex sync worked — reported but not fixed.
- Attached Codex copy of `session-insight` in this invocation still says "edit CLAUDE.md" in Human gates / Step 5 while canonical source prefers `docs/agents/habits.md` — mirror lag / stale attachment.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Challenged skipping rationalization/bulletproofing/evals as "not valuable" | Framed placement as rejection; under-sold micro-testing | (conversation) → later folded into write-a-skill / skill-evaluator |
| 2 | Reframed need: backlog of suggestions for a separate agent job, not session-bound skillify alone | I kept proposing session extraction as the main product | skill-backlog (built) |
| 3 | Chose two-skill seam (skill-backlog plans → workflow-skill implements) over one orchestrator | Needed confirmation; matched existing feature→build-one pattern | workflow-skill / skill-backlog |
| 4 | "do all of the above" including process fixes | Stopped at approval gate correctly | — |
| 5 | OpenWiki should own stubs but habits must be improvable / pointer must survive refresh | Almost left habits only in CLAUDE.md (regen-vulnerable) | docs/agents/habits.md + openwiki-scheduled.sh |
| 6 | commit and merge | — | — |

## Lessons
1. **Ground-truth before frequency.** Cross-session occurrence counts are worthless until you verify proposals aren't already landed. Bake the probe into harvest, don't treat it as optional rigor.
2. **Cluster by failure mode, not owner.** Popular skills accumulate unrelated checkboxes; owner-frequency over-counts.
3. **OpenWiki owns pointers, not policy.** Durable agent policy must live outside regenerated stubs; restore pointers in the scheduled job the same way we restore the workflow file.
4. **Polluted GIT_* is a session hazard.** Foreign worktree env masquerades as "repo is broken"; unset before any git write, and check author before push.
5. **Better way:** ruthlessly evaluating the process *during* the first backlog run (and folding fixes immediately) beat designing the skill perfectly up front.

## Proposed Improvements
- [ ] `docs/agents/habits.md` — add habit: before any git write in a session, `unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR` and verify `git rev-parse --show-toplevel` is the intended repo; check `git log -1 --format='%an <%ae>'` before push if the shell may have inherited foreign author env. (priority: **high** — evidence: this session nearly committed as Iris Developer / couldn't status until unset)
- [ ] `workflow-skill/SKILL.md` Step 4 — make Claude-runtime breakage a hard report with a one-line fix hint (expected symlink target: `dotfiles/.config/agents/skills`), not just "report it". (priority: **med** — evidence: sync succeeded for Codex, Claude still broken at end of session)
- [ ] `session-insight/SKILL.md` — Human gates + Step 5 still name `CLAUDE.md` as the edit target in the Codex-mirrored copy used this turn; confirm canonical source is habits-first and re-run `sync-codex-skills.sh --apply` after next edit so attachments don't lag. (priority: **med** — evidence: attached skill text vs canonical)
- [ ] `skill-backlog/SKILL.md` — optional: after Step 5 dispatch, append a one-line `_Note: implemented <date> via skill-backlog` to source reflection items (or accept ground-truth-only and document that reflections stay historical). Pick one so harvest doesn't rely on tribal knowledge. (priority: **low** — evidence: we chose ground-truth-only this run; still ambiguous in producer)

## Skill Extraction Candidates
<!-- omitted: the pipeline skills were authored and shipped this session; no additional net-new skill cleared the gate beyond what already landed -->
