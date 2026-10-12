import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import { getSubagentDetails, type SubagentMetricsEvent } from "./subagent-metrics.ts";

export function subagentRecord(entry: SessionEntry): unknown {
  if (entry.type === "message") return entry.message;
  if (entry.type === "custom_message") return entry;
  if (entry.type === "custom" && entry.customType === "subagent-usage") return { details: entry.data };
  return undefined;
}

/** Replace repeated envelopes by request ID; reconcile only against that ID. */
export class PendingMetrics {
  private readonly events = new Map<string, SubagentMetricsEvent>();

  add(event: SubagentMetricsEvent) {
    if (!event.subagentMetrics) return;
    const id = event.id ?? `legacy:${event.generatedAt}`;
    this.events.set(id, event);
  }

  clear() { this.events.clear(); }

  unpersisted(branch: readonly SessionEntry[]): SubagentMetricsEvent[] {
    const ids = new Set<string>();
    for (const entry of branch) {
      const details = getSubagentDetails(subagentRecord(entry));
      if (!details) continue;
      if (details.id) ids.add(details.id);
      else if (entry.type === "message" && entry.message.role === "toolResult") ids.add(entry.message.toolCallId);
      if (!details.id && details.generatedAt !== undefined) ids.add(`legacy:${details.generatedAt}`);
    }
    for (const id of ids) this.events.delete(id);
    return [...this.events.values()];
  }
}
