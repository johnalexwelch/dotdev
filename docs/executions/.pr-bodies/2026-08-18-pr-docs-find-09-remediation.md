## What this PR does

Closes out FIND-09 (the OpenSSH private key leaked into public git history at `449613f:dotfiles/config/ollama/id_ed25519`, re-reported by the 2026-07-28 skill-suite audit) by recording the 2026-08-18 remediation: the key was re-verified and confirmed dead at an operator gate, a fresh clone proved the 2026-07-09 filter-repo rewrite already cleaned all clonable origin history, and the two real leftovers — a stale local `v0.1.0` tag resurrecting the pre-rewrite line, and GitHub server-side persistence (22 `refs/pull/*/head` refs + SHA-fetchable blob) — were respectively fixed and documented with a GitHub Support request draft. Adds the remediation record, decision-log entry DL-0018 (correcting the 2026-07-09 entry), status flips where FIND-09 is tracked, and a tightly-scoped gitleaks allowlist so the record's evidence quotes don't break CI's secret scan.

## User-facing changes

None — documentation and secret-scanner configuration only.

## How I implemented it

- **New record** [docs/audits/2026-08-18-find-09-remediation.md](docs/audits/2026-08-18-find-09-remediation.md): key identity (fingerprint + public half only — no key material anywhere in this PR), blast-radius table, history topology explaining why no new rewrite is needed, actions taken with rollback anchors, residual GitHub exposure + Support-request draft, and the post-remediation gitleaks baseline (12 findings, all benign).
- **DL-0018** appended to [docs/decision-log.md](docs/decision-log.md): corrects the 2026-07-09 "erased" entry (the origin rewrite held; the "still open" signals were a resurrected local tag + GitHub network persistence), records the no-re-rewrite decision and its alternatives, and anchors the two surviving operator actions.
- **Status flips**: FIND-09 row + Top-three note in [docs/audits/2026-07-20-repo-audit.md](docs/audits/2026-07-20-repo-audit.md) (annotate-don't-rewrite: dated update notes, original text preserved), DONE entry in [docs/executions/skill-backlog.md](docs/executions/skill-backlog.md).
- **Scanner config**: `.gitleaks.toml` gains a `private-key`-rule allowlist AND-scoped to backtick-quoted header strings on anchored `docs/audits/*.md` lines only — probe-verified that real key material under that path still flags. `.secrets.baseline` regenerated (line-ref refresh + the new doc's known-benign header-quote entry).

## How to verify

1. `gitleaks git --log-opts="origin/main..HEAD" --redact` → no leaks (evidence quotes allowlisted, nothing real added).
2. Probe the allowlist scoping: drop any real/synthetic private key into `docs/audits/probe.md` → `gitleaks dir docs/audits` flags `private-key`; the two committed audit docs stay clean. (Run during review, 3 independent lanes reproduced.)
3. `detect-secrets-hook --baseline .secrets.baseline <changed files>` → exit 0.
4. `./test/run-tests.sh` → 22 passed / 0 failed (CI manifest commands all green at HEAD).
5. Confirm no private-key material in the diff: the only key artifacts are one SHA256 fingerprint, one `ssh-ed25519` public line, and backtick-quoted header strings.

## Issues

| Issue | Disposition | Rationale |
|-------|-------------|-----------|
| #69 | Refs | Closed 2026-07-09 with the original rotate+erase; this PR corrects and completes its record (leftover local tag + GitHub-side persistence) rather than reopening it |
| #68 | Refs | Setup-overhaul map references FIND-09; no map-scoped work done here |

## Changelog entry

docs(security): close FIND-09 — remediation record, DL-0018, scoped gitleaks allowlist

## References

- FIND-09: 2026-07-28 skill-suite audit re-report; first recorded in the 2026-07-09 setup audit
- DL-0018 (this PR) and the dated 2026-07-09 decision-log entry it corrects
- Operator actions outside this PR (documented in the remediation record): local tag re-point (done), `reflog expire` + `gc` in `~/dotdev` (handed to Alex), optional GitHub Support request (Alex decides)
