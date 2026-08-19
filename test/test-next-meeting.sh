#!/usr/bin/env bash
# Hermetic tests for the format-independent layer of next-meeting.py:
# event picking, URL anchoring, map matching, personal-title masking.
# Deliberately NOT a fixture of real icalBuddy output — that layer stays
# unverified until the calendar mirror produces real events (see PR body).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.local/bin/next-meeting.py"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

run_case() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

# Map file with the handoff's collision case: "<> tom" must not hit "Custom".
MAP="$TMPDIR_BASE/meeting-docs.tsv"
printf '# comment\n<> tom\thttps://docs.google.com/document/d/tom\n' >"$MAP"

# HOME is a sandbox so the module's ~/.streamdeck loader reads nothing real.
PYRUN() {
    HOME="$TMPDIR_BASE" MEETING_DOCS="$MAP" CAL_WORK="Work" CAL_PERSONAL="Personal" \
        python3 - "$SCRIPT" "$1" <<'PYEOF'
import importlib.util
import sys
from datetime import datetime, timedelta

spec = importlib.util.spec_from_file_location("nm", sys.argv[1])
nm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nm)
case = sys.argv[2]
now = datetime.now()

# These test the format-independent logic, not macOS notification I/O — stub
# notify() so cases that reach it (e.g. the Drive-search fallback) don't call
# osascript, which is absent on the Linux CI runner. The notify RCE case
# overrides subprocess.run instead and needs the real notify(), so it opts out.
if case != "notify_passes_argv_not_source":
    nm.notify = lambda *a, **k: None

def ev(title, start, profile="work"):
    return {"title": title, "blob": title, "start": start, "_profile": profile}

if case == "pick_prefers_real_start":
    allday = ev("OOO all-day", None)
    soon = ev("Real meeting", now + timedelta(minutes=5))
    assert nm.pick_event([allday, soon])["title"] == "Real meeting"
    assert nm.pick_event([soon, allday])["title"] == "Real meeting"
elif case == "conf_re_anchored":
    ok = ["https://meet.google.com/abc-def", "https://company.zoom.us/j/123"]
    bad = ["https://evil.tld/meet.google.com/x",
           "https://evil.example.com/?redir=zoom.us/j/1",
           "https://zoom.us.evil.tld/j/1"]
    assert all(nm.CONF_RE.search(u) for u in ok)
    assert not any(nm.CONF_RE.search(u) for u in bad)
elif case == "doc_re_anchored":
    assert nm.DOC_RE.search("https://docs.google.com/document/d/x")
    assert not nm.DOC_RE.search("https://evil.tld/docs.google.com/y")
elif case == "map_no_false_match":
    assert nm.prep_doc_url(ev("Custom Report Review", now)).startswith(
        "https://drive.google.com/drive/search")
    assert nm.prep_doc_url(ev("<> Tom weekly", now)) == \
        "https://docs.google.com/document/d/tom"
elif case == "personal_masked":
    p = ev("Therapy", now, profile="personal")
    assert nm.safe_title(p) == "your personal calendar event"
    assert nm.prep_doc_url(p) is None
elif case == "title_time_not_start":
    raw = "@@EVT@@Retro 09:30 recap\n    2026-08-19 at 14:00 - 15:00\n"
    parsed = nm.parse_events(raw, "work")
    assert parsed[0]["start"].hour == 14, parsed[0]["start"]
elif case == "notify_passes_argv_not_source":
    # Pins the RCE fix: a calendar title must travel as an argv element, never
    # be interpolated into the AppleScript source. Reverting notify() to an
    # f-string fails this. We capture the osascript argv instead of running it.
    captured = {}
    nm.subprocess.run = lambda cmd, **kw: captured.setdefault("cmd", cmd)
    payload = 'x" & (do shell script "touch /tmp/pwned") & "'
    nm.notify(payload, "Meeting")
    cmd = captured["cmd"]
    assert cmd[0] == "osascript", cmd
    # The payload must appear verbatim as its own argv element after `--`,
    # and must NOT be embedded inside any `-e` AppleScript source line.
    assert payload in cmd, cmd
    assert "--" in cmd and cmd.index(payload) > cmd.index("--"), cmd
    assert not any(payload in part for part in cmd[: cmd.index("--")]), cmd
elif case == "notes_time_no_start":
    # An all-day event's notes ("agenda 09:00") must not fabricate a start —
    # a truthy start would slip it past the all-day filter in all_events().
    raw = "@@EVT@@All-hands OOO\n    2026-08-19\n    notes: agenda 09:00 intro, 10:30 demo\n"
    parsed = nm.parse_events(raw, "work")
    assert parsed[0]["start"] is None, parsed[0]["start"]
elif case == "env_loader":
    import os
    from pathlib import Path
    (Path(os.environ["HOME"]) / ".streamdeck").write_text(
        'export CAL_WORK="FromFile"\n'
        'CAL_PERSONAL=AlsoFromFile\n'
        'export ICALBUDDY="/opt/x/icalBuddy"  # trailing comment\n'
        'MEETING_DOCS=/bare/path.tsv  # comment on bare value\n')
    for key in ("CAL_WORK", "CAL_PERSONAL", "ICALBUDDY", "MEETING_DOCS"):
        os.environ.pop(key, None)
    nm._load_streamdeck_env()
    assert os.environ["CAL_WORK"] == "FromFile"
    assert os.environ["CAL_PERSONAL"] == "AlsoFromFile"
    assert os.environ["ICALBUDDY"] == "/opt/x/icalBuddy", os.environ["ICALBUDDY"]
    assert os.environ["MEETING_DOCS"] == "/bare/path.tsv", os.environ["MEETING_DOCS"]
else:
    raise SystemExit(f"unknown case {case}")
PYEOF
}

echo "next-meeting.py (format-independent layer)"
run_case "pick_event prefers parseable start over all-day/None" PYRUN pick_prefers_real_start
run_case "CONF_RE is host-anchored (evil prefixes rejected)" PYRUN conf_re_anchored
run_case "DOC_RE stays host-anchored" PYRUN doc_re_anchored
run_case "map: '<> tom' does not false-match 'Custom Report Review'" PYRUN map_no_false_match
run_case "personal events are masked and get no prep doc" PYRUN personal_masked
run_case "time in title does not beat the datetime line" PYRUN title_time_not_start
run_case "notify passes title as argv, never AppleScript source (RCE)" PYRUN notify_passes_argv_not_source
run_case "time in notes does not give an all-day event a start" PYRUN notes_time_no_start
run_case "streamdeck env loader fills unset CAL_* vars" PYRUN env_loader

echo "next-meeting: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
