import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

type Theme = ExtensionContext["ui"]["theme"];
type ToolResult = { content?: Array<{ type: string; text?: string }> };

export function compactCall(name: string, theme: Theme, context: { isError?: boolean; isPartial?: boolean }) {
  const state = context.isError ? "failed" : context.isPartial ? "running" : "done";
  const background = context.isError ? "toolErrorBg" : context.isPartial ? "toolPendingBg" : "toolSuccessBg";
  return new Text(theme.style(` ${name} ${state} `, { fg: "toolTitle", bg: background }), 0, 0);
}

export function compactResult(result: ToolResult, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: { isError?: boolean }) {
  if (options.isPartial) return new Text("", 0, 0);
  const text = result.content?.filter((block) => block.type === "text").map((block) => block.text ?? "").join("\n") ?? "";
  // No transformation of the result sent to the model or to codemode. Only the
  // TUI preview is shortened; expanded errors must still show their cause.
  if (!options.expanded) return new Text(context.isError ? theme.fg("error", "⚠ failed") : "", 0, 0);
  const lines = text.split("\n");
  const preview = lines.slice(0, 20);
  if (lines.length > 20) preview.push(`... ${lines.length - 20} more lines`);
  if (!text) return new Text(result.content?.some((block) => block.type === "image") ? theme.fg("success", "Image loaded") : "", 0, 0);
  return new Text(`\n${preview.map((line) => theme.fg("toolOutput", line)).join("\n")}`, 0, 0);
}
