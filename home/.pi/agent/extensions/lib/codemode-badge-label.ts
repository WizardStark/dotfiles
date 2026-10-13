import type { CodemodeToolDetails } from "@earendil-works/pi-coding-agent";

type NestedCall = CodemodeToolDetails["calls"][number];
export type CodemodeTreeEntry = { branch: "├─" | "└─"; label: string; tone: "toolOutput" | "error" | "dim" };
const MAX_COLLAPSED_TOOLS = 11;

export function codemodeTreeEntries(calls: NestedCall[], isError: boolean): CodemodeTreeEntry[] {
  const groups = new Map<string, { count: number; failed: boolean }>();
  for (const call of calls) {
    const group = groups.get(call.name) ?? { count: 0, failed: false };
    group.count++;
    group.failed ||= call.status === "error";
    groups.set(call.name, group);
  }
  const hidden = Math.max(0, groups.size - MAX_COLLAPSED_TOOLS);
  const entries: Array<Omit<CodemodeTreeEntry, "branch">> = [];
  if (hidden) entries.push({ label: `… ${hidden} earlier tools (expand to see all)`, tone: "dim" });
  for (const [name, { count, failed }] of [...groups].slice(hidden)) {
    entries.push({
      label: `${name}${count > 1 ? ` x${count}` : ""}${failed ? " ⚠ failed" : ""}`,
      tone: failed ? "error" : "toolOutput",
    });
  }
  if (isError && !entries.some((entry) => entry.tone === "error")) {
    entries.push({ label: "⚠ codemode failed (expand for details)", tone: "error" });
  }
  return entries.map((entry, index) => ({
    ...entry,
    branch: index === entries.length - 1 ? "└─" : "├─",
  }));
}
