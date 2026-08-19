#!/usr/bin/env python3
"""Rule-3 shell tokenizer for workflow-guard.sh (D-006, PR #174 rebuild).

Reads a full bash command string on stdin. Exit 0 = permit (no suppressed
mutation found). Exit 1 = block (a mutating command has suppressed stderr);
a one-line reason is printed to stdout. Exit 3 = parse/internal error,
which the caller (workflow-guard.sh) must treat as FAIL CLOSED.

DECLARED BOUNDARY (verbatim in spirit; do not narrow or widen silently):

    Rule 3 sees a mutation only when its text sits as LITERAL
    (expansion-free) text in command position, in the same scope-chain as
    the suppression. Any mechanism that carries command text across that
    boundary -- name binding (aliases, functions, a script invoked by
    name), parameter expansion, eval of a variable, a here-document body,
    a file read at runtime -- is out of scope and FAILS OPEN.
    Tokenizer/parse errors FAIL CLOSED (block).

    "Literal (expansion-free)" is a round-1 fail-closed REFINEMENT of the
    original "unquoted" criterion (security lane, High): quoting that does
    not change the execve -- ``\\git push``, ``git "push"``, ``""git push``
    -- must not blind the detector, so words are judged by their
    quote-removed literal value, exactly as redirect targets already were
    (the reason ``2>"/dev/null"`` blocks). Only a word carrying an
    expansion segment has no knowable value and is disqualified. A quoted
    MENTION still permits because its value is one multi-word string
    ("git push origin main"), which can never equal the single word "git".
    Command names are also compared by basename, so ``/usr/bin/git push``
    and ``./git push`` are recognized (the boundary's name-binding items
    all share the property that the mutation text is absent or
    runtime-determined, which a path prefix is not).

This module is a hand-rolled lexer + recursive-descent parser + fd-state
walker, python3 stdlib only. No shell is invoked; nothing here executes the
command under test.

DESIGN NOTES (why, not just what):

* fd-state model: a single mutable ``persistent`` dict per "shell level"
  (top-level shell, or a fresh one per subshell / command substitution /
  isolated ``-c`` recursion) represents the shell's REAL fd table --
  touched only by an actual ``exec`` redirect, never automatically
  reverted. A list of ``overlays`` (each one enclosing construct's own
  redirect list) is re-applied on top of a *fresh copy* of ``persistent``
  every time we need the "effective" fd state for a command. Because a
  construct's own redirect list (``{ ...; } 2>/dev/null``) lives only in
  the overlay chain and is never written into ``persistent``, it can never
  leak past the construct -- while a real ``exec`` writes directly into
  ``persistent`` (after resolving dup sources against the *overlaid*
  effective view, so ``exec 2>&1`` inside an already-redirected construct
  dups the correct, currently-visible fd), so its effect always leaks out
  of brace groups / if / for / while (which share the same ``persistent``
  object) but never out of a subshell / command substitution / isolated
  ``bash -c`` (each of which starts a fresh ``persistent`` copy).

* Conservative choices, each named where a maintainer would otherwise
  wonder why: (1) ``exec`` with a command word still mutates ``persistent``
  even though real bash would replace the process and never reach later
  commands -- kept because "nothing after this ever runs" is not provable
  lexically, and dropping the mutation would fail open on the exact shape
  main already blocked. (2) A command substitution's / backtick's initial
  scope is the ENCLOSING command's effective POST-REDIRECT state (not its
  pre-redirect state) -- a mutation textually inside ``$( ... )`` under an
  outer suppression blocks, matching the pinned matrix behavior. (3) A
  function body is parsed and walked IN PLACE, at its definition site,
  using whatever scope is active at that point -- never linked to any
  later invocation. This is deliberately conservative (it can only ever
  see suppression that was already active AT THE DEFINITION), not a
  best-effort call-graph analysis; connecting a call site's suppression to
  a function body is name-binding indirection and stays out of scope by
  design (see N14 in test-guard-rules.sh).

* Recovery WITHIN a construct, fail-closed at the top: an unterminated
  quote reads to end-of-input as a literal word, and a missing construct
  terminator is tolerated by stopping the enclosing list -- but any
  NON-BLANK INPUT LEFT OVER after the top-level parse raises
  ``TokenizerError`` (exit 3, fail closed). A silently truncated parse
  would permit everything after the truncation point (round-1 logic lane);
  the leftover check retires that class. Measured safe: a realistic
  delivery corpus produces zero leftovers, so ordinary commands never
  error.

* Compound dispatch (audited against bash's compound-command grammar,
  round-1 tests lane): RECOGNIZED as constructs -- subshell ``( )``, brace
  group ``{ }``, ``if``/``elif``/``else``/``fi``, ``for``/``select``
  (shared arm; both are ``[in words]; do body done``), ``while``/``until``,
  ``case``/``esac``, arithmetic command ``(( ))`` (with the subshell
  backtrack below), posix ``name()`` and ``function name [()]``
  definitions (one shared code path, so definition-site redirects walk the
  body identically). TREATED AS ORDINARY WORDS -- ``[[ ]]`` (its content
  is a conditional expression, not commands; a redirect on it still
  attaches to the statement) and ``coproc`` (a prefix word; the command
  after it is scanned by the any-position mutation matcher anyway).

* Arithmetic backtrack (round-1 security lane High; ``$((`` capture fixed
  in round 2): bash backtracks a failed arithmetic parse to a NESTED
  SUBSHELL, so ``((cmd) redirect)`` and ``$((cmd) redirect)`` really
  execute. Both spellings are captured the same way -- consume one paren,
  scan the OUTER paren at depth 1, keep the body VERBATIM as the
  subshell reading (a fixed two-char strip is only correct when the
  closers are adjacent; on a backtracked span it severed the redirect) --
  and any span whose closers are non-adjacent or whose arithmetic content
  carries an unquoted ``)`` gets an ADDITIVE second reading as that
  subshell (parse errors from the re-read are discarded; it can only ever
  add a block, never a permit). Genuine nested-paren arithmetic finds no
  mutation in the second reading and stays permitted.

* ``|&`` (round-1 logic lane): the implicit ``2>&1`` lands AFTER the
  node's own redirect list (bash manual), so a piped-to-``|&`` node's
  effective fd2 is PIPE (visible) even when its own redirects nulled it --
  while commands nested INSIDE such a construct keep their own private
  suppression.
"""

from __future__ import annotations

import re
import sys


class TokenizerError(Exception):
    """Internal error -> the caller maps this to exit 3 (fail closed)."""


# --------------------------------------------------------------------------
# Word: a lexical word, built from literal / quoted / expansion segments.
# --------------------------------------------------------------------------

EXPANSION_KINDS = frozenset(
    {"cmdsub", "backtick", "arith", "paramexp", "procsub_in", "procsub_out"}
)
RECURSABLE_KINDS = frozenset({"cmdsub", "backtick", "procsub_in", "procsub_out"})


