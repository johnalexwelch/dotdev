import { homedir } from "node:os";
import { join, resolve } from "node:path";

/**
 * Normalizes pi `tool_result` events into follow events.
 *
 * Shapes mirror `EditToolResultEvent` / `WriteToolResultEvent` from
 * `@earendil-works/pi-coding-agent` (`dist/core/extensions/types.d.ts`).
 * They are restated structurally so this module stays testable without
 * loading the pi runtime.
 */

export interface FollowEvent {
  /** Absolute path of the file the agent just changed. */
  path: string;
  /** 1-indexed line to place the cursor on. */
  line: number;
}

/**
 * Resolves a raw tool-argument path the way pi's own tools do.
 *
 * `tool_result.input` is the model's *raw* arguments — `agent-session.js`
 * builds the event with `input: args`, and `edit.js` resolves the path into a
 * local that never reaches the event. So the path may be relative to the
 * agent's cwd, or `~`-prefixed, and resolving it here is what keeps Neovim
 * from resolving it against its own cwd instead.
 *
 * Not replicated from pi's `resolveToCwd`: `@`-prefix stripping and unicode
 * space normalization, neither of which appears in edit/write paths.
 */
function resolvePath(rawPath: string, cwd: string, home: string): string {
  if (rawPath === "~") {
    return home;
  }
  if (rawPath.startsWith("~/")) {
    return join(home, rawPath.slice(2));
  }
  return resolve(cwd, rawPath);
}

export interface ToolResultLike {
  type: string;
  toolName: string;
  input?: Record<string, unknown>;
  isError?: boolean;
  details?: { firstChangedLine?: number } | undefined;
}

/** Only tools that write to disk are worth following. */
const MUTATING_TOOLS = new Set(["edit", "write"]);

/**
 * @param cwd The agent's working directory, from `ExtensionContext.cwd`.
 * @param home Overridable for tests; defaults to the real home directory.
 */
export function toFollowEvent(
  event: ToolResultLike,
  cwd: string,
  home: string = homedir(),
): FollowEvent | null {
  if (!MUTATING_TOOLS.has(event.toolName) || event.isError === true) {
    return null;
  }
  const path = event.input?.["path"];
  if (typeof path !== "string" || path.length === 0) {
    return null;
  }
  return {
    path: resolvePath(path, cwd, home),
    line: event.details?.firstChangedLine ?? 1,
  };
}
