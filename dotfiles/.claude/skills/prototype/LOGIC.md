# Logic Prototype

## When this is the right shape

The question is about **behavior**, not appearance. Typical triggers:

- "Does this state machine handle all the edge cases?"
- "Is this data model right for the access patterns we need?"
- "What should the API shape look like for this workflow?"
- "Can this reducer handle undo/redo without getting weird?"
- "How do these domain objects interact when X happens?"

If you can phrase the question as "what happens when…" or "does this model support…", you want a logic prototype.

## Process

### 1. State the question

Write the question down in a comment at the top of the prototype file. One sentence. If you can't state it crisply, you're not ready to prototype — go back to grilling.

### 2. Pick the language

Match the host project. If the project is TypeScript, the prototype is TypeScript. If Python, Python. The point is to validate logic in the same language it will eventually live in, so type system behavior and idioms carry over.

### 3. Isolate the logic in a portable module

This is the core of the prototype. Put the logic in its own file, completely pure:

- **Reducer / state machine**: a function that takes `(state, action) -> state`
- **Pure functions**: transform input to output, no side effects
- **Class with clear method surface**: if the domain is naturally OOP, a class is fine — but methods should be pure or clearly separated from I/O

Rules for the logic module:
- No I/O. No network calls, no file reads, no database.
- No framework imports. Standard library only.
- Accept input as arguments, return output as return values.
- Keep it in one file. If it's getting long, the prototype scope is too big.

### 4. Build the smallest TUI that exposes the state

The TUI is a throwaway shell around the logic module. Its only job is to let the user poke the state and see what happens.

**Pattern: clear-screen-and-rerender**
- After every action, clear the terminal and reprint the full state.
- State goes at the top. Available actions go at the bottom.
- Use ANSI escape codes for minimal formatting (bold for labels, dim for hints). No TUI framework unless the project already has one.

**Layout:**
```
┌─────────────────────────────────┐
│  PROTOTYPE: [question]          │
│                                 │
│  [full state dump, formatted]   │
│                                 │
│                                 │
│  [a] action-one                 │
│  [b] action-two                 │
│  [r] reset  [q] quit            │
└─────────────────────────────────┘
```

**Keyboard shortcuts:**
- Single-letter keys for each action (a, b, c…)
- `r` to reset state to initial
- `q` to quit
- Print the shortcut legend at the bottom of every render

**State display:**
- Print the full state object after every action. Use JSON.stringify with indentation, pprint, or equivalent.
- Highlight what changed since last action if it's easy (bold the changed fields). Skip if it's not trivial.

### 5. Make it runnable in one command

Add a script to the project's task runner:
- `package.json` → `"scripts": { "prototype:thing-name": "npx tsx src/prototype-thing-name.ts" }`
- `Makefile` → `prototype-thing-name: ...`
- `pyproject.toml` → `[tool.poetry.scripts]` or a simple `python src/prototype_thing_name.py`

The command should be obvious from the project's existing patterns. Name it `prototype:descriptive-slug`.

### 6. Hand it over

Tell the user:
- What the question is
- How to run it (`npm run prototype:thing-name`)
- What to try (specific sequences of actions that exercise the interesting cases)
- What to look for in the state output

Then stop. Let them play with it.

### 7. Capture the answer

When the user has an answer, record it before deleting the prototype:
- What was the question?
- What did we learn?
- What decision does this support?

Put it in a commit message, an ADR, a NOTES.md next to the prototype, or an issue comment — wherever decisions live in this project.

## Anti-patterns

- **Don't add tests.** The prototype IS the test. You're manually exploring state space. Automated tests on throwaway code are wasted effort.
- **Don't wire it to a real database.** Use in-memory state. If you need seed data, hardcode it in the prototype file.
- **Don't generalize.** If the question is about one workflow, prototype one workflow. Don't build a "flexible prototype framework."
- **Don't blur logic and TUI.** The logic module should be importable without the TUI. The TUI should be a thin wrapper. This separation is the one structural rule worth keeping — it makes it trivial to port the logic into production later.
- **Don't ship the TUI shell to production.** The logic module might graduate. The TUI never does.
