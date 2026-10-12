import type { Usage } from "@earendil-works/pi-ai";
export type SubagentMetrics = {
  usage?: Usage;
  cost?: {
    amount?: number;
    estimated?: boolean;
    knownRate?: boolean;
    unknownModel?: string;
  };
  throughput?: {
    ttftMs?: number;
    generationDurationMs?: number;
    outputTokens?: number;
    generationTokensPerSecond?: number;
  };
};

export type SubagentMetricsEvent = {
  id?: string;
  generatedAt?: number;
  sessionKey?: string;
  subagentMetrics?: SubagentMetrics;
  source?: "tool" | "command";
};

export function getSubagentDetails(message: unknown): SubagentMetricsEvent | undefined {
  if (!message || typeof message !== "object") {
    return undefined;
  }

  const details = (message as { details?: unknown }).details;
  if (!details || typeof details !== "object") {
    return undefined;
  }

  const id = (details as { id?: unknown }).id;
  const generatedAt = (details as { generatedAt?: unknown }).generatedAt;
  const directMetrics = (details as { subagentMetrics?: unknown }).subagentMetrics;
  // Advisor packets written before cost tracking stored metrics beneath `usage`.
  // Keep reading that shape so resumed sessions include their advisor spend.
  const legacyMetrics = (details as { usage?: { subagentMetrics?: unknown } }).usage?.subagentMetrics;
  const metrics = directMetrics ?? legacyMetrics;
  if (typeof generatedAt !== "number" && (!metrics || typeof metrics !== "object")) {
    return undefined;
  }

  return {
    id: typeof id === "string" ? id : undefined,
    generatedAt: typeof generatedAt === "number" ? generatedAt : undefined,
    subagentMetrics: metrics && typeof metrics === "object" ? (metrics as SubagentMetrics) : undefined,
  };
}

export function getSubagentMetrics(message: unknown): SubagentMetrics | undefined {
  return getSubagentDetails(message)?.subagentMetrics;
}
