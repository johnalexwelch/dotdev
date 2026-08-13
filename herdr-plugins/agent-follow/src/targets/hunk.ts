import { relative } from "node:path";

import type { FollowEvent } from "../normalize.ts";

/**
 * Builds the `hunk session navigate` argv for a follow event.
 *
 * `hunk` addresses a live review session by repo path, so there is no registry
 * to consult — unlike the Neovim target, which has to look up a server address.
 *
 * It also rejects absolute paths ("No diff file matches"), so the absolute path
 * `toFollowEvent` produces is made repo-relative here.
 */
export function hunkCommand(event: FollowEvent, repoRoot: string): string[] | null {
  const file = relative(repoRoot, event.path);
  if (file.startsWith("..") || file.length === 0) {
    return null;
  }
  return [
    "hunk",
    "session",
    "navigate",
    "--repo",
    repoRoot,
    "--file",
    file,
    "--new-line",
    String(event.line),
  ];
}