class Word:
    __slots__ = ("segs", "quoted_any", "has_expansion")

    def __init__(self):
        self.segs = []  # list[(kind, text)]
        self.quoted_any = False
        self.has_expansion = False

    def add_lit(self, text):
        self.segs.append(("lit", text))

    def add_expansion(self, kind, text):
        self.segs.append((kind, text))
        self.has_expansion = True

    def literal_value(self):
        """Quote-removed literal text, or None if any expansion is present."""
        if self.has_expansion:
            return None
        return "".join(text for _, text in self.segs)

    def is_empty(self):
        return not self.segs

    def is_bare_dash(self):
        return self.literal_value() == "-"

    def is_bare_digits(self):
        v = self.literal_value()
        if v is not None and v.isdigit():
            return int(v)
        return None



# --------------------------------------------------------------------------
# Scanner: character-level cursor shared by lexing and parsing.
# --------------------------------------------------------------------------

WORD_TERMINATOR_CHARS = " \t\n&|;()"


class Scanner:
    def __init__(self, s):
        self.s = s
        self.i = 0
        self.n = len(s)
        self.pending_heredocs = []  # list[(delimiter, strip_tabs)]
        self.depth_guard = 0

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if 0 <= j < self.n else ""

    def at_end(self):
        return self.i >= self.n

    def skip_blanks(self):
        while True:
            advanced = False
            while self.i < self.n and self.s[self.i] in " \t":
                self.i += 1
                advanced = True
            if self.peek() == "\\" and self.peek(1) == "\n":
                self.i += 2
                advanced = True
            if not advanced:
                break

    def skip_blanks_and_comments(self):
        while True:
            self.skip_blanks()
            if self.peek() == "#":
                while self.i < self.n and self.s[self.i] != "\n":
                    self.i += 1
                continue
            break

    def peek_keyword(self, *keywords):
        for kw in sorted(keywords, key=len, reverse=True):
            end = self.i + len(kw)
            if self.s[self.i:end] == kw:
                nxt = self.s[end] if end < self.n else ""
                if nxt == "" or not (nxt.isalnum() or nxt in "_-"):
                    return kw
        return None

    def consume_newline_and_heredocs(self):
        assert self.s[self.i] == "\n"
        self.i += 1
        if self.pending_heredocs:
            pending = self.pending_heredocs
            self.pending_heredocs = []
            for delim, strip_tabs in pending:
                self._consume_heredoc_body(delim, strip_tabs)

    def _consume_heredoc_body(self, delim, strip_tabs):
        while self.i < self.n:
            nl = self.s.find("\n", self.i)
            line_end = nl if nl != -1 else self.n
            line = self.s[self.i:line_end]
            check_line = line.lstrip("\t") if strip_tabs else line
            self.i = (nl + 1) if nl != -1 else self.n
            if check_line == delim:
                return
        # Unterminated heredoc: recover, body consumed to EOF.

    # --- balanced-span scanning, quote-aware ------------------------------

    def _skip_quote_or_escape(self):
        """If positioned on a quote/backslash, consume the whole span and
        return True. Otherwise return False (caller advances one char)."""
        c = self.s[self.i]
        if c == "\\" and self.i + 1 < self.n:
            self.i += 2
            return True
        if c == "'":
            self.i += 1
            j = self.s.find("'", self.i)
            self.i = (j + 1) if j != -1 else self.n
            return True
        if c == '"':
            self.i += 1
            while self.i < self.n:
                cc = self.s[self.i]
                if cc == "\\" and self.i + 1 < self.n:
                    self.i += 2
                    continue
                if cc == '"':
                    self.i += 1
                    break
                self.i += 1
            return True
        return False

    def scan_balanced_parens(self, initial_depth):
        """Scans forward, quote-aware AND comment-aware, counting only
        unquoted '(' / ')', until depth returns to 0. A '#' at word start
        (start-of-scan, or preceded by blank/operator) opens a comment to
        end-of-line whose parens do not count -- so `$(echo hi # note )`
        parses to the real closer instead of truncating at the commented
        one (round-1 logic lane). Strips exactly `initial_depth` trailing
        close-parens from the returned content (the structural closers
        that brought depth to 0) -- e.g. depth=2 for `$((...))` strips the
        final `))`, depth=1 for `$(...)`/`<(...)` strips the final `)`.
        On unterminated input (EOF before depth hits 0), recovers by
        returning everything consumed with nothing stripped."""
        start = self.i
        depth = initial_depth
        while self.i < self.n and depth > 0:
            c = self.s[self.i]
            if c == "#":
                prev = self.s[self.i - 1] if self.i > start else ""
                if prev == "" or prev in " \t\n;&|(":
                    nl = self.s.find("\n", self.i)
                    self.i = nl if nl != -1 else self.n
                    continue
            if self._skip_quote_or_escape():
                continue
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            self.i += 1
        if depth > 0:
            return self.s[start:self.i]
        return self.s[start:self.i - initial_depth]

    def scan_balanced_braces(self, initial_depth):
        """Same as scan_balanced_parens but for '{' / '}' (parameter
        expansion `${...}`); parens inside are irrelevant to termination."""
        start = self.i
        depth = initial_depth
        while self.i < self.n and depth > 0:
            if self._skip_quote_or_escape():
                continue
            c = self.s[self.i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            self.i += 1
        if depth > 0:
            return self.s[start:self.i]
        return self.s[start:self.i - initial_depth]

    # --- $ / ` expansion consumption (shared by unquoted and dquoted runs)

    def consume_dollar(self, word):
        """self.s[self.i] == '$'. Consumes one expansion form, recording it
        onto `word`. Bare $VAR / $$ / $? etc. are treated as opaque data
        (paramexp) -- we never need the variable name, only the fact that
        an expansion is present."""
        if self.peek(1) == "(" and self.peek(2) == "(":
            # Capture the span the way _parse_arith_command does: consume
            # only '$(' and scan the OUTER paren at depth 1, keeping the
            # body verbatim as the nested-subshell reading (`$(( X ))` ==
            # `$( ( X ) )`). A fixed depth-2 read stripping two trailing
            # characters is only correct when the closers are adjacent --
            # on a backtracked span it truncated the payload mid-token and
            # severed the redirect, so the additive re-read saw a mutation
            # with no suppression (round-2 security lane, High). The
            # genuine-arithmetic interpretation needs no content at all
            # (data); the walker gates the additive subshell re-read on
            # _arith_content_has_close_paren.
            self.i += 2
            body = self.scan_balanced_parens(1)
            word.add_expansion("arith", body)
            return
        if self.peek(1) == "(":
            self.i += 2
            content = self.scan_balanced_parens(1)
            word.add_expansion("cmdsub", content)
            return
        if self.peek(1) == "{":
            self.i += 2
            content = self.scan_balanced_braces(1)
            word.add_expansion("paramexp", content)
            return
        if self.peek(1) == "'":
            # ANSI-C quoted string $'...': data, but a genuine quoted span.
            self.i += 2
            start = self.i
            while self.i < self.n:
                c = self.s[self.i]
                if c == "\\" and self.i + 1 < self.n:
                    self.i += 2
                    continue
                if c == "'":
                    break
                self.i += 1
            content = self.s[start:self.i]
            if self.i < self.n:
                self.i += 1
            word.add_lit(content)
            word.quoted_any = True
            return
        if self.peek(1) == '"':
            # Locale-translated string $"...": treat like a double-quoted
            # span (same expansions can occur inside).
            self.i += 2
            self.read_dquote_body(word)
            word.quoted_any = True
            return
        # Bare $name / $$ / $? / $# / $@ / $* / $N -- opaque data.
        self.i += 1
        j = self.i
        if j < self.n and (self.s[j].isalpha() or self.s[j] == "_"):
            while j < self.n and (self.s[j].isalnum() or self.s[j] == "_"):
                j += 1
        elif j < self.n and self.s[j].isdigit():
            j += 1
        elif j < self.n and self.s[j] in "@*#?$!-":
            j += 1
        name = self.s[self.i:j]
        self.i = j
        word.add_expansion("paramexp", name)

    def consume_backtick(self, word):
        assert self.s[self.i] == "`"
        self.i += 1
        start = self.i
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\" and self.i + 1 < self.n:
                self.i += 2
                continue
            if c == "`":
                content = self.s[start:self.i]
                self.i += 1
                word.add_expansion("backtick", content)
                return
            self.i += 1
        word.add_expansion("backtick", self.s[start:self.i])

    # --- double-quoted body ------------------------------------------------

    def read_dquote_body(self, word):
        """self.i is positioned right after the opening '"'. Consumes up to
        (and past) the matching unescaped '"', appending literal/expansion
        segments onto `word`. Inside double quotes, backslash escapes only
        $, `, ", \\, and newline (POSIX); any other backslash is literal."""
        word.quoted_any = True
        buf = []

        def flush():
            if buf:
                word.add_lit("".join(buf))
                buf.clear()

        while self.i < self.n:
            c = self.s[self.i]
            if c == '"':
                self.i += 1
                flush()
                return
            if c == "\\":
                nxt = self.peek(1)
                if nxt in ('$', "`", '"', "\\"):
                    buf.append(nxt)
                    self.i += 2
                    continue
                if nxt == "\n":
                    self.i += 2
                    continue
                if nxt == "":
                    buf.append("\\")
                    self.i += 1
                    continue
                buf.append("\\")
                buf.append(nxt)
                self.i += 2
                continue
            if c == "$":
                flush()
                self.consume_dollar(word)
                continue
            if c == "`":
                flush()
                self.consume_backtick(word)
                continue
            buf.append(c)
            self.i += 1
        # Unterminated double quote: recover, rest of input is literal.
        flush()

    # --- word reading --------------------------------------------------

    def read_word(self):
        """Reads one word at the current position, or returns None if no
        word starts here (blank/newline/operator-metachar/EOF). Unquoted
        '<' and '>' are metacharacters that terminate the word wherever
        they occur -- EXCEPT '<(' / '>(' at the very start of a fresh word,
        which is process substitution."""
        word = Word()
        started = False
        buf = []

        def flush():
            if buf:
                word.add_lit("".join(buf))
                buf.clear()

        while self.i < self.n:
            c = self.s[self.i]
            if c in " \t\n":
                break
            if c in "&|;":
                break
            if c in "<>":
                if not started and self.peek(1) == "(":
                    kind = "procsub_in" if c == "<" else "procsub_out"
                    self.i += 2
                    content = self.scan_balanced_parens(1)
                    word.add_expansion(kind, content)
                    started = True
                    continue
                break
            if c in "()":
                break
            if c == "#" and not started:
                break
            if c == "\\":
                nxt = self.peek(1)
                if nxt == "\n":
                    self.i += 2
                    continue
                if nxt == "":
                    buf.append("\\")
                    self.i += 1
                    started = True
                    continue
                flush()
                word.add_lit(nxt)
                word.quoted_any = True
                self.i += 2
                started = True
                continue
            if c == "'":
                self.i += 1
                j = self.s.find("'", self.i)
                if j == -1:
                    content = self.s[self.i:]
                    self.i = self.n
                else:
                    content = self.s[self.i:j]
                    self.i = j + 1
                flush()
                word.add_lit(content)
                word.quoted_any = True
                started = True
                continue
            if c == '"':
                self.i += 1
                flush()
                self.read_dquote_body(word)
                started = True
                continue
            if c == "$":
                flush()
                self.consume_dollar(word)
                started = True
                continue
            if c == "`":
                flush()
                self.consume_backtick(word)
                started = True
                continue
            buf.append(c)
            self.i += 1
            started = True
        flush()
        if not started:
            return None
        return word


# --------------------------------------------------------------------------
# Redirect: one [n]OP target entry on a simple command or construct.
# --------------------------------------------------------------------------


class Redirect:
    __slots__ = ("fd", "op", "target")

    def __init__(self, fd, op, target):
        self.fd = fd  # int
        self.op = op  # '<' '<>' '<&' '<<' '<<-' '<<<' '>' '>>' '>|' '>&' '&>' '&>>'
        self.target = target  # Word or None (heredoc has no target word)

    def touched_fds(self):
        if self.op in ("&>", "&>>"):
            return (1, 2)
        return (self.fd,)


def try_read_redirect(sc):
    """Attempts to read one redirect at the current position. Returns a
    Redirect, or None (and does not advance) if there isn't one here."""
    i0 = sc.i
    j = i0
    while j < sc.n and sc.s[j].isdigit():
        j += 1
    has_digits = j > i0

    if not has_digits and sc.peek() == "&":
        if sc.peek(1) == ">" and sc.peek(2) == ">":
            sc.i = i0 + 3
            target = read_redirect_target(sc)
            return Redirect(1, "&>>", target)
        if sc.peek(1) == ">":
            sc.i = i0 + 2
            target = read_redirect_target(sc)
            return Redirect(1, "&>", target)
        return None

    if has_digits:
        c0 = sc.s[j] if j < sc.n else ""
        if c0 not in ("<", ">"):
            return None
        fd = int(sc.s[i0:j])
    else:
        if sc.peek() not in ("<", ">"):
            return None
        fd = None
        j = i0

    c = sc.s[j]
    c1 = sc.s[j + 1] if j + 1 < sc.n else ""
    c2 = sc.s[j + 2] if j + 2 < sc.n else ""
    if c == "<" and c1 == "<" and c2 == "-":
        op, oplen = "<<-", 3
    elif c == "<" and c1 == "<" and c2 == "<":
        op, oplen = "<<<", 3
    elif c == "<" and c1 == "<":
        op, oplen = "<<", 2
    elif c == "<" and c1 == ">":
        op, oplen = "<>", 2
    elif c == "<" and c1 == "&":
        op, oplen = "<&", 2
    elif c == "<":
        op, oplen = "<", 1
    elif c == ">" and c1 == ">":
        op, oplen = ">>", 2
    elif c == ">" and c1 == "|":
        op, oplen = ">|", 2
    elif c == ">" and c1 == "&":
        op, oplen = ">&", 2
    elif c == ">":
        op, oplen = ">", 1
    else:
        return None

    sc.i = j + oplen

    if op in ("<<", "<<-"):
        sc.skip_blanks()
        delim_word = sc.read_word()
        delim_text = delim_word.literal_value() if delim_word else ""
        if delim_text is None:
            delim_text = ""
        sc.pending_heredocs.append((delim_text, op == "<<-"))
        return Redirect(fd if fd is not None else 0, op, None)

    target = read_redirect_target(sc)
    if op in ("<<<",):
        return Redirect(fd if fd is not None else 0, op, target)
    if op in (">&", "<&"):
        # Digit-less `>&word` is bash's legacy synonym of `&>word` (both
        # streams to the file) whenever the operand is NOT purely numeric
        # and not `-`; a numeric operand stays an fd-dup (`>&2`) and `-`
        # stays a close (round-1 tests lane; the `>&2` discriminator pin).
        # An expansion-bearing operand stays a dup-of-UNKNOWN -- visible
        # either way, fail-open within the boundary. An explicit fd
        # (`2>&1`) is never the synonym.
        if op == ">&" and fd is None and target is not None:
            lit = target.literal_value()
            if lit is not None and not lit.isdigit() and lit != "-":
                return Redirect(1, "&>", target)
        default_fd = 1 if op == ">&" else 0
        return Redirect(fd if fd is not None else default_fd, op, target)
    default_fd = 0 if c == "<" else 1
    return Redirect(fd if fd is not None else default_fd, op, target)


def read_redirect_target(sc):
    sc.skip_blanks()
    return sc.read_word()


# --------------------------------------------------------------------------
# AST nodes. Deliberately minimal -- only what the walker needs.
# --------------------------------------------------------------------------


class SimpleCommand:
    __slots__ = ("assignments", "words", "redirects")

    def __init__(self, assignments, words, redirects):
        self.assignments = assignments
        self.words = words
        self.redirects = redirects


class Pipeline:
    __slots__ = ("commands", "ops")

    def __init__(self, commands, ops):
        self.commands = commands  # list of command/construct nodes
        self.ops = ops  # '|' or '|&' between consecutive commands


class AndOr:
    __slots__ = ("pipelines", "ops")

    def __init__(self, pipelines, ops):
        self.pipelines = pipelines
        self.ops = ops  # '&&' or '||'


class CommandList:
    __slots__ = ("items",)

    def __init__(self, items):
        self.items = items  # list[AndOr]


class Subshell:
    __slots__ = ("body", "redirects")

    def __init__(self, body, redirects):
        self.body = body
        self.redirects = redirects


class BraceGroup:
    __slots__ = ("body", "redirects")

    def __init__(self, body, redirects):
        self.body = body
        self.redirects = redirects


class ForLoop:
    __slots__ = ("body", "redirects", "header_words")

    def __init__(self, body, redirects, header_words=()):
        self.body = body
        self.redirects = redirects
        # for/select header words (loop variable, `in` list): their
        # substitutions are command text in the enclosing scope and must be
        # walked, not discarded (round-1 logic lane finding 2).
        self.header_words = header_words


class WhileUntil:
    __slots__ = ("cond", "body", "redirects")

    def __init__(self, cond, body, redirects):
        self.cond = cond
        self.body = body
        self.redirects = redirects


class IfNode:
    __slots__ = ("branches", "redirects")

    def __init__(self, branches, redirects):
        self.branches = branches  # list[(cond_or_None, body)]
        self.redirects = redirects


class CaseNode:
    __slots__ = ("arms", "redirects", "header_words")

    def __init__(self, arms, redirects, header_words=()):
        self.arms = arms  # list[CommandList] (bodies only; patterns unused)
        self.redirects = redirects
        # The case subject word -- walked like any other word (round-1
        # logic lane finding 2).
        self.header_words = header_words


class ArithCommand:
    __slots__ = ("redirects", "subshell_text", "backtrack")

    def __init__(self, redirects, subshell_text="", backtrack=False):
        self.redirects = redirects
        # The nested-subshell reading of the span (`(( X ))` re-read as
        # `( ( X ) )` -- subshell_text is the outer subshell's body). When
        # `backtrack` is set (the arithmetic content carries an unquoted
        # `)`, so bash may have backtracked a failed arithmetic parse to a
        # nested subshell), the walker gives the span an ADDITIVE second
        # reading as that subshell (round-1 security lane finding 2).
        self.subshell_text = subshell_text
        self.backtrack = backtrack


class FunctionDef:
    __slots__ = ("name", "body", "redirects")

    def __init__(self, name, body, redirects):
        self.name = name
        self.body = body
        self.redirects = redirects


FUNC_DEF_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*[ \t]*\(\)")
ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")


class Parser:
    MAX_NODES = 20000  # recursion/size guard -> TokenizerError -> fail closed

    def __init__(self, text):
        self.sc = Scanner(text)
        self.node_budget = Parser.MAX_NODES

    def _spend(self):
        self.node_budget -= 1
        if self.node_budget <= 0:
            raise TokenizerError("parser node budget exceeded")

    def parse_program(self):
        body = self.parse_command_list()
        sc = self.sc
        # Non-blank leftover input means the parse silently stopped early
        # (stray `)`, `;;`, unattached keyword). Everything past that point
        # would be unexamined, so fail CLOSED instead of permitting it
        # (round-1 logic lane finding 3).
        while True:
            sc.skip_blanks_and_comments()
            if not sc.at_end() and sc.peek() == "\n":
                sc.consume_newline_and_heredocs()
                continue
            break
        if not sc.at_end():
            raise TokenizerError(
                "unparsed trailing input at offset %d: %r"
                % (sc.i, sc.s[sc.i:sc.i + 40])
            )
        return body

    # --- lists / pipelines / and-or --------------------------------------

    def parse_command_list(self, stop_keywords=frozenset()):
        sc = self.sc
        items = []
        while True:
            sc.skip_blanks_and_comments()
            if sc.at_end():
                break
            c = sc.peek()
            if c == "\n":
                sc.consume_newline_and_heredocs()
                continue
            if c == ";" and sc.peek(1) == ";":
                break
            if c == ";":
                sc.i += 1
                continue
            if c == ")":
                break
            if c == "&" and sc.peek(1) != "&":
                sc.i += 1
                continue
            if stop_keywords and sc.peek_keyword(*stop_keywords):
                break
            self._spend()
            node = self.parse_and_or()
            if node is None:
                break
            items.append(node)
        return CommandList(items)

    def parse_and_or(self):
        sc = self.sc
        first = self.parse_pipeline()
        pipelines = [first]
        ops = []
        while True:
            sc.skip_blanks_and_comments()
            if sc.peek() == "&" and sc.peek(1) == "&":
                ops.append("&&")
                sc.i += 2
            elif sc.peek() == "|" and sc.peek(1) == "|":
                ops.append("||")
                sc.i += 2
            else:
                break
            sc.skip_blanks_and_comments()
            while sc.peek() == "\n":
                sc.consume_newline_and_heredocs()
                sc.skip_blanks_and_comments()
            pipelines.append(self.parse_pipeline())
        return AndOr(pipelines, ops)

    def parse_pipeline(self):
        sc = self.sc
        while True:
            sc.skip_blanks_and_comments()
            kw = sc.peek_keyword("!", "time")
            if kw == "!":
                sc.i += 1
                continue
            if kw == "time":
                sc.i += 4
                sc.skip_blanks_and_comments()
                if sc.peek() == "-" and sc.peek(1) == "p":
                    sc.i += 2
                continue
            break
        commands = []
        ops = []
        while True:
            self._spend()
            cmd = self.parse_command_or_construct()
            if cmd is None:
                break
            commands.append(cmd)
            sc.skip_blanks_and_comments()
            if sc.peek() == "|" and sc.peek(1) == "&":
                ops.append("|&")
                sc.i += 2
                continue
            if sc.peek() == "|":
                ops.append("|")
                sc.i += 1
                continue
            break
        return Pipeline(commands, ops)

    # --- one command (simple or compound) --------------------------------

    def parse_command_or_construct(self):
        sc = self.sc
        sc.skip_blanks_and_comments()
        if sc.at_end():
            return None
        c = sc.peek()
        if c in ")\n;":
            return None
        if c == "(":
            if sc.peek(1) == "(":
                return self._parse_arith_command()
            return self._parse_subshell()
        kw = sc.peek_keyword(
            "if", "for", "select", "while", "until", "case", "function", "{"
        )
        if kw == "if":
            return self._parse_if()
        if kw == "for":
            return self._parse_for(kwlen=3)
        if kw == "select":
            # `select name [in words]; do body; done` is structurally a
            # for-loop (round-1 tests lane Must-fix): same header shape,
            # same done-redirect coverage of the body.
            return self._parse_for(kwlen=6)
        if kw in ("while", "until"):
            return self._parse_while(until=(kw == "until"))
        if kw == "case":
            return self._parse_case()
        if kw == "function":
            return self._parse_function_keyword()
        if kw == "{":
            return self._parse_brace_group()
        m = FUNC_DEF_RE.match(sc.s, sc.i)
        if m:
            name = m.group(0)
            paren = name.index("(")
            name = name[:paren].rstrip()
            sc.i = m.end()
            return self._finish_function_def(name)
        return self.parse_simple_command()

    def _parse_function_keyword(self):
        """`function name { body }` / `function name() { body }` -- the
        bash keyword spelling. Shares _finish_function_def with the posix
        `name()` form so definition-site redirects walk the body
        identically (round-1 tests lane)."""
        sc = self.sc
        sc.i += 8  # 'function'
        sc.skip_blanks_and_comments()
        name_word = sc.read_word()
        name = name_word.literal_value() if name_word else None
        if name is None:
            name = ""
        sc.skip_blanks_and_comments()
        if sc.peek() == "(" and sc.peek(1) == ")":
            sc.i += 2
        return self._finish_function_def(name)

    def _finish_function_def(self, name):
        sc = self.sc
        sc.skip_blanks_and_comments()
        while sc.peek() == "\n":
            sc.consume_newline_and_heredocs()
            sc.skip_blanks_and_comments()
        body = self.parse_command_or_construct()
        redirects = self._read_trailing_redirects()
        return FunctionDef(name, body, redirects)

    def _read_trailing_redirects(self):
        sc = self.sc
        redirects = []
        while True:
            sc.skip_blanks_and_comments()
            r = try_read_redirect(sc)
            if r is None:
                break
            redirects.append(r)
        return redirects

    def parse_simple_command(self):
        sc = self.sc
        assignments = []
        words = []
        redirects = []
        while True:
            sc.skip_blanks_and_comments()
            if sc.at_end():
                break
            ch = sc.peek()
            if ch == "(":
                break
            if ch in "\n;|)":
                break
            # '&' must be offered to try_read_redirect first: it may be the
            # start of '&>' / '&>>' rather than a job-control/list operator.
            r = try_read_redirect(sc)
            if r is not None:
                redirects.append(r)
                continue
            if ch == "&":
                break
            word = sc.read_word()
            if word is None:
                break
            if not words and _is_assignment_word(word):
                if sc.peek() == "(":
                    sc.i += 1
                    sc.scan_balanced_parens(1)
                assignments.append(word)
                continue
            words.append(word)
        return SimpleCommand(assignments, words, redirects)

    # --- compound constructs ---------------------------------------------

    def _parse_subshell(self):
        sc = self.sc
        sc.i += 1
        body = self.parse_command_list()
        sc.skip_blanks_and_comments()
        if sc.peek() == ")":
            sc.i += 1
        redirects = self._read_trailing_redirects()
        return Subshell(body, redirects)

    def _parse_brace_group(self):
        sc = self.sc
        sc.i += 1
        body = self.parse_command_list(stop_keywords=frozenset({"}"}))
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("}"):
            sc.i += 1
        redirects = self._read_trailing_redirects()
        return BraceGroup(body, redirects)

    def _parse_arith_command(self):
        sc = self.sc
        # Consume only the FIRST '(' and scan from the second with depth 1:
        # that yields exactly the outer subshell's body under the
        # backtracked reading (`(( X ))` == `( ( X ) )`), and it ends at
        # the same closer the plain depth-2 arithmetic scan would.
        sc.i += 1
        subshell_text = sc.scan_balanced_parens(1)
        redirects = self._read_trailing_redirects()
        backtrack = _arith_content_has_close_paren(subshell_text)
        return ArithCommand(redirects, subshell_text, backtrack)

    def _parse_for(self, kwlen=3):
        sc = self.sc
        sc.i += kwlen  # 'for' or 'select'
        header_words = []
        sc.skip_blanks_and_comments()
        if sc.peek() == "(" and sc.peek(1) == "(":
            sc.i += 2
            sc.scan_balanced_parens(2)
        else:
            var_word = sc.read_word()  # loop variable name
            if var_word is not None:
                header_words.append(var_word)
            sc.skip_blanks_and_comments()
            if sc.peek_keyword("in"):
                sc.i += 2
                while True:
                    sc.skip_blanks_and_comments()
                    if sc.at_end() or sc.peek() in ";\n":
                        break
                    if sc.peek_keyword("do"):
                        break
                    w = sc.read_word()
                    if w is None:
                        break
                    header_words.append(w)
        while True:
            sc.skip_blanks_and_comments()
            if sc.peek() == ";":
                sc.i += 1
                continue
            if sc.peek() == "\n":
                sc.consume_newline_and_heredocs()
                continue
            break
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("do"):
            sc.i += 2
        body = self.parse_command_list(stop_keywords=frozenset({"done"}))
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("done"):
            sc.i += 4
        redirects = self._read_trailing_redirects()
        return ForLoop(body, redirects, header_words)

    def _parse_while(self, until):
        sc = self.sc
        sc.i += 5  # len('while') == len('until') == 5
        cond = self.parse_command_list(stop_keywords=frozenset({"do"}))
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("do"):
            sc.i += 2
        body = self.parse_command_list(stop_keywords=frozenset({"done"}))
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("done"):
            sc.i += 4
        redirects = self._read_trailing_redirects()
        return WhileUntil(cond, body, redirects)

    def _parse_if(self):
        sc = self.sc
        sc.i += 2  # 'if'
        branches = []
        cond = self.parse_command_list(stop_keywords=frozenset({"then"}))
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("then"):
            sc.i += 4
        body = self.parse_command_list(
            stop_keywords=frozenset({"elif", "else", "fi"})
        )
        branches.append((cond, body))
        while True:
            sc.skip_blanks_and_comments()
            kw = sc.peek_keyword("elif", "else", "fi")
            if kw == "elif":
                sc.i += 4
                c2 = self.parse_command_list(stop_keywords=frozenset({"then"}))
                sc.skip_blanks_and_comments()
                if sc.peek_keyword("then"):
                    sc.i += 4
                b2 = self.parse_command_list(
                    stop_keywords=frozenset({"elif", "else", "fi"})
                )
                branches.append((c2, b2))
                continue
            if kw == "else":
                sc.i += 4
                b3 = self.parse_command_list(stop_keywords=frozenset({"fi"}))
                branches.append((None, b3))
                sc.skip_blanks_and_comments()
                if sc.peek_keyword("fi"):
                    sc.i += 2
                break
            if kw == "fi":
                sc.i += 2
                break
            break
        redirects = self._read_trailing_redirects()
        return IfNode(branches, redirects)

    def _parse_case(self):
        sc = self.sc
        sc.i += 4  # 'case'
        sc.skip_blanks_and_comments()
        subject = sc.read_word()
        header_words = [subject] if subject is not None else []
        sc.skip_blanks_and_comments()
        if sc.peek_keyword("in"):
            sc.i += 2
        arms = []
        while True:
            sc.skip_blanks_and_comments()
            if sc.peek_keyword("esac"):
                sc.i += 4
                break
            if sc.at_end():
                break
            if sc.peek() == "(":
                sc.i += 1
                sc.skip_blanks_and_comments()
            while True:
                sc.read_word()
                sc.skip_blanks_and_comments()
                if sc.peek() == "|":
                    sc.i += 1
                    sc.skip_blanks_and_comments()
                    continue
                break
            if sc.peek() == ")":
                sc.i += 1
            body = self.parse_command_list(stop_keywords=frozenset({"esac"}))
            arms.append(body)
            sc.skip_blanks_and_comments()
            if sc.peek() == ";" and sc.peek(1) == ";":
                sc.i += 2
                continue
            sc.skip_blanks_and_comments()
            if sc.peek_keyword("esac"):
                sc.i += 4
                break
            if sc.at_end():
                break
        redirects = self._read_trailing_redirects()
        return CaseNode(arms, redirects, header_words)


def _is_assignment_word(word):
    if not word.segs:
        return False
    kind, text = word.segs[0]
    if kind != "lit":
        return False
    return bool(ASSIGNMENT_RE.match(text))


def _contains_unquoted_close_paren(text: str) -> bool:
    """Quote-aware scan for a ')' outside quotes/escapes -- the gate that
    decides whether an arithmetic span earns the additive nested-subshell
    reading (see the module docstring)."""
    sc = Scanner(text)
    while sc.i < sc.n:
        if sc._skip_quote_or_escape():
            continue
        if sc.s[sc.i] == ")":
            return True
        sc.i += 1
    return False


def _arith_content_has_close_paren(subshell_text: str) -> bool:
    """Gate for the command-position `(( ))` backtrack. `subshell_text` is
    the outer-subshell reading's body: `( 1 > 0 )` for `(( 1 > 0 ))`,
    `(git push …) 2>/dev/null` for the backtracked shapes. Two signals of
    a possible bash backtrack: (a) the body does not end exactly at a `)`
    -- the two closers of a genuine `(( ))` are adjacent, so trailing text
    or even a space between them means bash could not have read it as
    arithmetic; (b) the arithmetic content (body minus its own wrapping
    pair) still carries an unquoted ')'. Genuine flat arithmetic
    (`(( 1 > 0 ))`) triggers neither; genuine nested-paren arithmetic
    triggers (b), earning the harmless additive second reading that finds
    no mutation."""
    if not subshell_text.startswith("(") or not subshell_text.endswith(")"):
        return True
    return _contains_unquoted_close_paren(subshell_text[1:-1])


# --------------------------------------------------------------------------
# fd-state model. See the module docstring for the persistent/overlay design.
# --------------------------------------------------------------------------


def classify_target(word: Word | None) -> str:
    """VISIBLE targets return 'FILE' or 'UNKNOWN' (both permit); NULL and
    CLOSED are the two block-worthy states."""
    if word is None:
        return "VISIBLE"
    if word.has_expansion:
        return "UNKNOWN"
    val = word.literal_value()
    if val is None:
        return "UNKNOWN"
    if val == "/dev/null":
        return "NULL"
    return "FILE"


def apply_redirects(redirect_list: list[Redirect], eff: dict[int, str]) -> None:
    """Applies a redirect list LEFT TO RIGHT onto `eff` (mutated in place),
    real dup semantics: >&N copies fd N's CURRENT value (a snapshot, not an
    alias), so order matters (`2>&1 >/dev/null` != `>/dev/null 2>&1`)."""
    for r in redirect_list:
        if r.op in (">", ">>", ">|", "<", "<>"):
            eff[r.fd] = classify_target(r.target)
        elif r.op in (">&", "<&"):
            if r.target is not None and r.target.is_bare_dash():
                eff[r.fd] = "CLOSED"
            else:
                n = r.target.is_bare_digits() if r.target is not None else None
                if n is not None:
                    eff[r.fd] = eff.get(n, "VISIBLE")
                else:
                    eff[r.fd] = "UNKNOWN"
        elif r.op in ("&>", "&>>"):
            val = classify_target(r.target)
            eff[1] = val
            eff[2] = val
        # <<, <<-, <<< are input redirects; irrelevant to fd2 blocking, and
        # heredoc bodies are consumed as data by the lexer already -- no-op.


def collect_touched_fds(redirect_list: list[Redirect]) -> set[int]:
    touched: set[int] = set()
    for r in redirect_list:
        touched.update(r.touched_fds())
    return touched


class Scope:
    """persistent: the real, mutable fd table for this shell level (a
    subshell / command substitution / isolated `-c` gets its own fresh
    dict; a brace group / if / for / while / function body shares the
    enclosing one, matching real bash's exec-persistence rules).

    overlays: redirect lists of enclosing constructs, re-applied on top of
    a *fresh copy* of `persistent` every time effective() is computed --
    so they can never themselves leak into `persistent`."""

    __slots__ = ("persistent", "overlays")

    def __init__(
        self, persistent: dict[int, str], overlays: list[list[Redirect]]
    ) -> None:
        self.persistent = persistent
        self.overlays = overlays

    def effective(self) -> dict[int, str]:
        eff = dict(self.persistent)
        for rl in self.overlays:
            apply_redirects(rl, eff)
        return eff

    def child_with_overlay(self, redirect_list: list[Redirect]) -> Scope:
        if not redirect_list:
            return self
        return Scope(self.persistent, self.overlays + [redirect_list])

    def new_isolated(self, base_eff: dict[int, str]) -> Scope:
        return Scope(dict(base_eff), [])

    def exec_apply(self, redirect_list: list[Redirect]) -> None:
        """A real `exec` redirect: resolves dup sources against the current
        *overlaid* effective view (so it sees any already-active
        suppression correctly), but commits only the fds its own redirect
        list actually touches into `persistent` -- so an enclosing
        construct's own (non-leaking) redirect never gets baked in."""
        eff = self.effective()
        apply_redirects(redirect_list, eff)
        for fd in collect_touched_fds(redirect_list):
            self.persistent[fd] = eff.get(fd, "VISIBLE")


# --------------------------------------------------------------------------
# Mutation detection.
# --------------------------------------------------------------------------

GIT_MUTATING_SUBCOMMANDS = {"push", "commit", "merge", "rebase"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
GH_PR_MUTATING = {"create", "edit", "close", "merge", "ready"}
TEA_PR_MUTATING = {"create", "edit", "close", "merge"}
GIT_FORGE_MUTATING = {"merge", "create", "edit", "close"}
API_MUTATING_VERBS = {"POST", "PATCH", "DELETE"}


def _word_values(words: list[Word]) -> list[str | None]:
    """Per-word QUOTE-REMOVED literal value, or None only when the word
    carries an expansion (its value is unknowable at guard time). Quoting
    that preserves the value must not blind detection -- `\\git push`,
    `git "push"` execve the same mutation (round-1 security lane, High) --
    so words are judged exactly like redirect targets already were. A
    quoted MENTION (`echo "git push origin main"`) still yields ONE
    multi-word value that matches nothing. Applies uniformly to every
    position in the sequence, not just the first."""
    return [w.literal_value() for w in words]


def find_mutation(words: list[Word]) -> str | None:
    """Returns a short description string for the first detected mutation
    in this simple command's word list, or None. Command names compare by
    BASENAME so `/usr/bin/git push` and `./git push` are recognized
    (round-1 security lane, Medium) -- the mutation text is lexically
    present there, not runtime-determined. Subcommands/verbs stay exact."""
    vals = _word_values(words)
    n = len(vals)
    i = 0
    while i < n:
        v = vals[i]
        if v is None:
            i += 1
            continue
        lv = v.lower().rsplit("/", 1)[-1]
        if lv == "git":
            j = i + 1
            while j < n and vals[j] is not None and vals[j].startswith("-"):
                opt = vals[j]
                consume_next = opt in GIT_OPTS_WITH_VALUE
                j += 1
                if consume_next and j < n:
                    j += 1
            if j < n and vals[j] is not None and vals[j].lower() in GIT_MUTATING_SUBCOMMANDS:
                return "git %s" % vals[j].lower()
        elif lv == "gh":
            sub = vals[i + 1].lower() if i + 1 < n and vals[i + 1] is not None else None
            if sub == "pr":
                if i + 2 < n and vals[i + 2] is not None and vals[i + 2].lower() in GH_PR_MUTATING:
                    return "gh pr %s" % vals[i + 2].lower()
            elif sub == "issue":
                if i + 2 < n and vals[i + 2] is not None and vals[i + 2].lower() == "edit":
                    return "gh issue edit"
            elif sub == "api":
                for k in range(i + 2, n):
                    if (
                        vals[k] is not None
                        and vals[k] == "-X"
                        and k + 1 < n
                        and vals[k + 1] is not None
                        and vals[k + 1].upper() in API_MUTATING_VERBS
                    ):
                        return "gh api -X %s" % vals[k + 1].upper()
        elif lv == "tea":
            if (
                i + 1 < n
                and vals[i + 1] is not None
                and vals[i + 1].lower() == "pr"
                and i + 2 < n
                and vals[i + 2] is not None
                and vals[i + 2].lower() in TEA_PR_MUTATING
            ):
                return "tea pr %s" % vals[i + 2].lower()
        elif lv == "git-forge":
            for k in range(i + 1, n):
                if vals[k] is not None and vals[k].lower() in GIT_FORGE_MUTATING:
                    return "git-forge %s" % vals[k].lower()
        i += 1
    return None


# --------------------------------------------------------------------------
# Walker: walks the AST, threading fd-state Scopes, raising BlockedFound as
# soon as a suppressed mutation is found anywhere in scope.
# --------------------------------------------------------------------------


class BlockedFound(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


SHELL_NAMES = {"bash", "sh", "zsh"}
RECURSION_DEPTH_LIMIT = 60


def _first_word_value(cmd: SimpleCommand) -> str | None:
    """Quote-removed literal value of the command word (None only when it
    carries an expansion) -- same rationale as _word_values: `"exec"` and
    `\\eval` are the builtins they spell (round-1 security lane, High)."""
    if not cmd.words:
        return None
    return cmd.words[0].literal_value()


def _recurse_text(text: str, scope: Scope, depth: int) -> None:
    if depth > RECURSION_DEPTH_LIMIT:
        raise TokenizerError("recursion depth exceeded")
    parser = Parser(text)
    body = parser.parse_program()
    walk_command_list(body, scope, depth + 1)


def _recurse_text_tolerant(text: str, scope: Scope, depth: int) -> None:
    """Additive second reading (arithmetic backtrack): parse errors are
    discarded -- a failed reading proves nothing -- but a BlockedFound
    verdict propagates. This reading can only ever ADD a block."""
    try:
        _recurse_text(text, scope, depth)
    except TokenizerError:
        pass


def walk_command_list(clist: CommandList, scope: Scope, depth: int = 0) -> None:
    for andor in clist.items:
        walk_and_or(andor, scope, depth)


def walk_and_or(andor: AndOr, scope: Scope, depth: int) -> None:
    for pipeline in andor.pipelines:
        walk_pipeline(pipeline, scope, depth)


def walk_pipeline(pipeline: Pipeline, scope: Scope, depth: int) -> None:
    last = len(pipeline.commands) - 1
    for idx, cmd in enumerate(pipeline.commands):
        if idx == last:
            walk_node(cmd, scope, depth)
        else:
            eff = scope.effective()
            eff[1] = "PIPE"
            piped_scope = Scope(dict(eff), [])
            # `|&` merges the node's stderr into the pipe AFTER the node's
            # own redirect list (bash manual; round-1 logic lane finding 5)
            # -- so it is applied inside walk_node, post-redirect, not here.
            stderr_piped = idx < len(pipeline.ops) and pipeline.ops[idx] == "|&"
            walk_node(cmd, piped_scope, depth, stderr_piped=stderr_piped)


def _piped_child(scope: Scope, redirects: list[Redirect]) -> Scope:
    """Concrete child scope for a construct that is a |&'d pipeline
    element: resolve the construct's own redirect list, then force fd2 to
    the (visible) pipe. Commands INSIDE keep their own private redirects
    on top of this. Concretizing is safe here because a non-last pipeline
    element already runs in a fresh subshell-like scope."""
    eff = scope.effective()
    apply_redirects(redirects, eff)
    eff[2] = "PIPE"
    return Scope(dict(eff), [])


def walk_node(
    node: object, scope: Scope, depth: int, stderr_piped: bool = False
) -> None:
    if isinstance(node, SimpleCommand):
        walk_simple_command(node, scope, depth, stderr_piped)
    elif isinstance(node, Subshell):
        eff = scope.effective()
        apply_redirects(node.redirects, eff)
        if stderr_piped:
            eff[2] = "PIPE"
        walk_command_list(node.body, Scope(dict(eff), []), depth)
    elif isinstance(node, BraceGroup):
        child = (
            _piped_child(scope, node.redirects)
            if stderr_piped
            else scope.child_with_overlay(node.redirects)
        )
        walk_command_list(node.body, child, depth)
    elif isinstance(node, ForLoop):
        child = (
            _piped_child(scope, node.redirects)
            if stderr_piped
            else scope.child_with_overlay(node.redirects)
        )
        _walk_word_expansions(node.header_words, child.effective(), depth)
        walk_command_list(node.body, child, depth)
    elif isinstance(node, WhileUntil):
        child = (
            _piped_child(scope, node.redirects)
            if stderr_piped
            else scope.child_with_overlay(node.redirects)
        )
        walk_command_list(node.cond, child, depth)
        walk_command_list(node.body, child, depth)
    elif isinstance(node, IfNode):
        child = (
            _piped_child(scope, node.redirects)
            if stderr_piped
            else scope.child_with_overlay(node.redirects)
        )
        for cond, body in node.branches:
            if cond is not None:
                walk_command_list(cond, child, depth)
            walk_command_list(body, child, depth)
    elif isinstance(node, CaseNode):
        child = (
            _piped_child(scope, node.redirects)
            if stderr_piped
            else scope.child_with_overlay(node.redirects)
        )
        _walk_word_expansions(node.header_words, child.effective(), depth)
        for arm in node.arms:
            walk_command_list(arm, child, depth)
    elif isinstance(node, ArithCommand):
        # Genuine arithmetic is data (no words, no traversal) -- but when
        # the span could be bash's backtracked nested subshell, give it the
        # additive second reading (round-1 security lane finding 2).
        if node.backtrack:
            eff = scope.effective()
            apply_redirects(node.redirects, eff)
            if stderr_piped:
                eff[2] = "PIPE"
            _recurse_text_tolerant(node.subshell_text, Scope(dict(eff), []), depth)
    elif isinstance(node, FunctionDef):
        # Parsed and walked IN PLACE at the definition site -- never linked
        # to a later invocation (name-binding indirection stays out of
        # scope by design). Shares scope like a brace group.
        if node.body is not None:
            child = (
                _piped_child(scope, node.redirects)
                if stderr_piped
                else scope.child_with_overlay(node.redirects)
            )
            walk_node(node.body, child, depth)
    else:
        raise TokenizerError("unknown node type: %r" % (type(node),))


def walk_simple_command(
    cmd: SimpleCommand, scope: Scope, depth: int, stderr_piped: bool = False
) -> None:
    eff_enclosing = scope.effective()
    cmd_eff = dict(eff_enclosing)
    apply_redirects(cmd.redirects, cmd_eff)
    if stderr_piped:
        # The |& implicit 2>&1 lands after the command's own redirects, so
        # a self-nulled fd2 is re-merged into the visible pipe.
        cmd_eff[2] = "PIPE"

    reason = find_mutation(cmd.words)
    if reason is not None and cmd_eff.get(2, "VISIBLE") in ("NULL", "CLOSED"):
        raise BlockedFound(reason)

    first = _first_word_value(cmd)

    if first == "exec":
        scope.exec_apply(cmd.redirects)

    if first == "eval":
        payload = _literal_eval_payload(cmd.words[1:])
        if payload is not None:
            child = scope.child_with_overlay(cmd.redirects)
            _recurse_text(payload, child, depth)

    # Shell names compare by basename too (`/bin/bash -c '…'` carries the
    # same literal payload) -- fail-closed direction, same rationale as
    # find_mutation's basename comparison.
    if first is not None and first.rsplit("/", 1)[-1] in SHELL_NAMES:
        payload = _literal_dash_c_payload(cmd.words[1:])
        if payload is not None:
            sub_scope = scope.new_isolated(cmd_eff)
            _recurse_text(payload, sub_scope, depth)

    _walk_substitutions(cmd, cmd_eff, depth)


def _literal_eval_payload(args: list[Word]) -> str | None:
    parts = []
    for w in args:
        v = w.literal_value()
        if v is None:
            return None
        parts.append(v)
    return " ".join(parts)


DASH_C_CLUSTER_RE = re.compile(r"^-[a-z]*c$")


def _literal_dash_c_payload(args: list[Word]) -> str | None:
    """The `-c` payload word's literal value, or None. Clustered short
    flags (`-ec`, `-lc`) carry the same fully-literal payload (round-1
    logic lane finding 4); `--`-style long options are excluded by the
    pattern."""
    for idx, w in enumerate(args):
        v = w.literal_value()
        if v is not None and DASH_C_CLUSTER_RE.match(v):
            if idx + 1 < len(args):
                payload = args[idx + 1].literal_value()
                return payload  # None (has expansion) -> caller skips
            return None
    return None


def _walk_word_expansions(
    words: list[Word] | tuple, eff: dict[int, str], depth: int
) -> None:
    """Walk the recursable expansions (command/backtick/process
    substitution) of `words` in a scope seeded from `eff`, plus the
    additive arithmetic-backtrack reading for `$((`-spans that carry an
    unquoted ')' (see the module docstring)."""
    for w in words:
        for kind, content in w.segs:
            if kind in RECURSABLE_KINDS:
                _recurse_text(content, Scope(dict(eff), []), depth)
            elif kind == "arith" and _arith_content_has_close_paren(content):
                # `content` is the $((-span's outer-subshell body (see
                # consume_dollar), so the gate is the same one the
                # command-position path uses -- non-adjacent closers or a
                # stray ')' in the arithmetic content.
                _recurse_text_tolerant(content, Scope(dict(eff), []), depth)


def _walk_substitutions(cmd: SimpleCommand, cmd_eff: dict[int, str], depth: int) -> None:
    words = list(cmd.words) + list(cmd.assignments)
    for r in cmd.redirects:
        if r.target is not None:
            words.append(r.target)
    _walk_word_expansions(words, cmd_eff, depth)


# --------------------------------------------------------------------------
# Entry point.
# --------------------------------------------------------------------------


def _run(command_text: str) -> tuple[int, str | None]:
    """Returns (exit_code, message_or_None). Never raises -- every error
    path (parse error, recursion blowup, unexpected exception) is mapped to
    exit 3 here, per the fail-closed contract."""
    persistent: dict[int, str] = {}
    scope = Scope(persistent, [])
    try:
        parser = Parser(command_text)
        body = parser.parse_program()
        walk_command_list(body, scope, 0)
    except BlockedFound as e:
        return 1, e.reason
    except TokenizerError as e:
        return 3, "tokenizer error: %s" % e
    except RecursionError:
        return 3, "tokenizer error: recursion depth exceeded"
    except Exception as e:  # noqa: BLE001 -- last-resort fail-closed backstop;
        # any bug in this hand-rolled parser must never silently permit a
        # mutation, so an unanticipated exception is treated the same as a
        # declared TokenizerError.
        return 3, "tokenizer error: %s: %s" % (type(e).__name__, e)
    return 0, None


def main() -> None:
    try:
        sys.setrecursionlimit(4000)
    except (ValueError, RecursionError):
        # Best-effort headroom bump; the current limit still applies and a
        # blowup still lands in _run's RecursionError -> exit 3 path.
        pass
    command_text = sys.stdin.read()
    code, message = _run(command_text)
    if code == 1:
        sys.stdout.write("%s\n" % message)
    elif code == 3:
        sys.stdout.write("%s\n" % message)
    sys.exit(code)


if __name__ == "__main__":
    main()
