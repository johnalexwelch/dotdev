import { describe, expect, test } from "bun:test";

import { toFollowEvent } from "../src/normalize.ts";

const fixturePath = new URL("./fixtures/follow-events.ndjson", import.meta.url);
const fixtures = new Map<string, unknown>(
  (await Bun.file(fixturePath).text())
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .map((line) => {
      const parsed = JSON.parse(line) as { _case: string; event: unknown };
      return [parsed._case, parsed.event] as const;
    }),
);

function fixture(name: string): any {
  const event = fixtures.get(name);
  if (event === undefined) {
    throw new Error(`missing fixture case: ${name}`);
  }
  return event;
}

const CWD = "/w";

describe("toFollowEvent", () => {
  test("an edit reporting firstChangedLine follows to that line", () => {
    expect(toFollowEvent(fixture("edit_with_first_changed_line"), CWD)).toEqual({
      path: "/w/src/a.ts",
      line: 12,
    });
  });

  test("a write follows to the top of the new file", () => {
    expect(toFollowEvent(fixture("write_new_file"), CWD)).toEqual({
      path: "/w/src/new.ts",
      line: 1,
    });
  });

  test.each(["read_is_ignored", "bash_is_ignored", "grep_is_ignored"])(
    "a tool that does not change the file produces no follow event (%s)",
    (name) => {
      expect(toFollowEvent(fixture(name), CWD)).toBeNull();
    },
  );

  test("an edit that failed produces no follow event", () => {
    expect(toFollowEvent(fixture("failed_edit_is_ignored"), CWD)).toBeNull();
  });

  // `EditToolResultEvent.details` is `EditToolDetails | undefined`, so an edit
  // can arrive with no line to follow to.
  test("an edit reporting no line falls back to the top of the file", () => {
    expect(toFollowEvent(fixture("edit_without_details"), CWD)).toEqual({
      path: "/w/src/b.ts",
      line: 1,
    });
  });

  // `input` is the model's raw tool arguments (agent-session.js constructs the
  // event with `input: args`); the tool resolves the path into a local that
  // never reaches the event. So the path can be relative to pi's cwd.
  test("a path relative to the agent's cwd resolves to an absolute path", () => {
    expect(toFollowEvent(fixture("edit_with_relative_path"), CWD)).toEqual({
      path: "/w/src/rel.ts",
      line: 4,
    });
  });

  test("a ~-prefixed path resolves against home, not the agent's cwd", () => {
    expect(toFollowEvent(fixture("edit_with_tilde_path"), CWD, "/home/me")).toEqual({
      path: "/home/me/notes/todo.md",
      line: 1,
    });
  });

  // pi strips a leading `@` (its file-mention syntax) on every path that goes
  // through resolveToCwd, edit included. An echoed `@src/x` mention must land
  // on the file pi actually edited, not on a nonexistent `@src/x`.
  test("a @-prefixed mention resolves to the file pi actually edited", () => {
    expect(toFollowEvent(fixture("edit_with_at_prefixed_path"), CWD)).toEqual({
      path: "/w/src/at.ts",
      line: 2,
    });
  });

  // `@` is stripped before `~` is expanded, matching normalizePath's order.
  test("a @~ path expands against home once the @ is stripped", () => {
    expect(toFollowEvent(fixture("edit_with_at_prefixed_tilde_path"), CWD, "/home/me")).toEqual({
      path: "/home/me/notes/at.md",
      line: 3,
    });
  });
});
