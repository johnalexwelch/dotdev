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

describe("toFollowEvent", () => {
  test("an edit reporting firstChangedLine follows to that line", () => {
    expect(toFollowEvent(fixture("edit_with_first_changed_line"))).toEqual({
      path: "/w/src/a.ts",
      line: 12,
    });
  });

  test("a write follows to the top of the new file", () => {
    expect(toFollowEvent(fixture("write_new_file"))).toEqual({
      path: "/w/src/new.ts",
      line: 1,
    });
  });

  test.each(["read_is_ignored", "bash_is_ignored", "grep_is_ignored"])(
    "a tool that does not change the file produces no follow event (%s)",
    (name) => {
      expect(toFollowEvent(fixture(name))).toBeNull();
    },
  );

  test("an edit that failed produces no follow event", () => {
    expect(toFollowEvent(fixture("failed_edit_is_ignored"))).toBeNull();
  });

  // `EditToolResultEvent.details` is `EditToolDetails | undefined`, so an edit
  // can arrive with no line to follow to.
  test("an edit reporting no line falls back to the top of the file", () => {
    expect(toFollowEvent(fixture("edit_without_details"))).toEqual({
      path: "/w/src/b.ts",
      line: 1,
    });
  });
});
