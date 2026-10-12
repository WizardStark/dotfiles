import type { Theme, ToolRenderers } from "@earendil-works/pi-coding-agent";
import { Box, Text, type Component } from "@earendil-works/pi-tui";
import { formatDuration } from "./format.ts";

export type ToolRenderContext = Parameters<NonNullable<ToolRenderers["renderCall"]>>[2];

type ToolResult = { content?: Array<{ type: string; text?: string }> };

// Reuse the render slot, but rebuild themed text each time (including invalidation).
export function toolText(text: string, context: ToolRenderContext): Text {
  const component = context.lastComponent instanceof Text ? context.lastComponent : new Text("", 0, 0);
  component.setPaddingX(context.outputPad);
  component.setText(text);
  return component;
}

export function durationLabel(context: Pick<ToolRenderContext, "durationMs">): string {
  return context.durationMs === undefined ? "" : ` · ${formatDuration(Math.round(context.durationMs))}`;
}

export function compactCall(name: string, theme: Theme, context: ToolRenderContext) {
  const state = context.isError ? "failed" : context.isPartial ? (context.executionStarted ? "running" : "pending") : "done";
  const background = context.isError ? "toolErrorBg" : context.isPartial ? "toolPendingBg" : "toolSuccessBg";
  return toolText(theme.style(` ${name} ${state}${durationLabel(context)} `, { fg: "toolTitle", bg: background }), context);
}

export function compactResult(result: ToolResult, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: ToolRenderContext) {
  if (!options.expanded) return toolText(context.isError ? theme.fg("error", "⚠ failed (expand for details)") : "", context);
  const text = result.content?.filter((block) => block.type === "text").map((block) => block.text ?? "").join("\n") ?? "";
  return toolText(text ? `\n${theme.fg("toolOutput", text)}` : "", context);
}

// Native default-shell renderers rely on Pi for their padding/background. Our
// resolver uses a self-shell, so reproduce that framing only for expanded slots.
// Keep native children in a separate slot: collapsed Text must never be passed
// to native renderers expecting a Container/Box after an expansion toggle.
class NativeSlot extends Box {
  child?: Component;
}

export function nativeSlot(
  render: (context: ToolRenderContext) => Component,
  native: ToolRenderers,
  theme: Theme,
  context: ToolRenderContext,
): Component {
  const box = context.lastComponent instanceof NativeSlot ? context.lastComponent : new NativeSlot(0, 0);
  const child = render({ ...context, lastComponent: box.child });
  box.child = child;
  box.clear();
  box.setPaddingX(native.renderShell === "self" ? 0 : context.outputPad);
  box.setBgFn((text: string) => native.renderShell === "self" ? text
    : theme.bg(context.isError ? "toolErrorBg" : context.isPartial ? "toolPendingBg" : "toolSuccessBg", text));
  box.addChild(child);
  return box;
}

export function compactRenderers(name: string, native?: ToolRenderers): ToolRenderers {
  return {
    renderShell: "self",
    renderCall(args, theme, context) {
      if (context.expanded && native?.renderCall) {
        return nativeSlot((ctx) => native.renderCall!(args, theme, ctx), native, theme, context);
      }
      return compactCall(name, theme, context);
    },
    renderResult(result, options, theme, context) {
      if (options.expanded && native?.renderResult) {
        return nativeSlot((ctx) => native.renderResult!(result, options, theme, ctx), native, theme, context);
      }
      return compactResult(result, options, theme, context);
    },
  };
}
