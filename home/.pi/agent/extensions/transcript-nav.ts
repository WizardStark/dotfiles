import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { transcriptNodes } from "./lib/transcript-nodes.ts";
import { TranscriptOverlay } from "./lib/transcript-overlay.ts";

export default function transcriptNav(pi: ExtensionAPI) {
  let close: (() => void) | undefined;
  const dismiss = () => close?.();
  pi.on("session_start", dismiss);
  pi.on("session_tree", dismiss);
  pi.on("session_shutdown", dismiss);

  async function open(ctx: ExtensionContext) {
    if (!ctx.hasUI || ctx.mode !== "tui") {
      if (ctx.hasUI) ctx.ui.notify("Transcript navigation requires interactive terminal mode.", "warning");
      return;
    }
    if (close) return;
    const snapshot = () => transcriptNodes(ctx.sessionManager.getBranch());
    const nodes = snapshot();
    try {
      await ctx.ui.custom<void>((tui, _theme, _keys, done) => {
        let closed = false;
        close = () => {
          if (closed) return;
          closed = true;
          done();
        };
        return new TranscriptOverlay(nodes, () => ctx.ui.theme,
          () => Math.max(4, tui.terminal.rows - 2), () => tui.requestRender(), close, snapshot);
      }, {
        overlay: true,
        overlayOptions: { anchor: "center", width: "100%", maxHeight: "100%", margin: 1 },
      });
    } finally {
      close = undefined;
    }
  }

  pi.registerShortcut("alt+t", { description: "Browse transcript with Vim navigation and local folds", handler: open });
  pi.registerCommand("transcript", { description: "Read-only transcript navigator (j/k, gg/G, Enter/za, / search)", handler: async (_args, ctx) => open(ctx) });
}
