// ponytail: reimplements pi's default footer stats line just to recolor the
// context % thresholds (0-40 success / 40-80 warning / 80-100 error).
// Ceiling: duplicates footer.js layout logic; if pi's footer format changes
// upstream this drifts out of sync. Upgrade path: replace with a real
// `contextBarColors` setting if pi ever exposes one.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => ({
      invalidate() {},
      dispose: footerData.onBranchChange(() => tui.requestRender()),
      render(width: number): string[] {
        const usage = ctx.getContextUsage();
        const pct = usage?.percent ?? 0;
        const window = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
        const fmt = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`);
        const label = `${usage?.percent != null ? pct.toFixed(1) : "?"}%/${fmt(window)}`;
        const color = pct > 80 ? "error" : pct > 40 ? "warning" : "success";
        const left = theme.fg("dim", `${ctx.model?.id || "no-model"} `) + theme.fg(color, label);
        const branch = footerData.getGitBranch();
        const right = theme.fg("dim", branch ? `(${branch})` : "");
        const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
        return [truncateToWidth(left + pad + right, width)];
      },
    }));
  });
}
