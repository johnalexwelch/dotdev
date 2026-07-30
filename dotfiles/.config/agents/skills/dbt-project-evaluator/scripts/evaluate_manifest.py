#!/usr/bin/env python3
"""Evaluate dbt_project_evaluator structural rules locally from manifest.json.

Mirrors the rule definitions of dbt-labs/dbt-project-evaluator (see the
skill's references/rule-categories.md) but computes them from the manifest
instead of materializing the package's models in the warehouse — no recursive
warehouse CTEs, no hangs. Rules are computed over the FULL graph (fanout etc.
need global context); findings are then filtered to the scope set.

Usage:
    evaluate_manifest.py MANIFEST_PATH --changed model_a model_b [--full]
    evaluate_manifest.py MANIFEST_PATH --changed-file changed.txt

Outputs JSON: {scope: [...], findings: {category: [...]}, out_of_scope_counts: {...},
not_covered: [...]}.
"""

import argparse
import json
import re
import sys
from collections import defaultdict

STAGING_PREFIXES = ("stg_",)
INTERMEDIATE_PREFIXES = ("int_",)
MART_PREFIXES = ("fct_", "dim_", "mrt_")
MODEL_FANOUT_THRESHOLD = 3  # package default: models_fanout_threshold
CHAINED_VIEWS_THRESHOLD = 4  # package default: chained_views_threshold

HARD_CODED_REF_RE = re.compile(
    r"(?:from|join)\s+(?!\s*[({])(\"?[\w]+\"?\.\"?[\w]+\"?(?:\.\"?[\w]+\"?)?)",
    re.IGNORECASE,
)


def load_manifest(path):
    with open(path) as f:
        return json.load(f)


def model_nodes(manifest):
    return {
        uid: n
        for uid, n in manifest["nodes"].items()
        if n["resource_type"] == "model" and n.get("config", {}).get("enabled", True)
    }


def build_graph(manifest, models):
    sources = manifest.get("sources", {})
    parents = {}  # uid -> set of parent uids (models+sources only)
    for uid, node in models.items():
        deps = set(node.get("depends_on", {}).get("nodes", []))
        parents[uid] = {d for d in deps if d in models or d in sources}
    children = defaultdict(set)
    for uid, ps in parents.items():
        for p in ps:
            children[p].add(uid)
    return sources, parents, children


def tests_by_model(manifest, models):
    out = defaultdict(list)
    for n in manifest["nodes"].values():
        if n["resource_type"] != "test":
            continue
        for dep in n.get("depends_on", {}).get("nodes", []):
            if dep in models:
                out[dep].append(n)
    return out


def name(node):
    return node["name"]


def layer(node):
    n = node["name"]
    if n.startswith(STAGING_PREFIXES):
        return "staging"
    if n.startswith(INTERMEDIATE_PREFIXES):
        return "intermediate"
    if n.startswith(MART_PREFIXES):
        return "marts"
    return "other"


