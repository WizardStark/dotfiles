import type { CodemodeToolDetails } from "@earendil-works/pi-coding-agent";

export function codemodeCallLabel(call: CodemodeToolDetails["calls"][number]): string {
  let args = call.args;
  try {
    const parsed: unknown = JSON.parse(args);
    if (parsed && typeof parsed === "object" && "command" in parsed && typeof parsed.command === "string") {
      args = parsed.command;
    }
  } catch {
    // Pi bounds argument previews; long JSON strings may be truncated.
  }
  const label = args.replace(/\s+/g, " ").trim();
  return `${call.name}${label ? `: ${label}` : ""}${call.status === "error" ? " ⚠ failed" : ""}`;
}
