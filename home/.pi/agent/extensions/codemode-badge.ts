import type { CodemodeToolDetails, ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { compactCall, compactResult, hasNativeResult, nativeSlot, toolText } from "./lib/compact-tool-renderers.ts";
import { codemodeTreeEntries } from "./lib/codemode-badge-label.ts";

// Keep the builtin extension as the sole owner of codemode execution and state.
export default function codemodeBadge(pi: ExtensionAPI) {
  pi.registerToolRenderer((name, next) => {
    const native = next();
    if (name !== "codemode") return native;
    return {
      renderShell: "self",
      renderCall(args, theme, context) {
        if (context.expanded && native?.renderCall) {
          return nativeSlot((ctx) => native.renderCall!(args, theme, ctx), native, theme, context);
        }
        return compactCall("codemode", theme, context);
      },
      renderResult(result, options, theme, context) {
        if (native?.renderResult && (options.expanded || hasNativeResult(context))) {
          const component = nativeSlot((ctx) => native.renderResult!(result, options, theme, ctx), native, theme, context, "result");
          if (options.expanded) return component;
        }
        if (options.expanded) return compactResult(result, options, theme, context);
        const calls = (result.details as CodemodeToolDetails | undefined)?.calls ?? [];
        const lines = codemodeTreeEntries(calls, context.isError).map(
          ({ branch, label, tone }) => `${theme.fg("dim", branch)} ${theme.fg(tone, label)}`,
        );
        return toolText(lines.length ? `\n${lines.join("\n")}` : "", context);
      },
    };
  });
}
