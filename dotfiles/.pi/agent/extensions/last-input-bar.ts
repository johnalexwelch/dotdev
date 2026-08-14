import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ponytail: one-line "what are we working on" bar above the input editor.
// Ceiling: shows only the last human message, no history/scrollback.
// Upgrade path: setWidget with an array of the last N inputs if one line stops being enough.
const MAX_LEN = 160;

function extractText(
	content: string | { type: string; text?: string }[],
): string {
	if (typeof content === "string") return content;
	return content
		.filter(
			(c): c is { type: string; text: string } =>
				c.type === "text" && typeof c.text === "string",
		)
		.map((c) => c.text)
		.join(" ");
}

export default function (pi: ExtensionAPI) {
	pi.on("message_start", (event, ctx) => {
		if (!ctx.hasUI || event.message.role !== "user") return;
		const text = extractText(event.message.content).replace(/\s+/g, " ").trim();
		if (!text) return;
		const truncated =
			text.length > MAX_LEN ? `${text.slice(0, MAX_LEN)}…` : text;
		ctx.ui.setWidget("last-input-bar", [
			ctx.ui.theme.fg("muted", `› ${truncated}`),
		]);
	});
}
