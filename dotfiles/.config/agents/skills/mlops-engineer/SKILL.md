---
name: mlops-engineer
description: Warehouse-native MLOps — batch ML pipelines, dbt-based metrics, immutable promotion contracts, no MLflow. Use when designing, building, or reviewing ML pipelines, training or scoring DAGs, experiment tracking, drift detection, model promotion/versioning, or training-serving skew in the warehouse stack.
risk: medium
source: custom
date_added: '2026-08-10'
---

## Use this skill when

- Building or modifying ML pipelines, training jobs, or scoring DAGs
- Implementing experiment tracking, metrics collection, or drift detection
- Working on model promotion, versioning, or registry patterns
- Designing reproducibility, rollback, or incident recovery flows

## Do not use this skill when

- Real-time/streaming ML (this stack is batch-oriented)
- Tasks unrelated to ML infrastructure

## Core Architecture Decisions

This skill encodes the Delphi MLOps platform decisions. **Do not recommend alternatives without explicit user request.**

### 1. No MLflow — Warehouse-Native Tracking (ADR-0007)

❌ **Rejected:** MLflow (managed or self-hosted), W&B, Neptune, Comet

✅ **Use instead:**

- **Redshift** as the authoritative metric store (append-only log)
- **SageMaker Registry** for artifact storage only (not deploy authority)
- **SQL/dbt** for experiment comparison (no tracker UI)
- **dbt seeds** for metric registry and thresholds

### 2. Immutable Promotion Contract (ADR-0001)

❌ **Rejected:** mutable tags (`stable`, `latest`), manual Airflow Variable edits, tracker-as-authority

✅ **Use instead:**

- CI mints `<family>-<40-hex-git-sha>` tag on merge
- Image digest IS the identity — artifacts ship inside container
- `promote-<family>` GitHub workflow with environment gate sets Airflow Variable via API
- Missing/invalid identity halts the run — no fallbacks

### 3. Warehouse-Native Quality Surface (ADR-0002)

**Grain:** `model × model_version × run × metric_name × value` + slice columns + `as_of` timestamp

**Metric floor:**

- Scoring runs: `n_scored`, score mean/p10/p50/p90, null/invalid rate
- Training runs: `n_train_rows`, class balance, one eval metric
- Each model registers ONE headline metric in dbt seed registry

**Writers:**

- Jobs push what only they know (n_train, class balance, in-container gates)
- dbt computes warehouse-derivables (score stats, outcome metrics)

### 4. Drift Detection — Warehouse-Native dbt (ADR-0003)

❌ **Rejected:** Evidently library, real-time drift, scoring-path checks

✅ **Use instead:**

- dbt models computing drift statistics off the scoring path
- Iceberg-stored historical baselines
- Alert gates defined in dbt seeds

### 5. Reproducibility Floor (AE-175)

**Provenance bundle (all models):**

- Training query fingerprint (SHA-256 of SQL + bound params)
- Hyperparameter manifest (YAML/JSON committed or S3 JSON + dbt source)
- Immutable artifact digest
- Training code reference (git SHA)
- Environment manifest (Python version + pinned lockfile)

**Critical tier adds:** pinned data snapshot reference (S3 URI + version)

**Universal ban:** `CURRENT_DATE`/runtime date functions, personal/temp schemas in training queries

## Infrastructure Patterns (cloud-ci-automation)

**Before proposing GitHub Actions, environments, or IAM for a new repo:**

1. Review `cloud-ci-automation/repo_config/` for similar repos to match company patterns
2. Check for existing CI runner configs, IAM policies, and deployment namespaces

### ML Model Repos Without K8s Deployment

Follow `classification-models.yaml` pattern:

```yaml
name: <repo>
team: <team>
ciRunners: yes
ciRunnerList:
  - label_suffix:
    docker_sidecar: yes
extraAwsPolicies:
  - # S3 artifacts access
  - # MLflow/SageMaker access (if applicable)
# No deploymentNamespaces — not a K8s service
```

### Approval Gates

Company pattern: **branch protection on main** (PR review required), not GitHub environments.

- Promotion = merge to main (requires review)
- K8s services use namespace-per-branch (staging branch → staging namespace)
- Non-K8s repos (ML models) use main-branch merge as the gate

## Stack Components

| Layer | Tool | Notes |
|-------|------|-------|
| Orchestration | Airflow | DAGs for training, scoring, drift |
| Compute | SageMaker Training/Processing | Batch jobs, not endpoints |
| Artifacts | SageMaker Registry | Storage only, not deploy authority |
| Metrics | Redshift | Append-only metric log |
| Transforms | dbt | Drift, outcome metrics, quality surface |
| Promotion | GitHub Actions | `promote-<family>` workflow + env gate |
| Identity | Container digest | `<family>-<git_sha>` tags |
| Hyperparams | S3 JSON + dbt source | Pinned, not git-committed |

## Patterns

### Training Job Checklist

```python
# 1. Emit provenance bundle
provenance = {
    "training_query_sha256": hash_query(query, params),
    "hyperparams_uri": "s3://bucket/hyperparams/family/v1.json",
    "code_sha": os.environ["GIT_SHA"],
    "env_lockfile": "requirements.lock",
    "run_id": f"{family}-{git_sha}",
}

# 2. Emit tier-0 metrics to Redshift
emit_metric(model=family, version=git_sha, run=run_id,
            metric_name="n_train_rows", value=len(df))
emit_metric(..., metric_name="class_balance", value=pos_rate)
emit_metric(..., metric_name="cv_auc", value=cv_score)

# 3. Register artifact (storage only)
sagemaker_registry.register(
    model_package_group=family,
    model_data=f"s3://.../{family}-{git_sha}/model.tar.gz",
    metadata=provenance,
)
```

### Promotion Flow

```
merge to main
  → CI builds image, tags <family>-<git_sha>
  → CI pushes to ECR, registers in SageMaker Registry
  → Manual: run promote-<family> workflow
  → Workflow validates image exists, digest matches
  → Workflow sets Airflow Variable via API (gated)
  → Next DAG run picks up new version
```

### Rollback

```
1. Run promote-<family> with previous known-good git_sha
2. Airflow Variable updates immediately
3. Next DAG run uses rolled-back version
4. No tracker dependency — 3am rollback works offline
```

## Anti-Patterns (Do Not Recommend)

| ❌ Anti-pattern | Why rejected |
|-----------------|--------------|
| MLflow for tracking | $132/mo overkill, couples rollback to tracker uptime |
| Mutable `stable` tags | Silent staleness, audit failure |
| `model-latest.tar.gz` side-loads | Two pointers that drift apart |
| Tracker-as-deploy-authority | 3am rollback blocked if tracker down |
| Manual Airflow Variable edits | Ungated, unauditable |
| Metrics in score rows | Churn pattern, run facts duplicated |
| `CURRENT_DATE` in training SQL | Reproducibility killer |

## Revisit Triggers

Current decisions may need revisiting if:
>
- >3 DS needing persistent experiment dashboards
- AutoML or continuous retraining adoption
- Compliance demands dedicated audit API
- >10 model families
- Any DS running >5 experiments/week

## References

- [Delphi decision log](~/projects/delphi/docs/decision-log.md)
- ADR-0001: Promotion contract
- ADR-0002: Quality surface
- ADR-0003: Drift tooling
- ADR-0007: Tracking layer (no MLflow)
- AE-175: Reproducibility floor
