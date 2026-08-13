import type { FollowEvent } from "./normalize.ts";

/** Escapes a string for use inside a single-quoted Vimscript literal. */
function vimEscape(value: string): string {
  return value.replaceAll("'", "''");
}

/**
 * Builds the `--remote-expr` argument that hands a follow event to Neovim.
 *
 * The event travels as one JSON string so there is exactly one level of
 * quoting to get right.
 */
export function remoteExpr(event: FollowEvent): string {
  const payload = vimEscape(JSON.stringify(event));
  return `luaeval("require('agent-follow').follow_json(_A)", '${payload}')`;
}

/** Delivers a follow event to Neovim. Best-effort: never throws. */
export async function send(
  serverAddress: string,
  event: FollowEvent,
  spawn: (cmd: string[]) => Promise<void>,
): Promise<void> {
  try {
    await spawn(["nvim", "--server", serverAddress, "--remote-expr", remoteExpr(event)]);
  } catch {
    // Neovim may have exited since it registered. Following is best-effort and
    // must never interrupt the agent.
  }
}
