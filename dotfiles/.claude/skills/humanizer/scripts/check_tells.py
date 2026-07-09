#!/usr/bin/env python3
"""
check_tells.py — scan text for common AI-writing tells.

Usage:
  python3 check_tells.py path/to/file.md
  cat draft.md | python3 check_tells.py -

Exit code is the total tell count, so it can be used in CI / pre-commit
or piped through `[ $(check_tells.py draft.md) -eq 0 ]`.

Output format:
  TELL_NAME: count
  ...
  TOTAL: N

Detects mechanical AI markers only (em dashes, curly quotes, vocab,
bolded inline list headers, title-case headings, common signposts).
Subtler tells (rule-of-three, promotional tone, fake significance)
still need agent judgment — this script catches the obvious stuff
the humanizer should never miss.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# High-frequency AI vocabulary (pattern catalog #7).
AI_VOCAB = [
    r"\bdelve\b",
    r"\btapestry\b",
    r"\bunderscore[sd]?\b",
    r"\btestament\b",
    r"\bpivotal\b",
    r"\bcrucial\b",
    r"\bvibrant\b",
    r"\bgroundbreaking\b",
    r"\benduring\b",
    r"\bgarner[sd]?\b",
    r"\bshowcase[sd]?\b",
    r"\bfostering\b",
    r"\bintricate\b",
    r"\binterplay\b",
    r"\bnestled\b",
    r"\bnavigate the\b",
    r"\bin (today's|the) (rapidly )?evolving landscape\b",
    r"\bvital role\b",
    r"\bkey (insight|takeaway|role)\b",
    # Common post-2023 vocab the original list missed.
    r"\bleverage[sd]?\b",
    r"\brobust\b",
    r"\bseamless(ly)?\b",
    r"\butilize[sd]?\b",
    r"\bmyriad\b",
    r"\bholistic\b",
    r"\bnuanced\b",
    r"\bmultifaceted\b",
    r"\brealm\b",
    r"\bmoreover\b",
    r"\bfurthermore\b",
    r"\bnotably\b",
    r"\bcomprehensive\b",
]

# Filler phrases (#23).
FILLER = [
    r"\bin order to\b",
    r"\bdue to the fact that\b",
    r"\bat this point in time\b",
    r"\bin the event that\b",
    r"\bhas the ability to\b",
    r"\bit is important to note that\b",
    r"\bit's worth noting\b",
    r"\bneedless to say\b",
]

# Copula avoidance (#8) — elaborate stand-ins for is/are.
COPULA = [
    r"\bserves as\b",
    r"\bstands as\b",
    r"\bboasts (a|an|over)\b",
    r"\bfeatures (a|an)\b",
]

# Persuasive authority tropes (#27).
AUTHORITY = [
    r"\bfundamentally\b",
    r"\bwhat really matters\b",
    r"\bthe deeper issue\b",
    r"\bthe heart of the matter\b",
    r"\bin reality\b",
]

# Knowledge-cutoff disclaimers (#21).
KNOWLEDGE_CUTOFF = [
    r"\bas of my last (training|update|knowledge)\b",
    r"\bbased on available information\b",
    r"\bwhile specific details are (limited|scarce)\b",
]

# Signposting phrases (pattern catalog #28).
SIGNPOSTS = [
    r"\blet's (dive|explore|break this down|take a look)\b",
    r"\bhere's what you need to know\b",
    r"\bnow let's\b",
    r"\bwithout further ado\b",
    r"\bin conclusion\b",
    r"\bat its core\b",
    r"\bthe real question is\b",
]

# Collaborative / chatbot artifacts (#20).
CHATBOT = [
    r"\bgreat question\b",
    r"\bi hope this helps\b",
    r"\bcertainly!\b",
    r"\bof course!\b",
    r"\byou're absolutely right\b",
    r"\blet me know if\b",
    r"\bwould you like\b",
]

# Negative parallelism (#9).
NEG_PARALLEL = [
    r"\bit's not (just|merely|only) about\b",
    r"\bnot just .{1,40} but\b",
    r"\bnot only .{1,40} but( also)?\b",
]

# Code-review hedges. Stating a recommendation > hedging around one.
# Acceptable status statements ("not blocking", "ok to merge as-is",
# "confirmed by the test plan") are factual and excluded.
HEDGES = [
    r"\bworth (confirming|a look|adding|pulling|opening|a sentence|noting|extracting|considering|checking|documenting)\b",
    r"\bworth it to\b",
    r"\bok to defer\b",
    r"\bok to batch\b",
    r"\bmight want to\b",
    r"\bmight be worth\b",
    r"\bcould be worth\b",
    r"\bprobably fine\b",
    r"\bprobably worth\b",
    r"\bit seems like\b",
    r"\bit looks like\b",
    r"\bmay want to consider\b",
    r"\bone could argue\b",
    r"\bperhaps consider\b",
]

# Third-person abstractions where "we" or "this" is more direct.
# Code review voice is collegial first-person plural.
THIRD_PERSON = [
    r"\bthe author (should|will|might|may|could|would)\b",
    r"\bthe reviewer\b",
    r"\bthe next person\b",
    r"\bthe next maintainer\b",
    r"\banyone editing\b",
    r"\banyone discovering\b",
    r"\bdownstream consumers (shouldn't|should not|will|would|might)\b",
]


def find(pattern: str, text: str, flags: int = re.IGNORECASE) -> int:
    return len(re.findall(pattern, text, flags))


def count_em_dashes(text: str) -> int:
    return text.count("—")


def count_curly_quotes(text: str) -> int:
    return sum(text.count(c) for c in ["\u201c", "\u201d", "\u2018", "\u2019"])


def count_bolded_list_headers(text: str) -> int:
    """Lines like `- **Header:** rest...` or `* **Header:** rest...`."""
    return len(re.findall(r"^\s*[-*]\s+\*\*[A-Z][^*]{2,40}:\*\*", text, re.MULTILINE))


def _is_title_case_heading(line: str) -> bool:
    """ATX heading where 3+ main words are capitalized (likely title case)."""
    m = re.match(r"^#+\s+(.+?)\s*$", line)
    if not m:
        return False
    words = [w for w in re.findall(r"[A-Za-z][A-Za-z'-]+", m.group(1))]
    if len(words) < 3:
        return False
    # Drop common lowercase function words.
    small = {"a", "an", "the", "and", "or", "but", "for", "of", "in",
             "on", "to", "with", "vs", "via", "at", "by", "as", "is"}
    content = [w for w in words if w.lower() not in small]
    if len(content) < 3:
        return False
    return sum(1 for w in content if w[0].isupper()) / len(content) >= 0.75


def count_title_case_headings(text: str) -> int:
    return sum(1 for line in text.splitlines() if _is_title_case_heading(line))


def count_pattern_list(text: str, patterns: list[str]) -> int:
    return sum(find(p, text) for p in patterns)


def count_semicolons(text: str) -> int:
    return text.count(";")


_SEG = r"[A-Za-z]+(?:\s+[A-Za-z]+){0,3}"
RULE_OF_THREE_RE = re.compile(rf"\b{_SEG},\s+{_SEG},?\s+and\s+{_SEG}\b")


def count_rule_of_three(text: str) -> int:
    """Catches inline `X, Y, and Z` triples where each item is 1-4 words.
    Heuristic — false positives expected (that's why it's a flag, not an autofix)."""
    return len(RULE_OF_THREE_RE.findall(text))


# Category -> matchers, reused by locate(). Keeps the location view in sync
# with the count view: same patterns, just with offsets attached.
_LITERAL = {"em_dashes": "—", "semicolons": ";"}
_CURLY = ["\u201c", "\u201d", "\u2018", "\u2019"]
_PATTERN_GROUPS = {
    "ai_vocabulary": AI_VOCAB,
    "signposting": SIGNPOSTS,
    "chatbot_artifacts": CHATBOT,
    "negative_parallelism": NEG_PARALLEL,
    "filler_phrases": FILLER,
    "copula_avoidance": COPULA,
    "authority_tropes": AUTHORITY,
    "knowledge_cutoff": KNOWLEDGE_CUTOFF,
    "hedges": HEDGES,
    "third_person_abstraction": THIRD_PERSON,
}
_BOLDED_RE = re.compile(r"^\s*[-*]\s+\*\*[A-Z][^*]{2,40}:\*\*", re.MULTILINE)


def _line_col(text: str, offset: int) -> tuple[int, int]:
    line = text.count("\n", 0, offset) + 1
    col = offset - (text.rfind("\n", 0, offset) + 1) + 1
    return line, col


def _snippet(text: str, start: int, end: int, pad: int = 24) -> str:
    lo = max(0, start - pad)
    hi = min(len(text), end + pad)
    frag = text[lo:hi].replace("\n", " ")
    return re.sub(r"\s+", " ", frag).strip()


# Inline allowlist: a line containing `<!-- slop-ok: cat1 cat2 -->` (or
# `slop-ok: all`) suppresses hits of those categories located on that line, so a
# legit data enumeration can pass the gate without being reworded into worse prose.
_ALLOW_RE = re.compile(r"<!--\s*slop-ok:\s*([^>]*?)\s*-->")


def _allowlist(text: str) -> dict[int, set[str]]:
    allow: dict[int, set[str]] = {}
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in _ALLOW_RE.finditer(line):
            allow.setdefault(lineno, set()).update(m.group(1).split())
    return allow


def _allowed(allow: dict[int, set[str]], line: int, cat: str) -> bool:
    cats = allow.get(line)
    return bool(cats) and ("all" in cats or cat in cats)


def locate(text: str, apply_allowlist: bool = True) -> list[tuple[int, int, str, str]]:
    """Return (line, col, category, snippet) for every hit, sorted by position."""
    hits: list[tuple[int, int, str, str]] = []

    def add(category: str, start: int, end: int) -> None:
        line, col = _line_col(text, start)
        hits.append((line, col, category, _snippet(text, start, end)))

    for cat, ch in _LITERAL.items():
        i = text.find(ch)
        while i != -1:
            add(cat, i, i + len(ch))
            i = text.find(ch, i + 1)
    for ch in _CURLY:
        i = text.find(ch)
        while i != -1:
            add("curly_quotes", i, i + 1)
            i = text.find(ch, i + 1)
    for cat, patterns in _PATTERN_GROUPS.items():
        for p in patterns:
            for m in re.finditer(p, text, re.IGNORECASE):
                add(cat, m.start(), m.end())
    for m in _BOLDED_RE.finditer(text):
        add("bolded_list_headers", m.start(), m.end())
    for m in RULE_OF_THREE_RE.finditer(text):
        add("rule_of_three", m.start(), m.end())
    # title_case_headings is line-scoped; report the heading start.
    offset = 0
    for raw in text.splitlines(keepends=True):
        line_text = raw.rstrip("\n")
        if _is_title_case_heading(line_text):
            add("title_case_headings", offset, offset + len(line_text))
        offset += len(raw)

    hits.sort(key=lambda h: (h[0], h[1]))
    if apply_allowlist:
        allow = _allowlist(text)
        if allow:
            hits = [h for h in hits if not _allowed(allow, h[0], h[2])]
    return hits


def _selftest() -> int:
    """Runnable self-check: dirty sample must flag the new groups; clean must be 0."""
    dirty = (
        "In order to leverage our robust platform, it's worth noting that it "
        "serves as a comprehensive solution. Fundamentally, we offer speed, "
        "quality, and scale; not only fast but also seamless."
    )
    clean = "We rewrote the parser. It now handles nested quotes without crashing."
    d = {
        "filler": count_pattern_list(dirty, FILLER),
        "vocab": count_pattern_list(dirty, AI_VOCAB),
        "copula": count_pattern_list(dirty, COPULA),
        "authority": count_pattern_list(dirty, AUTHORITY),
        "neg": count_pattern_list(dirty, NEG_PARALLEL),
        "semis": count_semicolons(dirty),
        "three": count_rule_of_three(dirty),
    }
    assert d["filler"] >= 2, d
    assert d["vocab"] >= 4, d          # leverage, robust, comprehensive, seamless
    assert d["copula"] >= 1, d         # serves as
    assert d["authority"] >= 1, d      # fundamentally
    assert d["neg"] >= 1, d            # not only...but also
    assert d["semis"] == 1, d
    assert d["three"] >= 1, d          # speed, quality, and scale
    clean_total = (
        count_pattern_list(clean, FILLER + AI_VOCAB + COPULA + AUTHORITY + NEG_PARALLEL)
        + count_semicolons(clean)
    )
    assert clean_total == 0, clean_total
    # locate() must agree with the counts and carry positions.
    hits = locate(dirty)
    assert hits, "locate found nothing on dirty sample"
    assert all(ln >= 1 and col >= 1 for ln, col, _, _ in hits), hits
    assert len(locate(clean)) == 0, locate(clean)
    # Rhetorical triple still flags; a numeric-only triple never did.
    assert count_rule_of_three("speed, quality, and scale") == 1
    assert count_rule_of_three("44.6%, 53.3%, and 63.2%") == 0
    # Inline allowlist suppresses only the named category on that line.
    ok = "We saw revenue, margin, and growth. <!-- slop-ok: rule_of_three -->"
    assert count_rule_of_three(ok) == 1  # raw count unchanged
    assert not [h for h in locate(ok) if h[2] == "rule_of_three"], locate(ok)
    print("self-test OK")
    return 0


def main() -> int:
    args = sys.argv[1:]
    if args == ["--self-test"]:
        return _selftest()
    show_loc = False
    for flag in ("--locations", "--verbose", "-v"):
        if flag in args:
            show_loc = True
            args.remove(flag)
    if len(args) != 1:
        print("usage: check_tells.py [--locations] <file|-|--self-test>", file=sys.stderr)
        return 2

    src = args[0]
    text = sys.stdin.read() if src == "-" else Path(src).read_text()

    if show_loc:
        hits = locate(text)
        cwidth = max((len(c) for _, _, c, _ in hits), default=0)
        for line, col, cat, snip in hits:
            print(f"{line}:{col}\t{cat.ljust(cwidth)}  {snip}")
        print(f"TOTAL : {len(hits)}")
        return min(len(hits), 255)

    checks = {
        "em_dashes": count_em_dashes(text),
        "curly_quotes": count_curly_quotes(text),
        "ai_vocabulary": count_pattern_list(text, AI_VOCAB),
        "signposting": count_pattern_list(text, SIGNPOSTS),
        "chatbot_artifacts": count_pattern_list(text, CHATBOT),
        "negative_parallelism": count_pattern_list(text, NEG_PARALLEL),
        "filler_phrases": count_pattern_list(text, FILLER),
        "copula_avoidance": count_pattern_list(text, COPULA),
        "authority_tropes": count_pattern_list(text, AUTHORITY),
        "knowledge_cutoff": count_pattern_list(text, KNOWLEDGE_CUTOFF),
        "hedges": count_pattern_list(text, HEDGES),
        "third_person_abstraction": count_pattern_list(text, THIRD_PERSON),
        "bolded_list_headers": count_bolded_list_headers(text),
        "title_case_headings": count_title_case_headings(text),
        "semicolons": count_semicolons(text),
        "rule_of_three": count_rule_of_three(text),
    }

    # Honor inline `<!-- slop-ok: cat -->` allowlists by subtracting suppressed hits.
    allow = _allowlist(text)
    if allow:
        for line, _, cat, _ in locate(text, apply_allowlist=False):
            if cat in checks and _allowed(allow, line, cat):
                checks[cat] = max(0, checks[cat] - 1)

    width = max(len(k) for k in checks)
    total = 0
    for name, count in checks.items():
        if count:
            print(f"{name.ljust(width)} : {count}")
        total += count
    print(f"{'TOTAL'.ljust(width)} : {total}")
    return min(total, 255)


if __name__ == "__main__":
    sys.exit(main())
