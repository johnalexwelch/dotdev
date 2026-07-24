# 14 — Code Rot

Question:

```markdown
What rot exists that automated analyzers can prove? Run `lens_diagnostics` with `mode=full` and `refreshRunners=all` and report its findings verbatim as facts:

- **Dead code / unused exports / unreferenced files & deps** (knip, dead-code)
- **Copy-paste duplication** (jscpd) — cite the duplicated ranges and clone size
- **Circular dependencies** (madge) — cite the cycles
- **Known CVEs** (govulncheck / trivy) and **leaked secrets** (gitleaks)

Report counts, file:line locations, and the analyzer that produced each finding. Do NOT judge severity or propose fixes — that's the synthesizer's job. If an analyzer did not run or produced no output, say so explicitly (absence of evidence is itself a fact). Fall back to `git grep` for obviously-unreferenced exports only if `lens_diagnostics` is unavailable, and flag the degraded confidence.
```
