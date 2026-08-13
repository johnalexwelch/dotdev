import { describe, expect, test } from "bun:test";

import { hunkCommand } from "../src/targets/hunk.ts";

const REPO = "/w";

describe("hunkCommand", () => {
  // `hunk session navigate` rejects absolute paths with "No diff file matches",
  // so the absolute path the normalizer produces has to be made relative here.
  test("addresses the file relative to the repo root", () => {
    expect(hunkCommand({ path: "/w/src/a.ts", line: 12 }, REPO)).toEqual([
      "hunk",
      "session",
      "navigate",
      "--repo",
      "/w",
      "--file",
      "src/a.ts",
      "--new-line",
      "12",
    ]);
  });

  // A file outside the review's repo would relativize to `../…`, which hunk
  // cannot match against its diff. There is nothing useful to navigate to.
  test("declines to navigate to a file outside the repo", () => {
    expect(hunkCommand({ path: "/elsewhere/other.ts", line: 3 }, REPO)).toBeNull();
  });
});
