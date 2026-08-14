# Session Reflection: Warren Pivot Decision Point

**Date**: 2026-08-10
**Goal**: Work through Warren follow-up backlog, ended at architecture pivot decision

## What Went Well

- **Playwright for browser debugging**: Instead of asking user to check DevTools, used Playwright to actually inspect DOM classes and take screenshots — got concrete evidence without user effort
- **Ponytail audit**: Identified and removed ~96 lines of dead code including an unsafe barrel file
- **Security fix**: Quickly identified that `restoreBackup` was dead code with no callers, deleted rather than patched
- **Handoff was clean**: Captured the pivot decision point clearly with schema sketch

## What Went Wrong / Friction

- **Chased symptoms instead of questioning paradigm**: Spent significant time fixing bold rendering, wiki-link nesting, code-fence detection — all symptoms of fighting markdown as a UI paradigm. The user's actual need (campaign worldbuilding) was obscured by the Obsidian-compatibility assumption.
- **Asked user to debug when I could have**: Initially asked user to check DevTools for cm-md-bold class; user correctly redirected me to do the research myself.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "do the research instead of asking me to debug it" | Defaulted to user verification when automated check was possible | General agent behavior — prefer automated verification |
| 2 | "what if we don't need obsidian? it's just what I was using" | Accepted the markdown-file paradigm as a constraint without questioning | No owning skill — see Gap below |

## Lessons

1. **Question inherited constraints early**: The Obsidian/markdown assumption was never validated — it was inherited from "what the user happened to be using." A 5-minute conversation at project start could have saved weeks of CodeMirror work.

2. **Symptoms cluster around paradigm mismatch**: When multiple UI fixes feel like fighting the framework (decoration nesting, code-fence detection, bold in monospace, etc.), step back and ask if the paradigm itself is wrong.

3. **Automate verification when possible**: Playwright/headless browser checks are faster and more reliable than asking the user to inspect DevTools. Do the work.

## Proposed Improvements

- [ ] `docs/agents/habits.md` — Add: "Before accepting a tool/format/paradigm as a constraint, verify it's a real requirement, not just 'what the user happened to be using'" (priority: high)
- [ ] `workflow-feature` or `execute-prd` — Add checkpoint: "Does the proposed solution serve the user's actual goal, or just their stated approach?" (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `pivot-assessment` · **target**: `~/.claude/skills/pivot-assessment/SKILL.md` · **invocation**: model (when friction accumulates) or user ("should we redesign this?")
  - **Trigger / leading word**: "should we scrap", "is this the right approach", accumulated friction with current paradigm
  - **Inputs**: Current architecture, friction points, user's underlying goal (not their stated approach)
  - **Steps**:
    1. Identify the inherited constraint/paradigm being questioned
    2. Verify: is this constraint a real requirement or just "what we had"?
    3. If not required: sketch what the alternative would look like
    4. Inventory: what to keep, what to gut, what to add
    5. Estimate effort: pivot vs. fresh start vs. continue
    6. Present tradeoffs, let user decide
  - **Success criteria**: User makes an informed decision with clear effort estimates
  - **Constraints / pitfalls**: Don't propose pivot for every friction — only when symptoms cluster around a paradigm mismatch
  - **Verification evidence**: Warren session — markdown editor friction → "do we need Obsidian?" → structured entities proposal with 2-3 week estimate
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: When is friction "enough" to trigger this? How to distinguish paradigm mismatch from implementation bugs?
