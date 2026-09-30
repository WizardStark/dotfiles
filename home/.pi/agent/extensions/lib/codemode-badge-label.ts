import type { CodemodeToolDetails } from "@earendil-works/pi-coding-agent";

type NestedCall = CodemodeToolDetails["calls"][number];
export type CodemodeTreeEntry = { branch: "├─" | "└─"; label: string; tone: "toolOutput" | "error" | "dim" };
const MAX_COLLAPSED_CALLS = 11;

export function codemodeCallLabel(call: NestedCall): string {
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

export function codemodeTreeEntries(calls: NestedCall[], isError: boolean): CodemodeTreeEntry[] {
  const hidden = Math.max(0, calls.length - MAX_COLLAPSED_CALLS);
  const entries: Array<Omit<CodemodeTreeEntry, "branch">> = [];
  if (hidden) entries.push({ label: `… ${hidden} earlier calls (expand to see all)`, tone: "dim" });
  for (const call of calls.slice(hidden)) {
    entries.push({ label: codemodeCallLabel(call), tone: call.status === "error" ? "error" : "toolOutput" });
  }
  if (isError && !calls.some((call) => call.status === "error")) {
    entries.push({ label: "⚠ codemode failed (expand for details)", tone: "error" });
  }
  return entries.map((entry, index) => ({
    ...entry,
    branch: index === entries.length - 1 ? "└─" : "├─",
  }));
}
