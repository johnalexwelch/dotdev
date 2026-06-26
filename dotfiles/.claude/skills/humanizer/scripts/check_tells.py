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


def count_title_case_headings(text: str) -> int:
    """ATX headings where 3+ main words are capitalized (likely title case)."""
    hits = 0
    for line in text.splitlines():
        m = re.match(r"^#+\s+(.+?)\s*$", line)
        if not m:
            continue
        words = [w for w in re.findall(r"[A-Za-z][A-Za-z'-]+", m.group(1))]
        if len(words) < 3:
            continue
        # Drop common lowercase function words.
        small = {"a", "an", "the", "and", "or", "but", "for", "of", "in",
                 "on", "to", "with", "vs", "via", "at", "by", "as", "is"}
        content = [w for w in words if w.lower() not in small]
        if len(content) < 3:
            continue
        if sum(1 for w in content if w[0].isupper()) / len(content) >= 0.75:
            hits += 1
    return hits


def count_pattern_list(text: str, patterns: list[str]) -> int:
    return sum(find(p, text) for p in patterns)


def count_rule_of_three(text: str) -> int:
    """Catches inline `X, Y, and Z` patterns. Heuristic — false positives expected."""
    return len(re.findall(
        r"\b[A-Za-z]+,\s+[A-Za-z]+,?\s+and\s+[A-Za-z]+\b", text
    ))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_tells.py <file|->", file=sys.stderr)
        return 2

    src = sys.argv[1]
    text = sys.stdin.read() if src == "-" else Path(src).read_text()

    checks = {
        "em_dashes": count_em_dashes(text),
        "curly_quotes": count_curly_quotes(text),
        "ai_vocabulary": count_pattern_list(text, AI_VOCAB),
        "signposting": count_pattern_list(text, SIGNPOSTS),
        "chatbot_artifacts": count_pattern_list(text, CHATBOT),
        "negative_parallelism": count_pattern_list(text, NEG_PARALLEL),
        "hedges": count_pattern_list(text, HEDGES),
        "third_person_abstraction": count_pattern_list(text, THIRD_PERSON),
        "bolded_list_headers": count_bolded_list_headers(text),
        "title_case_headings": count_title_case_headings(text),
        "rule_of_three": count_rule_of_three(text),
    }

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
