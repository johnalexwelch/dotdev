#!/usr/bin/env python3
"""M1-1 (#129) — thin owned L1 harness: score a fixture's SQL-execution
correctness into a score card.

Part of the IRIS optimization loop's *measure* half (DL-0021 thin owned driver:
cherry-pick iris-eval's proven pieces, no Inspect). The result-set comparison is
cherry-picked from classdojo/iris `backend/src/iris/eval/comparator.py`
(`compare_sql_by_execution`) with two deliberate changes per DL-0022 §L1:

  1. column-sum "boost" heuristic REMOVED. The upstream comparator inflates a
     GROUP-BY mismatch to 0.8 when per-column sums happen to agree. L1 is a
     *binary correctness gate* — no partial credit, no aggregate coincidences.
  2. float tolerance 0.1% -> 1% (DL-0022 §L1: "1% float tolerance").

L1 PASS := set equality (order-independent) + 1% float tolerance +
column-alias normalization (column NAMES ignored; column COUNT and row VALUES
compared positionally). Suite gate ("no regression vs baseline") is applied by
the loop driver against the P0c baseline pass-map — out of scope for this slice.

The single live seam is `execute`: a callable `sql -> {"columns": [...],
"rows": [[...], ...]}`. Wire it to the warehouse MCP client for a real run
(HITL — needs warehouse creds, the #129 "secrets" gate). Offline use and the
`--selftest` supply recorded result sets, so the scoring core needs no network.

Run:  python loop/measure/l1_harness.py --selftest
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Callable
from dataclasses import asdict, dataclass, field
from typing import Any

# ponytail: DL-0022 §L1 fixes tolerance at 1%. Kept as a named constant, not a
# knob — there is exactly one spec value. Widen only if the spec changes.
FLOAT_TOL = 0.01

# A result set as returned by the warehouse MCP: ordered columns + row tuples.
Result = dict[str, Any]
Execute = Callable[[str], Result]


def _parse_numeric(val: Any) -> float | None:
    if val is None:
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


def _cells_match(a: Any, b: Any, tol: float = FLOAT_TOL) -> bool:
    """One cell vs one cell: numeric with relative tolerance, else string-equal."""
    na, nb = _parse_numeric(a), _parse_numeric(b)
    if na is not None and nb is not None:
        if na == 0.0 and nb == 0.0:
            return True
        return abs(na - nb) <= tol * max(abs(na), abs(nb), 1.0)
    return str(a) == str(b)


def _rows_match(a: list[Any], b: list[Any], tol: float = FLOAT_TOL) -> bool:
    return len(a) == len(b) and all(_cells_match(x, y, tol) for x, y in zip(a, b, strict=True))


def _multiset_equal(golden: list[list[Any]], cand: list[list[Any]], tol: float = FLOAT_TOL) -> bool:
    """Order-independent bijection: every golden row pairs with a distinct
    candidate row under `_rows_match`. Assumes equal length (checked by caller).

    ponytail: greedy first-fit matching. O(n^2), fine for L1 result sets
    (<=100 rows). Pathological near-tie float clusters could greedily misassign;
    upgrade path if it ever bites = bipartite (Hungarian) matching.
    """
    remaining = list(cand)
    for g in golden:
        for i, c in enumerate(remaining):
            if _rows_match(g, c, tol):
                remaining.pop(i)
                break
        else:
            return False
    return not remaining


def l1_pass(golden: Result | None, cand: Result | None, tol: float = FLOAT_TOL) -> bool:
    """Binary L1 gate. Missing/empty result, differing column count, differing
    row count, or any unmatched row -> fail. Column NAMES are ignored."""
    if not golden or not cand:
        return False
    g_cols, c_cols = golden.get("columns", []), cand.get("columns", [])
    g_rows, c_rows = golden.get("rows", []), cand.get("rows", [])
    if len(g_cols) != len(c_cols):  # alias-agnostic: count only, not names
        return False
    if len(g_rows) != len(c_rows):
        return False
    return _multiset_equal(g_rows, c_rows, tol)


@dataclass
class CaseResult:
    id: str
    passed: bool
    note: str = ""


@dataclass
class ScoreCard:
    cases: list[CaseResult] = field(default_factory=list)

    @property
    def n_total(self) -> int:
        return len(self.cases)

    @property
    def n_pass(self) -> int:
        return sum(1 for c in self.cases if c.passed)

    @property
    def pass_rate(self) -> float:
        return self.n_pass / self.n_total if self.n_total else 0.0

    def to_dict(self) -> dict[str, Any]:
        return {
            "layer": "L1",
            "n_total": self.n_total,
            "n_pass": self.n_pass,
            "pass_rate": round(self.pass_rate, 4),
            "cases": [asdict(c) for c in self.cases],
        }


def score_l1(pairs: list[dict[str, str]], execute: Execute, tol: float = FLOAT_TOL) -> ScoreCard:
    """Score each pair's L1 correctness. Each pair needs `id`, `golden_sql`, and
    `generated_sql` (the analyst's candidate for a real run; == golden_sql only
    for a trivial smoke run). Execution errors fail the case, never crash."""
    card = ScoreCard()
    for p in pairs:
        cid = p.get("id", "?")
        try:
            g = execute(p["golden_sql"])
            c = execute(p["generated_sql"])
        except Exception as exc:  # a broken query is an L1 failure, not a crash
            card.cases.append(CaseResult(cid, False, f"execution error: {exc}"))
            continue
        ok = l1_pass(g, c, tol)
        card.cases.append(CaseResult(cid, ok, "" if ok else "result sets differ"))
    return card


def load_pairs(seed_path: str) -> list[dict[str, str]]:
    """Load golden pairs (id, question, golden_sql) from an iris seed.yml at the
    pinned commit. `generated_sql` is attached later by the run step (the analyst
    stage lives in #130). Lazy-imports PyYAML so `--selftest` stays stdlib-only."""
    import yaml  # noqa: PLC0415 — deferred so the offline self-check needs no deps

    try:
        with open(seed_path) as fh:
            data = yaml.safe_load(fh)
    except OSError as exc:
        raise FileNotFoundError(f"cannot read seed file {seed_path!r}: {exc}") from exc
    out = []
    for p in data.get("pairs", []):
        if p.get("golden_sql"):
            out.append({"id": p["id"], "question": p.get("question", ""), "golden_sql": p["golden_sql"]})
    return out


def _selftest() -> None:
    """Assert-based, no framework. Exercises the DL-0022 §L1 semantics and the
    two cherry-pick changes (boost removed, 1% tolerance)."""
    R = lambda cols, rows: {"columns": cols, "rows": rows}  # noqa: E731

    # 1. identical -> pass
    assert l1_pass(R(["a"], [[1], [2]]), R(["a"], [[1], [2]]))
    # 2. order-independent -> pass
    assert l1_pass(R(["a"], [[1], [2], [3]]), R(["a"], [[3], [1], [2]]))
    # 3a. 1% tolerance: 100.0 vs 100.5 (0.5%) -> pass
    assert l1_pass(R(["x"], [[100.0]]), R(["x"], [[100.5]]))
    # 3b. 2% delta -> fail (proves tol is 1%, not looser)
    assert not l1_pass(R(["x"], [[100.0]]), R(["x"], [[102.0]]))
    # 4. column-count mismatch -> fail
    assert not l1_pass(R(["a", "b"], [[1, 2]]), R(["a"], [[1]]))
    # 5. row-count mismatch -> fail
    assert not l1_pass(R(["a"], [[1], [2]]), R(["a"], [[1]]))
    # 6. column-alias normalization: different NAMES, same values -> pass
    assert l1_pass(R(["revenue"], [[10]]), R(["total_rev"], [[10]]))
    # 7. BOOST REMOVED: same row count, per-column sums equal (6==6), rows differ -> FAIL
    assert not l1_pass(R(["v"], [[1], [2], [3]]), R(["v"], [[2], [2], [2]]))
    # 8. string cells compared exactly
    assert not l1_pass(R(["p"], [["basic"]]), R(["p"], [["premium"]]))
    # 9. missing/empty result -> fail (no crash)
    assert not l1_pass(None, R(["a"], [[1]]))
    assert not l1_pass(R(["a"], []), R(["a"], [[1]]))

    # 10. score card + execution-error handling (error = fail, no crash)
    recorded = {
        "SELECT ok": R(["a"], [[1]]),
        "SELECT match": R(["a"], [[1]]),
        "SELECT diff": R(["a"], [[9]]),
    }

    def execute(sql: str) -> Result:
        if sql == "BOOM":
            raise RuntimeError("syntax error")
        return recorded[sql]

    pairs = [
        {"id": "hit", "golden_sql": "SELECT ok", "generated_sql": "SELECT match"},
        {"id": "miss", "golden_sql": "SELECT ok", "generated_sql": "SELECT diff"},
        {"id": "broken", "golden_sql": "SELECT ok", "generated_sql": "BOOM"},
    ]
    card = score_l1(pairs, execute)
    d = card.to_dict()
    assert d["n_total"] == 3 and d["n_pass"] == 1, d
    assert abs(card.pass_rate - 1 / 3) < 1e-9, card.pass_rate  # unrounded property
    assert d["pass_rate"] == 0.3333, d  # card rounds to 4dp
    assert {c["id"]: c["passed"] for c in d["cases"]} == {"hit": True, "miss": False, "broken": False}
    assert "execution error" in [c["note"] for c in d["cases"] if c["id"] == "broken"][0]

    print("l1_harness selftest OK — 10 checks (set-equality, 1% tol, alias norm, boost removed, "
          "error-as-fail, score card)")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="M1-1 L1 SQL-execution-correctness harness (#129).")
    ap.add_argument("--selftest", action="store_true", help="run offline self-check and exit")
    ap.add_argument("--seed", help="path to an iris seed.yml; prints loaded golden pairs (no scoring "
                                   "— live scoring needs warehouse creds, the #129 HITL gate)")
    args = ap.parse_args(argv)

    if args.selftest:
        _selftest()
        return 0
    if args.seed:
        pairs = load_pairs(args.seed)
        print(json.dumps({"loaded_pairs": len(pairs), "ids": [p["id"] for p in pairs]}, indent=2))
        print("\nNote: L1 scoring requires executing golden + generated SQL against the warehouse. "
              "Wire `execute` to the MCP client and call score_l1() once creds are provisioned (#129).",
              file=sys.stderr)
        return 0
    ap.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
