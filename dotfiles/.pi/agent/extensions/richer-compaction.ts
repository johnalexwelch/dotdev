/**
 * richer-compaction: append standing focus instructions to every auto-compaction.
 * Reuses pi's built-in compact() so the default structured format, split-turn
 * handling, and file tracking are unchanged — we only steer WHAT it emphasizes.
 *
 * ponytail: standing instructions live in STANDING_FOCUS below. Summaries use
 * Sonnet (cheaper/faster than Opus, ample for structured extraction); falls back
 * to the conversation model if Sonnet isn't registered.
 */
import { compact } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STANDING_FOCUS = `
Additionally, preserve with high fidelity:
- Exact file paths, function/symbol names, and line-level locations touched.
- Concrete decisions AND the options rejected (with the reason), not just the winner.
- Any user constraints, preferences, or "do not do X" instructions verbatim.
- Open questions / unverified assumptions still needing confirmation.
- The single most important next action, stated so work can resume cold.
Prefer specificity over brevity when the two conflict.`;

export default function (pi: ExtensionAPI) {
	pi.on("session_before_compact", async (event, ctx) => {
		// Sonnet for summarization — Opus is wasted on a bounded extraction task.
		const model = ctx.modelRegistry.find("anthropic", "claude-sonnet-4-6") ?? ctx.getModel();
		if (!model) return; // fall back to default compaction

		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
		if (!auth.ok || !auth.apiKey) return;

		const instructions = [event.customInstructions?.trim(), STANDING_FOCUS.trim()]
			.filter(Boolean)
			.join("\n\n");

		try {
			const compaction = await compact(
				event.preparation,
				model,
				auth.apiKey,
				auth.headers,
				instructions,
				event.signal,
				ctx.getThinkingLevel(),
				undefined,
				auth.env,
			);
			return { compaction };
		} catch {
			return; // any failure → default compaction path
		}
	});
}
