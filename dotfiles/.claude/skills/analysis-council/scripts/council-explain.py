#!/usr/bin/env python3
"""Dry-run the analysis-council roster: show which personas/models WOULD run,
whether quorum is achievable, and a seat-cost signal — without dispatching a
single token. (Stolen from pi-smart-router's explain endpoint: compute the
decision without executing it.)

Usage:
    council-explain.py ["topic text"]      # topic optional; enables keyword preview
    council-explain.py --selftest
Reads roster.yml sitting next to this script's skill dir.
"""
import os, re, sys

ROSTER = os.path.join(os.path.dirname(__file__), "..", "roster.yml")


def parse(text):
    def model_for(name, default):
        m = re.search(
            r"^\s+" + re.escape(name)
            + r":\s*\{model:\s*(\w+),\s*reasoning:\s*(\w+)(?:,\s*cross_family:\s*(true))?\}",
            text, re.M)
        if not m:
            return default
        return {"model": m.group(1), "reasoning": m.group(2), "cf": bool(m.group(3))}

    def list_after(key):
        out, grab = [], False
        for ln in text.splitlines():
            if re.match(r"^%s:\s*$" % re.escape(key), ln):
                grab = True
                continue
            if grab:
                mm = re.match(r"^\s+-\s+(.+)$", ln)
                if mm:
                    out.append(mm.group(1).strip())
                elif ln.strip() == "" or ln.lstrip().startswith("#"):
                    continue
                else:
                    break
        return out

    default = model_for("default", {"model": "sonnet", "reasoning": "high", "cf": False})
    synth = model_for("synthesis", default)
    always = []
    m = re.search(r"always_seat:\s*\[([^\]]*)\]", text)
    if m:
        always = [x.strip() for x in m.group(1).split(",") if x.strip()]
    sig = {}
    for m in re.finditer(r"^  ([a-z][\w-]+):\n\s+keywords:\s*\[([^\]]*)\]", text, re.M):
        sig[m.group(1)] = [k.strip() for k in m.group(2).split(",") if k.strip()]
    maxe = re.search(r"max_experts:\s*(\d+)", text)
    return {
        "required": list_after("required"),
        "optional": list_after("optional"),
        "always": always,
        "quorum": "required_all_contributing: true" in text,
        "max_experts": int(maxe.group(1)) if maxe else None,
        "synth": synth,
        "default": default,
        "model_for": lambda n: model_for(n, default),
        "signals": sig,
    }


def tag(m):
    return f"{m['model']}/{m['reasoning']}" + ("  [cross-family]" if m.get("cf") else "")


def explain(topic=""):
    r = parse(open(ROSTER).read())
    t = topic.lower()
    seated_required = list(dict.fromkeys(r["required"] + r["always"]))
    opt_pool = [p for p in r["optional"] if p not in seated_required]

    print("analysis-council — dry run (no dispatch)")
    print(f'topic: {topic!r}' if topic else "topic: (none — showing full roster)")
    print("\nREQUIRED (always seated):")
    for p in seated_required:
        note = "  (always_seat)" if p in r["always"] and p not in r["required"] else ""
        print(f"  {p:<26} {tag(r['model_for'](p))}{note}")

    matched, untriggered = [], []
    for p in opt_pool:
        hits = [k for k in r["signals"].get(p, []) if t and k.lower() in t]
        (matched if hits else untriggered).append((p, hits))

    if topic:
        print("\nOPTIONAL — would seat (keyword match; semantic classifier may add more):")
        if not matched:
            print("  (none matched — orchestrator still seats by semantic read)")
        for p, hits in matched:
            print(f"  {p:<26} {tag(r['model_for'](p))}  ← {', '.join(hits)}")
        print("\nOPTIONAL — available, not triggered:")
    else:
        print("\nOPTIONAL — available (seated by topic at run time):")
    for p, _ in untriggered:
        print(f"  {p:<26} {tag(r['model_for'](p))}")

    print(f"\nSYNTHESIS: {tag(r['synth'])}")
    print("QUORUM: " + ("all required must return 'contributing' or the run is INVALID"
                         if r["quorum"] else "(none configured)"))
    if r["max_experts"]:
        print(f"CAP: max {r['max_experts']} experts seated per run")

    seats = [r["model_for"](p) for p in seated_required] + [r["synth"]]
    opus = sum(1 for s in seats if s["model"] == "opus")
    other = len(seats) - opus
    print(f"\nSeat-cost signal (required + synthesis, before optional): "
          f"{opus} opus + {other} {r['default']['model']} calls, "
          f"+ up to {len(opt_pool)} optional. No tokens spent.")
    return r


def selftest():
    r = explain("pricing and ROI for a cohort retention experiment")
    assert "skeptical-data-scientist" in r["required"], "missing primary adversary"
    assert r["model_for"]("skeptical-data-scientist")["model"] == "opus", "adversary not opus"
    assert r["model_for"]("skeptical-data-scientist")["cf"], "adversary not cross-family"
    assert r["quorum"], "quorum rule not parsed"
    assert "bias-auditor" in r["always"], "always_seat not parsed"
    print("\nselftest OK")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        selftest()
    else:
        explain(" ".join(sys.argv[1:]))
