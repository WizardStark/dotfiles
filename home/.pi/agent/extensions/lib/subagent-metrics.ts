export type SubagentMetrics = {
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

  const generatedAt = (details as { generatedAt?: unknown }).generatedAt;
  const metrics = (details as { subagentMetrics?: unknown }).subagentMetrics;
  if (typeof generatedAt !== "number" && (!metrics || typeof metrics !== "object")) {
    return undefined;
  }

  return {
    generatedAt: typeof generatedAt === "number" ? generatedAt : undefined,
    subagentMetrics: metrics && typeof metrics === "object" ? (metrics as SubagentMetrics) : undefined,
  };
}

export function getSubagentMetrics(message: unknown): SubagentMetrics | undefined {
  return getSubagentDetails(message)?.subagentMetrics;
}