def evaluate(manifest):
    models = model_nodes(manifest)
    sources, parents, children = build_graph(manifest, models)
    tests = tests_by_model(manifest, models)
    findings = defaultdict(list)  # rule -> list of {models: [names], detail}

    def add(rule, involved, detail):
        findings[rule].append({"models": sorted(set(involved)), "detail": detail})

    for uid, node in models.items():
        nm = name(node)
        model_parents = {p for p in parents[uid] if p in models}
        source_parents = {p for p in parents[uid] if p in sources}

        if not (node.get("description") or "").strip():
            add("fct_undocumented_models", [nm], "no description")

        has_pk = any(
            t["name"].startswith(("unique_", "not_null_"))
            or "unique_combination_of_columns" in t["name"]
            for t in tests[uid]
        )
        if not has_pk:
            add("fct_missing_primary_key_tests", [nm], "no unique/not_null test")

        if source_parents and model_parents:
            add("fct_direct_join_to_source", [nm],
                f"joins source(s) {sorted(sources[s]['name'] for s in source_parents)} directly alongside model refs")

        if len(source_parents) > 1:
            add("fct_multiple_sources_joined", [nm],
                f"joins {len(source_parents)} sources directly")

        if layer(node) == "staging":
            bad = [models[p]["name"] for p in model_parents
                   if layer(models[p]) in ("intermediate", "marts")]
            if bad:
                add("fct_staging_dependent_on_marts_or_intermediate", [nm],
                    f"staging model depends on {bad}")

        if layer(node) in ("intermediate", "marts") and not parents[uid]:
            add("fct_root_models", [nm], "no upstream refs or sources")

        # rejoining: C depends on A and B where A is also a direct parent of B
        direct = list(model_parents)
        for a in direct:
            for b in direct:
                if a != b and a in parents.get(b, set()):
                    add("fct_rejoining_of_upstream_concepts",
                        [nm, models[a]["name"], models[b]["name"]],
                        f"{nm} joins both {models[a]['name']} and {models[b]['name']}, "
                        f"but {models[b]['name']} already depends on {models[a]['name']}")

        kids = children.get(uid, set())
        leaf_kids = [k for k in kids if not children.get(k)]
        if len(leaf_kids) > MODEL_FANOUT_THRESHOLD and len(leaf_kids) == len(kids):
            add("fct_model_fanout", [nm],
                f"fans out to {len(leaf_kids)} leaf models")

        raw = node.get("raw_code") or node.get("raw_sql") or ""
        cleaned = re.sub(r"\{\{.*?\}\}|\{%.*?%\}|--.*", "", raw, flags=re.DOTALL)
        hard = [m.group(1) for m in HARD_CODED_REF_RE.finditer(cleaned) if "." in m.group(1)]
        if hard:
            add("fct_hard_coded_references", [nm], f"hardcoded refs: {sorted(set(hard))[:5]}")

    # chained view dependencies
    view_uids = {u for u, n in models.items()
                 if n.get("config", {}).get("materialized") in ("view", "ephemeral")}

    def view_chain_depth(uid, seen):
        if uid not in view_uids or uid in seen:
            return 0
        return 1 + max(
            (view_chain_depth(p, seen | {uid}) for p in parents.get(uid, set()) if p in models),
            default=0,
        )

    for uid in view_uids:
        d = view_chain_depth(uid, set())
        if d > CHAINED_VIEWS_THRESHOLD:
            add("fct_chained_views_dependencies", [models[uid]["name"]],
                f"view/ephemeral chain depth {d} (> {CHAINED_VIEWS_THRESHOLD})")

    for suid, src in sources.items():
        kids = children.get(suid, set())
        if not kids:
            add("fct_unused_sources", [src["name"]],
                f"source {src['source_name']}.{src['name']} has no models built on it")
        elif len(kids) > 1:
            kid_names = sorted(models[k]["name"] for k in kids)
            add("fct_source_fanout", [src["name"], *kid_names],
                f"source feeds {len(kids)} models directly: {kid_names}")

    seen = defaultdict(list)
    for suid, src in sources.items():
        seen[(src.get("database"), src.get("schema"), src.get("identifier") or src["name"])].append(src["name"])
    for key, names in seen.items():
        if len(names) > 1:
            add("fct_duplicate_sources", names, f"same relation {key} declared {len(names)} times")

    return models, sources, parents, children, findings


def scope_set(models, parents, children, changed_names):
    by_name = {n["name"]: uid for uid, n in models.items()}
    changed_uids = {by_name[c] for c in changed_names if c in by_name}
    missing = [c for c in changed_names if c not in by_name]

    scoped = set(changed_uids)
    frontier = set(changed_uids)  # upstream walk
    while frontier:
        nxt = set()
        for uid in frontier:
            for p in parents.get(uid, set()):
                if p in models and p not in scoped:
                    nxt.add(p)
        scoped |= nxt
        frontier = nxt
    frontier = set(changed_uids)  # downstream walk
    while frontier:
        nxt = set()
        for uid in frontier:
            for c in children.get(uid, set()):
                if c not in scoped:
                    nxt.add(c)
        scoped |= nxt
        frontier = nxt
    return {models[u]["name"] for u in scoped}, missing


NOT_COVERED = [
    "fct_test_coverage (project-wide %; compute from summary if needed)",
    "fct_undocumented_source_columns",
    "exposure-based checks (fct_exposures_dependent_on_private_models etc.)",
    "naming-convention checks driven by package var overrides (verify against dbt_project.yml vars)",
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--changed", nargs="*", default=[])
    ap.add_argument("--changed-file")
    ap.add_argument("--full", action="store_true", help="report all findings, unscoped")
    args = ap.parse_args()

    changed = list(args.changed)
    if args.changed_file:
        with open(args.changed_file) as f:
            changed += [l.strip() for l in f if l.strip()]
    if not changed and not args.full:
        sys.exit("no changed models given; pass --changed or --full")

    manifest = load_manifest(args.manifest)
    models, sources, parents, children, findings = evaluate(manifest)

    if args.full:
        scope = {n["name"] for n in models.values()} | {s["name"] for s in sources.values()}
        missing = []
    else:
        scope, missing = scope_set(models, parents, children, changed)

    in_scope, out_counts = defaultdict(list), {}
    for rule, items in findings.items():
        kept = [i for i in items if set(i["models"]) & scope]
        if kept:
            in_scope[rule] = kept
        dropped = len(items) - len(kept)
        if dropped:
            out_counts[rule] = dropped

    json.dump(
        {
            "changed_models": changed,
            "changed_not_found": missing,
            "scope_size": len(scope),
            "scope": sorted(scope),
            "findings": in_scope,
            "out_of_scope_counts": out_counts,
            "not_covered": NOT_COVERED,
        },
        sys.stdout,
        indent=2,
    )
    print()


if __name__ == "__main__":
    main()
