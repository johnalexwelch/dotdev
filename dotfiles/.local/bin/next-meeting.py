#!/usr/bin/env python3
"""
next-meeting.py — find the meeting happening now (or starting shortly) and
either join it, open its prep doc, or both.

Reads macOS Calendar.app via icalBuddy. Both your work and personal Google
accounts land there once you enable them in System Settings > Internet
Accounts, so one code path covers both — you never have to open Calendar.app
itself.

Usage:
    next-meeting.py join      open the conference link
    next-meeting.py doc       open the prep doc
    next-meeting.py both      join, then open the doc   (this is the key 3 action)
    next-meeting.py debug     dump what icalBuddy returned and what was parsed

Prep-doc resolution, first hit wins:
    1. a docs.google.com / notion link in the invite notes
    2. a pattern match in meeting-docs.tsv
    3. a Google Drive search pre-filled with the meeting title

WORK vs PERSONAL
----------------
icalBuddy can't label which calendar an event came from in its property list,
so we query each calendar set separately and tag the results:

    export CAL_WORK="<work calendar names>"      # calendar names, comma-separated
    export CAL_PERSONAL="<personal calendar names>"

Find your exact calendar names with:  icalBuddy calendars
Set them in untracked ~/.streamdeck — Stream Deck invokes this script without
an interactive shell, so ~/.zshrc exports never reach it; the script loads
~/.streamdeck itself.

Both sets are merged for `join`. Prep-doc lookup and title display are
restricted to the work set — so a personal appointment is still joinable from
the deck without its title appearing in a macOS notification while you're
screen-sharing.

If neither variable is set, every calendar is treated as work.

Requires: brew install ical-buddy
          System Settings > Internet Accounts > Google > enable Calendars
"""

import os
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

LOOKAHEAD_MIN = 20

# Quoted values take everything inside the quotes; bare values stop at
# whitespace or a trailing "# comment" — an optional-quote backreference
# would silently swallow quotes and comments into the value.
_ENV_RE = re.compile(
    r'^(?:export\s+)?([A-Z_][A-Z0-9_]*)='
    r'(?:"([^"]*)"|\'([^\']*)\'|([^#\s]*))\s*(?:#.*)?$'
)


def _load_streamdeck_env() -> None:
    """Deck presses arrive without an interactive shell, so ~/.zshrc never
    ran — pull CAL_WORK / CAL_PERSONAL / MEETING_DOCS / ICALBUDDY from
    untracked ~/.streamdeck ourselves. Simple KEY=VALUE / export lines only;
    already-set environment always wins."""
    cfg = Path.home() / ".streamdeck"
    if not cfg.exists():
        return
    try:
        lines = cfg.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    for line in lines:
        m = _ENV_RE.match(line.strip())
        if m and m.group(1) in {"CAL_WORK", "CAL_PERSONAL", "MEETING_DOCS", "ICALBUDDY"}:
            value = next(g for g in m.groups()[1:] if g is not None)
            os.environ.setdefault(m.group(1), value)


_load_streamdeck_env()

# Deck presses inherit a minimal PATH — pin it like the sibling scripts so
# the bare-name icalBuddy fallback and subprocess calls resolve.
os.environ["PATH"] = (
    f"{Path.home()}/.local/bin:/opt/homebrew/bin:" + os.environ.get("PATH", "")
)

# The title→doc map holds internal meeting names and URLs, so it lives
# outside the (public) dotfiles repo — see ~/.config/streamdeck/README.md.
MAP_FILE = Path(
    os.environ.get("MEETING_DOCS")
    or Path.home() / ".config" / "streamdeck" / "meeting-docs.tsv"
)

# Homebrew puts this in different places on Apple Silicon vs Intel.
ICALBUDDY = os.environ.get("ICALBUDDY") or next(
    (p for p in ("/opt/homebrew/bin/icalBuddy", "/usr/local/bin/icalBuddy")
     if Path(p).exists()),
    "icalBuddy",
)

EVT = "@@EVT@@"          # bullet, used to split events apart
DOC_RE = re.compile(
    r"https://(?:docs\.google\.com|www\.notion\.so|[a-z0-9.-]*\.notion\.site)/[^\s)>\"'\\]+"
)
# Host-anchored like DOC_RE — an unanchored pattern would let
# https://evil.tld/meet.google.com/x reach `open`.
CONF_RE = re.compile(
    r"https://(?:[a-z0-9-]+\.)*(?:meet\.google\.com|zoom\.us)/[^\s)>\"']+"
)
DATE_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
TIME_RE = re.compile(r"\b(\d{2}:\d{2})\b")


def notify(msg: str, title: str = "Meeting") -> None:
    # Message and title travel as argv, never interpolated into AppleScript
    # source — a calendar-invite title is attacker-controlled text, and an
    # f-string here is an arbitrary-code-execution hole (do shell script).
    subprocess.run(
        ["osascript",
         "-e", "on run argv",
         "-e", "display notification (item 1 of argv) with title (item 2 of argv)",
         "-e", "end run",
         "--", msg, title],
        capture_output=True,
    )


def calendar_sets():
    """[(label, calendar_names_or_None)] — None means 'all calendars'."""
    work = os.environ.get("CAL_WORK", "").strip()
    personal = os.environ.get("CAL_PERSONAL", "").strip()
    if not work and not personal:
        return [("work", None)]
    sets = []
    if work:
        sets.append(("work", work))
    if personal:
        sets.append(("personal", personal))
    return sets


