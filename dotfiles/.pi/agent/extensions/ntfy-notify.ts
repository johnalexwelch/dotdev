import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { exec } from "node:child_process";
import { basename } from "node:path";

// ponytail: pushes ntfy notification when pi settles (awaits you).
// Ceiling: fire-and-forget, no approve-from-phone round-trip.
// Upgrade path: ntfy action button -> local listener that answers the prompt.
// Requires env NTFY_TOPIC. Silent no-op if unset.
export default function (pi: ExtensionAPI) {
  const topic = process.env.NTFY_TOPIC;
  const project = basename(process.cwd());

  pi.on("agent_settled", async (_event, ctx) => {
    if (!topic || !ctx.isIdle()) return;
    const body = `pi finished in ${project}`;
    exec(
      `curl -fsS -H "Title: pi ready" -d ${JSON.stringify(body)} ` +
        `ntfy.sh/${topic}`,
      () => {}, // best-effort; ignore errors so it never blocks the turn
    );
  });
}
