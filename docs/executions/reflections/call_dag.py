#!/usr/bin/env python3
"""Skill CALL DAG: only immediate upstream/downstream invoke edges.
- Flow `A → B → C` ⇒ A→B, B→C (and orchestrator→A)
- No workflow-router classification fan-out
- Transitive reduction on the result
"""
from __future__ import annotations
import json, re
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path("/Users/alexwelch/dotdev/dotfiles/.config/agents/skills")
NAMES = {p.name for p in ROOT.iterdir() if p.is_dir() and (p / "SKILL.md").exists()}

INVOKE_RE = [
    re.compile(r"Load and run [`']([a-z][a-z0-9-]{1,60})(?:/SKILL\.md)?[`']", re.I),
    re.compile(r"Load and execute [`']([a-z][a-z0-9-]{1,60})(?:/SKILL\.md)?[`']", re.I),
    re.compile(r"Use the Skill tool to invoke [`']([a-z][a-z0-9-]{1,60})[`']", re.I),
    re.compile(r"\*\*Invoke:\*\*\s*[`']([a-z][a-z0-9-]{1,60})[`']", re.I),
    re.compile(r"\binvoke [`']([a-z][a-z0-9-]{1,60})[`']", re.I),
    re.compile(r"invocations? via [`']([a-z][a-z0-9-]{1,60})[`']", re.I),
    re.compile(r"implementation via [`']([a-z][a-z0-9-]{1,60})[`']", re.I),
]
HANDOFF_RE = re.compile(r"auto-handoff|\*\*auto-handoff\*\*|invoke [`']handoff[`']|mandatory end-of-run exit", re.I)
FENCE = re.compile(r"```(?:text|markdown)?\n(.*?)```", re.S)
ROUTING_ARROW = re.compile(
    r"(?:^|\n)\s*[-*]\s+([^\n]+?)\s*→\s*[`']([a-z][a-z0-9-]{1,60})[`']"
)
# informal flow aliases → skill names
ALIAS = {
    "preflight": "prompt-builder",
    "execute": "execute-phase",
    "finalize": "workflow-finalize",
    "user-journey": "user-journey-qa",
    "uj-qa": "user-journey-qa",
    "grill": "grill-with-docs",
}

CLUSTER_COLOR = {
    "router": "red", "workflow": "blue", "incident": "orange", "data": "green",
    "metric": "violet", "analysis": "light-violet", "v1": "light-blue",
    "review": "yellow", "delivery": "light-green", "skillops": "grey",
    "persona": "light-red", "misc": "black",
}

def cluster_of(name: str) -> str:
    if name == "workflow-router" or name == "wayfinder":
        return "router"
    if name.startswith("v1-") or name == "stage-v1-concept":
        return "v1"
    if name.startswith("workflow-") or name in (
        "run-backlog", "execute-prd", "execute-phase", "to-prd", "to-issues",
        "triage", "prompt-builder", "design-plan", "repo-audit",
        "improve-codebase-architecture", "grill-with-docs", "decision-log",
    ):
        return "workflow"
    if "incident" in name or name in ("diagnose", "runbook-author", "post-mortem"):
        return "incident"
    if name in ("describe-pr", "receive-review", "watch-ci", "pr-review", "pr-responder",
                "review", "spec-review", "docs-audit", "clarity-review"):
        return "review"
    if name in ("cleanup-delivery", "handoff", "setup-worktree", "git-guardrails",
                "implement", "tdd", "herdr", "herdr-launch", "slack-update",
                "resolving-merge-conflicts", "prototype", "product-launch-checklist",
                "user-journey-qa", "caveman"):
        return "delivery"
    if name.startswith("skill-") or name in ("write-a-skill", "setup-skills", "find-skills"):
        return "skillops"
    if any(x in name for x in ("metric", "dashboard", "okr", "viz")):
        return "metric"
    if any(x in name for x in ("data-", "sql-", "lineage", "domain-model", "mock-data")):
        return "data"
    if any(x in name for x in ("analysis", "decision-", "experiment", "strategic", "vendor", "council")):
        return "analysis"
    if name in ("causal-reasoner", "statistician", "counterfactual-check", "bias-auditor",
                "exec-audience-stand-in", "ops-analyst", "economist", "visualization-critic",
                "governance-reviewer"):
        return "persona"
    return "misc"

