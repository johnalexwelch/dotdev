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

export interface ToolResultLike {
  type: string;
  toolName: string;
  input?: Record<string, unknown>;
  isError?: boolean;
  details?: { firstChangedLine?: number } | undefined;
}

/** Only tools that write to disk are worth following. */
const MUTATING_TOOLS = new Set(["edit", "write"]);

export function toFollowEvent(event: ToolResultLike): FollowEvent | null {
  if (!MUTATING_TOOLS.has(event.toolName) || event.isError === true) {
    return null;
  }
  const path = event.input?.["path"];
  if (typeof path !== "string") {
    return null;
  }
  return { path, line: event.details?.firstChangedLine ?? 1 };
}
