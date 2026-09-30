import { createCodemodeExtension, type CodemodeToolDetails, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { codemodeCallLabel } from "./lib/codemode-badge-label.ts";

// Pi has no renderer-only API. Wrap its public codemode extension factory rather
// than copying the sandbox, tool declaration, session store, or usage handling.
// Disable builtin:codemode in settings so this is the sole registration.
export default function codemodeBadge(pi: ExtensionAPI) {
  const rendererOnlyApi = new Proxy(pi, {
    get(target, key, receiver) {
      if (key !== "registerTool") return Reflect.get(target, key, receiver);
      return (tool: Parameters<ExtensionAPI["registerTool"]>[0]) => {
        if (tool.name !== "codemode") throw new Error("Unexpected tool registered by codemode extension");
        const { renderCall: originalCall, renderResult: originalResult } = tool;
        pi.registerTool({
          ...tool,
          renderShell: "self",
          renderCall(args, theme, context) {
            if (context.expanded && originalCall) return originalCall(args, theme, context);
            const bg = context.isError ? "toolErrorBg" : context.isPartial ? "toolPendingBg" : "toolSuccessBg";
            return new Text(theme.style(" codemode ", { fg: "toolTitle", bg }), 0, 0);
          },
          renderResult(result, options, theme, context) {
            if (options.expanded && originalResult) return originalResult(result, options, theme, context);
            const calls = (result.details as CodemodeToolDetails | undefined)?.calls ?? [];
            const lines = calls.map((call) => theme.fg(call.status === "error" ? "error" : "toolOutput", codemodeCallLabel(call)));
            if (context.isError && !calls.some((call) => call.status === "error")) {
              lines.push(theme.fg("error", "⚠ codemode failed (expand for details)"));
            }
            return new Text(lines.length ? `\n${lines.join("\n")}` : "", 0, 0);
          },
        });
      };
    },
  });
  return createCodemodeExtension()(rendererOnlyApi);
}
