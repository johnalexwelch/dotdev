import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { promisify } from "node:util";

import { toFollowEvent, type FollowEvent, type ToolResultLike } from "./normalize.ts";
import { resolveServer } from "./registry.ts";
import { hunkCommand } from "./targets/hunk.ts";
import { send } from "./transport.ts";

const execFileAsync = promisify(execFile);

async function spawn(cmd: string[]): Promise<void> {
  const [bin, ...args] = cmd;
  if (bin === undefined) {
    return;
  }
  await execFileAsync(bin, args, { timeout: 2000 });
}

/** Cache of cwd -> git worktree root, so following costs no extra subprocess. */
const repoRoots = new Map<string, string | null>();

async function repoRoot(cwd: string): Promise<string | null> {
  const cached = repoRoots.get(cwd);
  if (cached !== undefined) {
    return cached;
  }
  let root: string | null = null;
  try {
    const { stdout } = await execFileAsync("git", ["rev-parse", "--show-toplevel"], {
      cwd,
      timeout: 2000,
    });
    root = stdout.trim() || null;
  } catch {
    // Not a git worktree. Only the hunk target needs this; Neovim does not.
    root = null;
  }
  repoRoots.set(cwd, root);
  return root;
}

/** Moves the Neovim instance registered for this herdr workspace. */
async function followInNeovim(workspaceId: string, event: FollowEvent): Promise<void> {
  const server = await resolveServer(workspaceId, (path) => readFile(path, "utf8"));
  if (server !== null) {
    await send(server, event, spawn);
  }
}

/**
 * Moves a live `hunk` review session, if one is open on this repo.
 *
 * No registry lookup: hunk addresses sessions by repo path, and the command is
 * a no-op when no session is running.
 */
async function followInHunk(cwd: string, event: FollowEvent): Promise<void> {
  const root = await repoRoot(cwd);
  if (root === null) {
    return;
  }
  const cmd = hunkCommand(event, root);
  if (cmd === null) {
    return;
  }
  try {
    await spawn(cmd);
  } catch {
    // No hunk session open, or hunk not installed. Following is best-effort.
  }
}

/**
 * pi extension: mirrors the agent's file edits into the surfaces running in the
 * same herdr workspace — Neovim for editing, `hunk` for review. Both are
 * optional and independent; whichever is present gets moved.
 */
export default function (pi: {
  on: (
    event: string,
    handler: (event: ToolResultLike, ctx: { cwd: string }) => void,
  ) => void;
}): void {
  const workspaceId = process.env["HERDR_WORKSPACE_ID"];
  if (process.env["HERDR_ENV"] !== "1" || !workspaceId) {
    return;
  }

  pi.on("tool_result", (event, ctx) => {
    // `event.input` holds the model's raw arguments, so the path is resolved
    // against the agent's cwd here rather than against Neovim's.
    const followEvent = toFollowEvent(event, ctx.cwd);
    if (followEvent === null) {
      return;
    }
    // Fire-and-forget: following must never block or fail the agent's turn.
    // One target failing must not stop the other, hence allSettled.
    void Promise.allSettled([
      followInNeovim(workspaceId, followEvent),
      followInHunk(ctx.cwd, followEvent),
    ]);
  });
}
