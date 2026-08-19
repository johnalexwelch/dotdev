# FIND-09 remediation record — leaked ollama SSH key (2026-08-18)

**Status: remediated / closed.** Key confirmed dead; local repo cleaned; clonable public history verified free of the private key. Residual GitHub-network persistence documented below (Alex decides on the Support ticket).

Finding: a real OpenSSH private key at `dotfiles/config/ollama/id_ed25519`, committed `449613f` (2025-01-07), in the public repo `johnalexwelch/dotdev`. Re-reported by the 2026-07-28 skill-suite audit; first recorded in the 2026-07-09 setup audit and partially remediated the same day (see `docs/decision-log.md` DL-0018 and the 2026-07-09 dated entry it corrects).

No private-key material appears in this document, the remediation session transcript, or any surviving file. The only key artifacts recorded are the fingerprint and public half, which are not secrets.

## Key identity

- Type: ED25519, **unencrypted** (no passphrase — a copied key is directly usable)
- Fingerprint: `SHA256:yR4RAyuDooI1lZMBPaQ9JXgHl77lJcLfb43CpntgKcE`
- Public half: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJX4gkPbgthWy6l50vJfwuxaC7X8CKxYLcw7VaNSTZN` (no comment)
- Committed `449613f47f994fca999ed8f3d659c41a17bc4b24` (2025-01-07, alongside its `.pub` and an ollama `config.yaml` pointing only at `127.0.0.1:11434`), removed same day by `3d0a7785283fe34a46a8af530f8154632b72e565` ("remove exposed SSH keys") — a plain `git rm`, no rewrite at that time.

## Rotation decision (operator gate 1 — Alex, 2026-08-18): key is dead, no rotation needed

Everywhere the public half was checked for, it was absent:

| Location | Result |
|----------|--------|
| All current keypairs in `~/.ssh` on the primary Mac (4 keypairs) | different fingerprints |
| Primary Mac `~/.ssh/authorized_keys` | not present |
| GitHub account SSH keys (3 registered) | not present |
| pergamon (192.168.4.39) `authorized_keys` — checked read-only over SSH | not present |
| synology (192.168.4.43) | unreachable from session (SSH timeout); Alex confirmed checked/dead at gate 1 |
| Any committed `authorized_keys`, install script, or deploy reference in **any revision** of repo history | none exist |

The key appears to have been generated for an ollama experiment and never installed anywhere durable. Alex confirmed at the first operator gate that the key is dead; rotation was therefore unnecessary. It is still treated as compromised for exposure-analysis purposes (the blob was public for ~18 months).

## History topology (why this wasn't a filter-repo job in 2026-08)

The 2026-07-09 remediation (decision-log dated entry, 2026-07-09) already ran `git filter-repo` and force-pushed: main's ancestry carries rewritten twin commits (`b981ff9b439cc876ddd673e55d610627c3163fd9` / `05711e007301d8cf05827694a64b1a0297024754`) that contain **only the `.pub`** — the private key was never in the rewritten line. Verified 2026-08-18 by fresh clone from GitHub:

- private blob `3fef018335d31dc1cbd1323900f495925704ce0e` → **absent** from all clonable refs
- commit `449613f…` → **absent**
- `.pub` blob `bba4df426b65daff733c8767c336fd767cfd0f18` → present (by design per the 2026-07-09 decision; a public key is not a secret)

What the 2026-07-09 pass left behind — the actual FIND-09 leftovers:

1. **Local tag resurrection.** The primary checkout's local `v0.1.0` tag pointed at `8c4572662cad9078a2949b4467f27affdab9c013` (pre-rewrite line), diverged from origin's clean `v0.1.0` (`e249f0e14753a03c3dfa6e0177f1f3126fbc56f3`). This kept `449613f` and the private blob alive in the local object store — and is why the 2026-07-20 repo audit's `git show 449613f:…` evidence kept succeeding locally, leading it to conclude (incorrectly) that "no history rewrite" had happened.
2. **GitHub server-side persistence.** Twenty-two PR head refs still reach `449613f` on the server: `refs/pull/{3,4,5,6,7,8,9,10,11,12,13,14,15,41,54,58,59,60,61,62,64,67}/head`. Anyone can `git fetch origin refs/pull/N/head` from the public repo and receive the private key — no SHA guessing needed. The blob is also directly fetchable by SHA via the API (verified 2026-08-18). Users cannot delete `refs/pull/*`; **only GitHub Support can remove PR refs, dereferenced objects, and cached diff views.**
3. **Fork network.** `lane-foxly/dotdev` (forked 2026-07-17, after the rewrite — its own refs are clean) shares GitHub's object network with the parent, so the dangling objects resolve through it too. A network-wide purge is a GitHub Support operation; fork deletion by its owner would simplify GC.

## Actions taken 2026-08-18

1. Verified the finding (mode-600 scratch copy, fingerprinted, then overwritten and deleted; overwrite is best-effort on APFS/SSD).
2. Blast-radius enumeration per the table above; operator gate 1 confirmed key dead → no rotation.
3. Local cleanup (operator gate 2, approved): re-pointed local `v0.1.0` to origin's `e249f0e14753…`. **Rollback record:** previous local tag target was `8c4572662cad9078a2949b4467f27affdab9c013`. After this, zero local refs reach the tainted commits (`git for-each-ref --contains` = empty).
4. `git reflog expire --expire=now --all && git gc --prune=now` was handed to Alex to run in `~/dotdev` (blocked for the agent by the permission classifier; destructive-git). Until run, the tainted objects sit unreachable-but-present in the local object store only.
5. **No filter-repo / BFG re-run and no force-push** — deliberately. The clonable remote history is already clean (fresh-clone proof above); a rewrite would only remove the non-secret `.pub` at the cost of changing every branch SHA, invalidating 5 open PRs, re-cutting ~24 worktrees, and dangling all D-006 ledger `head_sha` references. Decision: skip (DL-0018). Because no branch history was rewritten, **ledger snapshots' recorded head_shas remain valid** — the anticipated dangling-reference caveat is moot.

## Residual exposure and the GitHub Support decision (Alex's call)

Cached views, PR diffs, the 22 PR refs, and dereferenced network objects will continue to serve the blob until GitHub acts. **Contacting GitHub Support (or the "remove sensitive data" process, support.github.com) is the only way to fully purge these.** Since the key is confirmed dead, this is hygiene, not containment. Draft request text:

> Subject: Remove sensitive data from repository network — johnalexwelch/dotdev
>
> A private SSH key was committed to the public repository johnalexwelch/dotdev and has been removed from all branch/tag history via git filter-repo (force-pushed 2026-07-09). The key has been verified unused and treated as compromised. Please (1) remove the pull-request refs still reaching the pre-rewrite commits — refs/pull/{3,4,5,6,7,8,9,10,11,12,13,14,15,41,54,58,59,60,61,62,64,67}/head; (2) run garbage collection to drop the now-unreachable objects, specifically commit 449613f47f994fca999ed8f3d659c41a17bc4b24 and blob 3fef018335d31dc1cbd1323900f495925704ce0e (path dotfiles/config/ollama/id_ed25519); (3) purge cached commit/diff views referencing them; and (4) apply this across the repository network, including the fork lane-foxly/dotdev.

## Post-remediation secret-scan baseline

`gitleaks 8.30.1`, full history (`gitleaks git --redact`), fresh clone from GitHub, 2026-08-18: **12 findings, all benign, zero real secrets**:

- 2 × intentional fake-secret fixtures in `dotfiles/.pi/agent/extensions/scrub-secrets/impact.test.ts` (the scrub-secrets extension's own tests)
- 10 × `private-key` rule matches on the literal `-----BEGIN OPENSSH PRIVATE KEY-----` string **quoted as audit evidence** in `docs/audits/2026-07-20-repo-audit.md` (5 historical commits × 2 lines) — no key material, just the header string

The local primary checkout scans identically post-cleanup. The known-benign header-string quotes are covered in this same delivery: a `private-key`-rule-scoped allowlist for `docs/audits/*.md` in `.gitleaks.toml` (which CI's secret-scan job uses) and refreshed `.secrets.baseline` entries. The two scrub-secrets test fixtures live only in historical commits and are not re-scanned by CI's range-based scan.
