/**
 * scrub-secrets — redact secret values from bash tool output before they land
 * in the session transcript / model context.
 *
 * Uses the `tool_result` hook (fires after a tool runs, can replace the result)
 * instead of overriding the `bash` tool. Overriding would collide with any other
 * extension that owns bash (e.g. pi-tool-display) — pi hard-fails on duplicate
 * tool names. The hook composes cleanly with all of them.
 *
 * Scope: bash only. Deliberately NOT read/write — masking file contents there
 * would corrupt legitimate edits to config/.env files. To also cover other
 * tools, widen the toolName check below.
 *
 * NOTE: cannot scrub RTK's own temp log files (/var/folders/.../pi-bash-*.log),
 * which are written by the rtk wrapper, not pi. Rotate any leaked secret.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { makeRedactor } from "./redactor.ts";

export default function (pi: ExtensionAPI) {
  const redact = makeRedactor();

  const scrub = <T>(value: T): T => {
    if (typeof value === "string") return redact(value) as T;
    if (Array.isArray(value)) return value.map(scrub) as T;
    if (value && typeof value === "object") {
      const out: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(value)) out[k] = scrub(v);
      return out as T;
    }
    return value;
  };

  pi.on("tool_result", (event) => {
    if (event.toolName !== "bash") return;
    const content = event.content.map((c) =>
      c.type === "text" ? { ...c, text: redact(c.text) } : c,
    );
    return event.details === undefined ? { content } : { content, details: scrub(event.details) };
  });
}
