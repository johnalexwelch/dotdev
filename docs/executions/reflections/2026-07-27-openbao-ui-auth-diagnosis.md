# Session Reflection: OpenBao UI Auth Diagnosis
**Date**: 2026-07-27
**Goal**: Reflect on the OpenBao UI authentication failure handling and preserve skill improvements.

## What Went Well
- Kept the diagnosis non-secret: checked UI reachability, health, and userpass login results without printing passwords or tokens.
- Used the screenshot as authoritative UI evidence: it showed `Userpass`, username `openbao-admin`, and mount path `operators`, so the problem was not field selection.
- Separated runtime state from repo state: the repo documented the intended `operators` mount, while the live API response showed authentication still failed.

## What Went Wrong / Friction
- I initially over-indexed on the UI form and password possibility before proving all three role-account logins failed through the API.
- The live-check command had avoidable shell friction: using `path` as a zsh loop variable broke executable lookup and produced `command not found: curl`.
- Parsing the UI mount response took multiple tries due stdin/f-string command mistakes. The check was read-only, but the tool sequence was clumsy.
- The root-cause fork stayed unresolved: repeated `403 permission denied` could be bad password/auth state, lockout, or mount/user drift. The next diagnostic should make that fork explicit earlier.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Screenshot showed the UI settings were already correct despite authentication failure. | I treated browser form settings as still suspect after API evidence already pointed at live auth state. | Proposed `openbao-operator-auth-diagnose` skill |
| 2 | User had previously supplied 1Password refs and expected secret-safe automation. | Diagnosis needed a project-specific auth flow, not generic "try the password again" advice. | `prompt-builder` / proposed OpenBao auth skill |

## Lessons
1. **Correct form plus API failure means live auth state**: Once UI settings match the documented userpass mount, move to API/login state, lockout, and account reset paths.
2. **Secret-safe auth checks need a standard ladder**: Health -> UI route -> documented mount -> non-printing 1Password login probes -> lockout/stale-password/reset recommendation.
3. **Avoid `path` in zsh snippets**: In zsh, assigning `path` mutates the command search path. Use names like `endpoint`.
4. **HITL secret work needs operational preflight**: Before issue #29 secret migration, verify operator login works or fix it. Otherwise the migration session starts blocked.

## Proposed Improvements
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/prompt-builder/SKILL.md` — for OpenBao/HITL secret-migration prompts, add a preflight bullet: verify `BAO_ADDR`, UI/health, and non-root operator login using secret handles before implementation; if login fails, halt for auth repair. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-build-one/SKILL.md` — add a narrow reminder for secret-runtime issues: prove operator auth before planning value movement, and record failure as a blocker rather than trying migration steps. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/openbao-operator-auth-diagnose/SKILL.md` — create a small project-specific diagnostic skill for OpenBao UI/userpass failures. (priority: high)

## Skill Extraction Candidates
- **Proposed skill**: `openbao-operator-auth-diagnose` · **target**: `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/openbao-operator-auth-diagnose/SKILL.md` · **invocation**: user/model
  - **Trigger / leading word**: "OpenBao login failed", "Vault auth failed", "permission denied in OpenBao UI", issue #29 auth preflight.
  - **Inputs**: repo root, OpenBao URL, expected userpass mount/usernames, optional 1Password refs as handles only.
  - **Steps**:
    1. Check `/ui/` and `/v1/sys/health`; completion is reachable UI and initialized/unsealed status.
    2. Read repo-owned auth docs for expected mount/usernames; completion is method, mount path, and role accounts identified.
    3. Probe userpass login via API using secret handles without printing passwords or tokens; completion is PASS/FAIL per role only.
    4. If failures are repeated, branch explicitly: lockout wait vs stale password/auth drift vs reset/reapply needed.
    5. Produce exact UI fields and the next safe repair command shape, without secret values.
  - **Success criteria**: user knows whether the problem is UI form, sealed/unreachable vault, lockout, stale password, or live auth drift.
  - **Constraints / pitfalls**: never print token/password material; avoid zsh variable `path`; do not use root token for routine login; reset requires approved admin/root-capable token.
  - **Verification evidence**: this session proved UI `200`, health initialized/unsealed, screenshot fields correct, and all three 1Password-backed role logins failed with `403 permission denied`.
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: whether to encode 1Password item names directly or keep them as parameters.