def run_icalbuddy(cals, command):
    cmd = [
        ICALBUDDY,
        "-nc",                    # no calendar name headers
        "-nrd",                   # no "today"/"tomorrow" — give us real dates
        "-b", EVT,                # distinctive bullet so we can split events
        "-df", "%Y-%m-%d",        # deterministic date format
        "-tf", "%H:%M",           # deterministic time format
        "-iep", "title,datetime,url,notes",
    ]
    if cals:
        cmd += ["-ic", cals]
    cmd.append(command)
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except FileNotFoundError:
        notify("icalBuddy not installed — brew install ical-buddy")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        notify("icalBuddy timed out — calendar may still be syncing")
        return ""
    if out.returncode != 0:
        notify((out.stderr or "icalBuddy failed").strip().split("\n")[-1][:100])
        return ""
    return out.stdout


def parse_events(raw, label):
    """
    Turn icalBuddy's text into event dicts.

    Deliberately not parsing into named fields by position — icalBuddy emits
    properties in its own order and notes can span lines. Instead we keep the
    whole chunk as a blob and pull what we need out of it by pattern, which is
    how the URL logic works anyway.
    """
    events = []
    for chunk in raw.split(EVT):
        chunk = chunk.strip()
        if not chunk:
            continue
        lines = [ln.strip() for ln in chunk.splitlines() if ln.strip()]
        if not lines:
            continue
        title = lines[0]

        # Take the start from the first non-title line carrying BOTH a date
        # and a time (with -df/-tf that is the datetime property line).
        # Scanning the whole blob lets a "09:30" in the title beat the real
        # start; accepting a date-less time line lets an all-day event's
        # notes ("agenda 09:00 intro") fabricate a start — which would slip
        # it past the all-day filter in all_events().
        start = None
        for ln in lines[1:]:
            t = TIME_RE.search(ln)
            d = DATE_RE.search(ln)
            if not (t and d):
                continue
            try:
                start = datetime.strptime(
                    f"{d.group(1)} {t.group(1)}", "%Y-%m-%d %H:%M")
            except ValueError:
                start = None
            break

        events.append({
            "title": title,
            "blob": chunk,
            "start": start,
            "_profile": label,
        })
    return events


def all_events():
    """Prefer meetings in progress; otherwise everything left today."""
    now = datetime.now()
    horizon = now + timedelta(minutes=LOOKAHEAD_MIN)

    running, upcoming = [], []
    for label, cals in calendar_sets():
        # All-day events (OOO, focus blocks) are "in progress" all day but
        # have no parseable start — if they counted as running, one of them
        # would disable the lookahead for the whole day.
        running += [
            ev for ev in parse_events(run_icalbuddy(cals, "eventsNow"), label)
            if ev["start"]
        ]
        for ev in parse_events(run_icalbuddy(cals, "eventsToday"), label):
            if ev["start"] and now <= ev["start"] <= horizon:
                upcoming.append(ev)

    return running or upcoming


def pick_event(events):
    if not events:
        return None
    now = datetime.now()
    # None-start events sort LAST — a 0 key here would make an unparsed
    # all-day event beat a meeting starting in five minutes.
    return min(events, key=lambda e: abs((e["start"] - now).total_seconds())
               if e["start"] else float("inf"))


def conference_url(ev):
    m = CONF_RE.search(ev["blob"])
    return m.group(0) if m else None


def work_labels():
    return {label for label, _ in calendar_sets() if label == "work"} or {"work"}


def load_map():
    pairs = []
    if not MAP_FILE.exists():
        return pairs
    for line in MAP_FILE.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#") or "\t" not in line:
            continue
        pattern, url = line.split("\t", 1)
        pattern, url = pattern.strip().lower(), url.strip()
        if pattern and url:
            pairs.append((pattern, url))
    return pairs


def prep_doc_url(ev):
    # Personal events have no prep doc, and running the Drive-search fallback
    # on a personal event title is exactly the wrong behaviour.
    if ev["_profile"] not in work_labels():
        return None

    m = DOC_RE.search(ev["blob"])
    if m:
        return m.group(0)

    title_lc = ev["title"].lower()
    for pattern, url in load_map():
        if pattern in title_lc:
            return url

    notify(f'No mapped doc for "{ev["title"]}" — opening Drive search', "Meeting prep")
    query = re.sub(r"[^A-Za-z0-9 ]", "", ev["title"]).strip().replace(" ", "+")
    return f"https://drive.google.com/drive/search?q={query}"


def safe_title(ev):
    """Never put a non-work title in a notification — you may be screen-sharing."""
    if ev["_profile"] in work_labels():
        return ev["title"]
    return f"your {ev['_profile']} calendar event"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"

    if mode == "debug":
        print(f"icalBuddy : {ICALBUDDY}")
        print(f"cal sets  : {calendar_sets()}\n")
        for label, cals in calendar_sets():
            for cmd in ("eventsNow", "eventsToday"):
                raw = run_icalbuddy(cals, cmd)
                print(f"--- {label} / {cmd} (raw) ---\n{raw or '(empty)'}")
                for ev in parse_events(raw, label):
                    print(f"  parsed: {ev['start']}  {ev['title']!r}"
                          f"  conf={conference_url(ev)}")
        picked = pick_event(all_events())
        print(f"\npicked: {picked['title'] if picked else None}")
        return

    if mode not in {"join", "doc", "both"}:
        print(__doc__)
        sys.exit(2)

    ev = pick_event(all_events())
    if not ev:
        notify("No meeting in the next 20 minutes")
        return

    if mode in {"join", "both"}:
        url = conference_url(ev)
        if url:
            subprocess.run(["open", url])
        else:
            notify(f"No conference link on {safe_title(ev)}")

    if mode in {"doc", "both"}:
        doc = prep_doc_url(ev)
        if doc:
            subprocess.run(["open", doc])
        elif mode == "doc":
            notify(f"No prep doc for {safe_title(ev)}")


if __name__ == "__main__":
    main()
