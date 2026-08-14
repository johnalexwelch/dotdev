import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Where a Neovim instance advertises its RPC server address, keyed by herdr
 * workspace. Neovim writes the file on VimEnter; emitters read it.
 *
 * One nvim per workspace: if two register in the same workspace, the last one
 * to start wins.
 */
export function registryPath(workspaceId: string): string {
  return join(homedir(), ".herdr", "nvim-servers", workspaceId);
}

export type ReadFile = (path: string) => Promise<string>;

/** Resolves the Neovim server address for a workspace, or null if none is registered. */
export async function resolveServer(
  workspaceId: string | undefined,
  readFile: ReadFile,
): Promise<string | null> {
  if (!workspaceId) {
    return null;
  }
  try {
    const address = (await readFile(registryPath(workspaceId))).trim();
    return address.length > 0 ? address : null;
  } catch {
    // No nvim registered for this workspace. Following is best-effort.
    return null;
  }
}
