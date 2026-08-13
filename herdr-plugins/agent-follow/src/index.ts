import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { promisify } from "node:util";

import { toFollowEvent, type ToolResultLike } from "./normalize.ts";
import { resolveServer } from "./registry.ts";
import { send } from "./transport.ts";

const execFileAsync = promisify(execFile);

async function spawn(cmd: string[]): Promise<void> {
  const [bin, ...args] = cmd;
  if (bin === undefined) {
    return;
  }
  await execFileAsync(bin, args, { timeout: 2000 });
}

/**
 * pi extension: mirrors the agent's file edits into the Neovim instance
 * running in the same herdr workspace.
 */
export default function (pi: {
  on: (event: string, handler: (event: ToolResultLike) => void) => void;
}): void {
  const workspaceId = process.env["HERDR_WORKSPACE_ID"];
  if (process.env["HERDR_ENV"] !== "1" || !workspaceId) {
    return;
  }

  pi.on("tool_result", (event) => {
    const followEvent = toFollowEvent(event);
    if (followEvent === null) {
      return;
    }
    // Fire-and-forget: following must never block or fail the agent's turn.
    void (async () => {
      const server = await resolveServer(workspaceId, (path) => readFile(path, "utf8"));
      if (server !== null) {
        await send(server, followEvent, spawn);
      }
    })();
  });
}