def section(text: str, title: str) -> str:
    m = re.search(rf"^## {re.escape(title)}\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""

def resolve_token(tok: str) -> str | None:
    if tok in NAMES:
        return tok
    if tok in ALIAS and ALIAS[tok] in NAMES:
        return ALIAS[tok]
    # exact skill name appearing inside a longer segment (not substring of another word)
    for n in sorted(NAMES, key=len, reverse=True):
        if re.search(rf"(?<![a-z0-9-]){re.escape(n)}(?![a-z0-9-])", tok):
            return n
    return None

def parse_flow_sequence(flow: str) -> list[str]:
    """Extract ordered skill sequence from first flow fence."""
    fences = FENCE.findall(flow)
    if not fences:
        # also try unfenced single-line arrows in Flow
        fences = [flow]
    best: list[str] = []
    for fence in fences:
        # split on arrows
        parts = re.split(r"\s*(?:→|->|⬇️)\s*", fence.replace("\n", " "))
        seq = []
        for p in parts:
            p = p.strip()
            if not p:
                continue
            # strip brackets / conditionals
            p = re.sub(r"[\[\]()]", " ", p)
            # collect skill tokens in segment; prefer known skill names
            hits = []
            for tok in re.findall(r"[a-z][a-z0-9-]{2,60}", p.lower()):
                r = resolve_token(tok)
                if r and (not hits or hits[-1] != r):
                    hits.append(r)
            if hits:
                # one step per segment — first skill
                if not seq or seq[-1] != hits[0]:
                    seq.append(hits[0])
        if len(seq) > len(best):
            best = seq
    return best

def step_bodies(text: str) -> str:
    parts = []
    for title in ("Flow", "Process", "Detailed Steps", "Workflow"):
        s = section(text, title)
        if s:
            parts.append(s)
    parts.extend(re.findall(r"^### (?:Step|Phase)[^\n]*\n(.*?)(?=^### |\Z)", text, re.M | re.S))
    return "\n".join(parts)

def extract_edges(name: str, text: str) -> list[tuple[str, str, str]]:
    """Return list of (src, dst, label) — may include edges where src != name (fence pairs)."""
    if name == "workflow-router":
        return []

    edges: list[tuple[str, str, str]] = []
    flow = section(text, "Flow")
    seq = parse_flow_sequence(flow) if flow else []

    if seq:
        # orchestrator → first step
        if seq[0] != name:
            edges.append((name, seq[0], "start"))
        # consecutive immediate steps
        for a, b in zip(seq, seq[1:]):
            if a != b:
                edges.append((a, b, ""))
    else:
        # no usable flow sequence: strong invokes from this skill are immediate children
        body = step_bodies(text) or text
        for pat in INVOKE_RE:
            for m in pat.finditer(body):
                tgt = m.group(1)
                if tgt in NAMES and tgt != name:
                    edges.append((name, tgt, ""))

    # Also pick up Load/run targets even when a flow fence exists, IF they are not
    # already in the fence sequence (side calls). Still immediate from this skill.
    fence_set = set(seq)
    body = step_bodies(text) or text
    for pat in INVOKE_RE:
        for m in pat.finditer(body):
            tgt = m.group(1)
            if tgt in NAMES and tgt != name and tgt not in fence_set:
                # avoid re-adding orchestrator fan-out to mid-chain steps already
                # reachable via fence — only allow side exits / siblings
                if tgt in ("handoff",) or not seq:
                    edges.append((name, tgt, ""))
                elif name in ("run-backlog", "skill-backlog", "execute-prd", "workflow-autonomous-backlog"):
                    edges.append((name, tgt, "dispatch"))

    # halt → handoff
    if HANDOFF_RE.search(body) and "handoff" in NAMES and name != "handoff":
        if name.startswith("workflow-") or name in ("run-backlog", "execute-prd", "watch-ci"):
            edges.append((name, "handoff", "halt"))

    # handoff → prompt-builder (explicit in handoff skill)
    if name == "handoff":
        for pat in INVOKE_RE:
            for m in pat.finditer(text):
                tgt = m.group(1)
                if tgt in NAMES:
                    edges.append((name, tgt, ""))

    return edges

def extract_routes(name: str, text: str) -> list[tuple[str, str, str]]:
    if name == "workflow-router":
        return []
    out = []
    # Prefer dedicated Routing sections
    for title in ("Routing", "Routing table", "When to invoke"):
        pass
    for m in ROUTING_ARROW.finditer(text):
        label, tgt = m.group(1).strip(), m.group(2)
        if tgt in NAMES and tgt != name:
            # skip classification-looking long labels from router-like tables inside other files
            if "Routes to" in label or "Classification" in label:
                continue
            out.append((name, tgt, label[:36]))
    return out

def transitive_reduction(
    edges: set[tuple[str, str]],
    ignore_for_paths: set[tuple[str, str]] | None = None,
) -> set[tuple[str, str]]:
    """Remove A→C when a longer A↝C path exists via non-ignored edges.
    ignore_for_paths: halt/soft edges that must not create phantom longer paths
    (e.g. build-one→handoff→prompt-builder must not delete build-one→prompt-builder).
    Also collapse 2-cycles preferring delivery-order edges."""
    ignore_for_paths = ignore_for_paths or set()
    prefer = {
        ("receive-review", "watch-ci"),
        ("watch-ci", "reconcile-issues"),
        ("describe-pr", "receive-review"),
        ("post-mortem", "describe-pr"),
    }
    both = set(edges)
    for a, b in list(both):
        if (b, a) in both:
            if (a, b) in prefer:
                both.discard((b, a))
            elif (b, a) in prefer:
                both.discard((a, b))
            else:
                both.discard((b, a))

    adj = defaultdict(set)
    for a, b in both:
        if (a, b) not in ignore_for_paths:
            adj[a].add(b)

    def has_longer_path(u, v):
        seen = set()
        q = deque([w for w in adj[u] if w != v])
        while q:
            x = q.popleft()
            if x in seen:
                continue
            seen.add(x)
            if x == v:
                return True
            for y in adj[x]:
                if y not in seen:
                    q.append(y)
        return False

    return {(a, b) for a, b in both if not has_longer_path(a, b)}

def layered_coords(nodes: set[str], edges: set[tuple[str, str]]):
    adj = defaultdict(list)
    indeg = {n: 0 for n in nodes}
    # cycle-break for layout only
    state, back = {}, set()
    for root in nodes:
        if state.get(root):
            continue
        stack = [(root, iter(adj.get(root, []) or []))]
        # need adj first
    for a, b in edges:
        adj[a].append(b)
    state, back = {}, set()
    for root in nodes:
        if state.get(root):
            continue
        stack = [(root, iter(list(adj[root])))]
        state[root] = 1
        while stack:
            u, it = stack[-1]
            adv = False
            for v in it:
                st = state.get(v, 0)
                if st == 0:
                    state[v] = 1
                    stack.append((v, iter(list(adj[v]))))
                    adv = True
                    break
                if st == 1:
                    back.add((u, v))
            if not adv:
                state[u] = 2
                stack.pop()

    dag = defaultdict(list)
    indeg = {n: 0 for n in nodes}
    for a, b in edges:
        if (a, b) in back:
            continue  # drop back-edges from layout graph (keep in drawn edges!)
        dag[a].append(b)
        indeg[b] += 1

    layer = {n: 0 for n in nodes}
    q = deque([n for n in nodes if indeg[n] == 0])
    tin = dict(indeg)
    seen_count = 0
    while q:
        u = q.popleft()
        seen_count += 1
        for v in dag[u]:
            layer[v] = max(layer[v], layer[u] + 1)
            tin[v] -= 1
            if tin[v] == 0:
                q.append(v)
    # nodes in cycles / unreachable: keep layer 0

    layers = defaultdict(list)
    for n in nodes:
        layers[layer[n]].append(n)
    for L in layers:
        layers[L].sort()

    NW, NH, DX, DY = 200, 56, 240, 140
    coords = {}
    width = max((len(layers[L]) for L in layers), default=1)
    for L in sorted(layers):
        row = layers[L]
        off = (width - len(row)) / 2.0
        for i, n in enumerate(row):
            coords[n] = ((off + i) * DX, L * DY)
    return coords, NW, NH, DX, DY

def main():
    raw: set[tuple[str, str]] = set()
    labels: dict[tuple[str, str], str] = {}
    halt_edges: set[tuple[str, str]] = set()
    routes: list[tuple[str, str, str]] = []

    for name in sorted(NAMES):
        text = (ROOT / name / "SKILL.md").read_text()
        for a, b, lab in extract_edges(name, text):
            raw.add((a, b))
            if lab:
                labels[(a, b)] = lab
            if lab == "halt":
                halt_edges.add((a, b))
        routes.extend(extract_routes(name, text))

    # handoff→prompt-builder and orchestrator→handoff must not erase pipeline starts
    ignore = set(halt_edges)
    if ("handoff", "prompt-builder") in raw:
        ignore.add(("handoff", "prompt-builder"))

    reduced = transitive_reduction(raw, ignore_for_paths=ignore)

    # Drop callback / prose false-positives (not Flow-defined delivery)
    for bad in [
        ("watch-ci", "receive-review"),
        ("cleanup-delivery", "reconcile-issues"),
        # handoff→prompt-builder is soft follow-up; keeps layout from sinking prompt-builder
        ("handoff", "prompt-builder"),
    ]:
        reduced.discard(bad)

    # CALL DAG only — connected skills. No router classification, no decision-route fan-out.
    used = {n for ab in reduced for n in ab}
    isolates = sorted(NAMES - used)
    # Include router as orphan annotation node (no edges) so it still appears
    if "workflow-router" in NAMES and "workflow-router" not in used:
        used.add("workflow-router")

    coords, NW, NH, DX, DY = layered_coords(used - {"workflow-router"}, reduced)
    # park router left of layer-0 roots
    if "workflow-router" in used:
        coords["workflow-router"] = (-DX * 1.5, 0)

    PAD, TTL = 40, 70
    frames, titles = [], []
    if used:
        xs = [coords[n][0] for n in used]
        ys = [coords[n][1] for n in used]
        fx, fy = min(xs) - PAD, min(ys) - TTL
        fw = max(xs) - min(xs) + NW + 2 * PAD
        fh = max(ys) - min(ys) + NH + TTL + PAD
        frames.append({"id": "shape:frame_DAG", "x": fx, "y": fy, "w": fw, "h": fh})
        titles.append({
            "id": "shape:ttl_DAG", "x": fx + PAD, "y": fy + 12,
            "text": "CALL DAG — only immediate next skill (Flow A→B or Load/run). No router fan-out. Transitive shortcuts removed.",
            "color": "black", "size": "l", "w": max(fw - 2 * PAD, 400),
        })

    out_nodes = [{
        "id": f"shape:sk_{n}", "x": round(x), "y": round(y), "w": NW, "h": NH,
        "color": CLUSTER_COLOR.get(cluster_of(n), "grey"), "label": n,
    } for n, (x, y) in coords.items()]

    out_edges = []
    for i, (a, b) in enumerate(sorted(reduced)):
        lab = labels.get((a, b), "")
        # Don't label with the destination skill name (looks like a duplicate node)
        if lab in (b, a, "start", "dispatch", "halt"):
            show = "" if lab in (b, a) else lab
        else:
            show = lab
        out_edges.append({
            "id": f"shape:e{i}", "from": f"shape:sk_{a}", "to": f"shape:sk_{b}",
            "color": "blue", "dash": "solid",
            "label": show, "kind": "call",
        })

    bx = frames[0]["x"] if frames else 0
    by = (frames[0]["y"] - 130) if frames else -130
    titles.extend([
        {"id": "shape:ttl_main", "x": bx, "y": by, "text": "SKILL CALL DAG",
         "size": "xl", "color": "black", "w": 900},
        {"id": "shape:ttl_legend", "x": bx, "y": by + 50,
         "text": f"BLUE = immediate invoke only. workflow-router = dynamic dispatch (0 outbound). Isolates omitted ({len(isolates)} skills with no parsed calls).",
         "size": "s", "color": "grey", "w": 2400},
    ])

    Path("/tmp/skillmap/call_payload.json").write_text(json.dumps({
        "frames": frames, "titles": titles, "nodes": out_nodes, "edges": out_edges,
    }))

    router_out = sum(1 for e in out_edges if e["from"].endswith("workflow-router"))
    print(f"raw:{len(raw)} reduced:{len(reduced)} drawn:{len(out_edges)} router_out:{router_out} isolates:{len(isolates)}")
    for a, b in sorted(reduced):
        print(f"  {a} -> {b}  [{labels.get((a,b),'')}]")
    checks = {
        "router→handoff": ("workflow-router", "handoff") in reduced,
        "router→describe-pr": ("workflow-router", "describe-pr") in reduced,
        "describe-pr→receive-review": ("describe-pr", "receive-review") in reduced,
        "receive-review→watch-ci": ("receive-review", "watch-ci") in reduced,
        "build-one→triage or prompt": ("workflow-build-one", "triage") in reduced or ("workflow-build-one", "prompt-builder") in reduced,
        "feature→grill": ("workflow-feature", "grill-with-docs") in reduced,
        "watch-ci→receive-review (bad)": ("watch-ci", "receive-review") in reduced,
    }
    print("checks:", checks)

if __name__ == "__main__":
    main()
