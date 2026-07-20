import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * Extract only the graph overview useful at session start.
 *
 * ponytail: omit bulk communities and generated suggested questions; use
 * `graphify query` when that detail is needed.
 */
function extractCompactReport(report: string): string {
	const lines = report.split("\n");
	const sections: string[] = [];
	let inCommunityHubs = false;
	let skippingBulk = false;

	for (const line of lines) {
		if (line.startsWith("## Communities")) {
			sections.push("## Communities");
			sections.push("[omitted — use `graphify query <topic>` or open `graphify-out/GRAPH_REPORT.md`]");
			skippingBulk = true;
			continue;
		}

		if (skippingBulk) {
			if (line.startsWith("## Knowledge Gaps")) skippingBulk = false;
			else continue;
		}

		if (line.startsWith("## Suggested Questions")) break;

		// Stop collecting numbered community hub links (e.g. "- [[_COMMUNITY_Community 20|...")
		if (inCommunityHubs && /^\- \[\[_COMMUNITY_Community \d+\|/.test(line)) {
			sections.push("- [... numbered communities omitted — use `graphify query` to navigate ...]");
			inCommunityHubs = false;
			continue;
		}

		if (line.startsWith("## Community Hubs")) inCommunityHubs = true;
		if (line.startsWith("## God Nodes")) inCommunityHubs = false;

		sections.push(line);
	}

	return sections.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, _ctx) => {
		if (process.env.PI_GRAPHIFY_CONTEXT === "0") return;

		const cwd = event.systemPromptOptions?.cwd ?? process.cwd();
		const reportPath = join(cwd, "graphify-out", "GRAPH_REPORT.md");

		if (!existsSync(reportPath)) return;

		const report = readFileSync(reportPath, "utf-8");
		const maxChars = Number(process.env.PI_GRAPHIFY_CONTEXT_MAX_CHARS ?? 12000);
		const compact = extractCompactReport(report).slice(0, maxChars);

		return {
			message: {
				customType: "graphify-context",
				content: `<graphify_knowledge_graph>\n${compact}\n</graphify_knowledge_graph>`,
				display: false,
			},
		};
	});
}
