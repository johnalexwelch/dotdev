# Session Reflection: MLflow Pilot Vertical Slice

**Date**: 2026-08-18
**Goal**: Complete AE-232 MLflow pilot with real Redshift training + promotion

## What Went Well

- **Systematic permission debugging**: traced MLflow auth failures through SSO → IAM → sagemaker-mlflow actions, identified exact missing permissions
- **Local fallback strategy**: when GHA runners failed, pivoted to local verification quickly
- **Real data integration**: production feature query adapted successfully (dropped inaccessible table, maintained AUC)
- **Presigned URL pattern**: correctly used `aws sagemaker create-presigned-mlflow-tracking-server-url` for UI access

## What Went Wrong / Friction

- **Auth token redaction**: first presigned URL attempt failed because echoing the token to output triggered redaction, which was then passed to `open`
- **Runner investigation sprawl**: tried ml-models runner → astronomer runner → ubuntu-latest; should have started with ubuntu-latest as baseline
- **OIDC debugging incomplete**: identified `sts:AssumeRoleWithWebIdentity` failure but didn't fix the trust policy (deferred)
- **Proactive UI offer missing**: user had to ask twice to see the MLflow UI; should have offered after first successful model registration

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|------------------------|------------|-------------------|
| 1 | "can i see the working example" | Didn't demo after verification | workflow-finalize (demo gate) |
| 2 | "Invalid AuthToken" | Echoed token → redaction → broken URL | (new pattern needed) |
| 3 | "can i see the UI" (again) | Same redaction issue on retry | (same) |

## Lessons

1. **Never echo sensitive URLs to output**: presigned URLs, auth tokens, and similar secrets get redacted when printed. Capture directly into variables and pass to commands without intermediate echo. Pattern: `URL=$(...) && open "$URL"` in a single command.

2. **Baseline runners first**: when debugging GHA, always verify ubuntu-latest works before investigating self-hosted runners. Self-hosted can fail silently (scale-set issues, networking), and a working ubuntu-latest baseline separates "my workflow is broken" from "infrastructure is broken."

3. **Proactive demo after verification**: when local verification succeeds for a user-facing system (UI, API, dashboard), immediately offer to show it. Don't wait for the user to ask.

## Proposed Improvements

- [ ] `workflow-finalize` — add optional "demo gate" step: after local verification of user-facing system, offer to show it (priority: low)
- [ ] `docs/agents/habits.md` — add "sensitive URL handling" pattern: never echo presigned URLs; use `VAR=$(...) && open "$VAR"` (priority: med)
- [ ] (new) — GHA debugging checklist: always test ubuntu-latest first before self-hosted (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `mlflow-ui-access` · **target**: `~/.claude/skills/mlflow-ui-access/SKILL.md` · **invocation**: user
  - **Trigger / leading word**: "mlflow ui", "see the model", "open mlflow"
  - **Inputs**: tracking server name (default: `delphi-mlflow`), region (default: `us-east-1`)
  - **Steps**:
    1. Generate presigned URL: `aws sagemaker create-presigned-mlflow-tracking-server-url --tracking-server-name <name> --region <region> --query 'AuthorizedUrl' --output text`
    2. Open directly without echoing: `URL=$(...) && open "$URL"`
  - **Success criteria**: browser opens MLflow UI without "Invalid AuthToken" error
  - **Constraints / pitfalls**: URL must not be echoed to output (redaction); URL expires in 5 minutes
  - **Verification evidence**: second attempt (direct capture + open) worked after first (echo) failed
  - **Quality gate**: googleable=No (SageMaker-specific + redaction gotcha) · specific=Yes (delphi infra) · real-effort=Yes (debugging took 2 attempts)
  - **Open questions**: should this also handle IAM auth errors with a helpful message?
