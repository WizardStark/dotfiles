import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createStatuslineItem, getStatuslineSessionKey } from "./statusline/registry";

type SubagentMetrics = {
  cost?: {
    amount?: number;
    estimated?: boolean;
    knownRate?: boolean;
    unknownModel?: string;
  };
};

type ReviewerMetricsEvent = {
  generatedAt?: number;
  sessionKey?: string;
  subagentMetrics?: SubagentMetrics;
};

type CostSummary = {
  mainTotal: number;
  subTotal: number;
  hasUnknownSubCost: boolean;
  sawSubagentMessage: boolean;
  unknownModels: Set<string>;
};

const STATUS_KEY = "copilot-cost";
const TOKENS_PER_MILLION = 1_000_000;

const statuslineItem = createStatuslineItem({
  id: STATUS_KEY,
  side: "left",
  order: 30,
  importance: 40,
  background: "userMessageBg",
});

// Rates from GitHub Copilot models and pricing docs
// https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing
// Accessed 2026-06-03. Values are USD per 1M tokens.
type ModelRates = {
  input: number;
  cachedInput: number;
  output: number;
  cacheWrite?: number;
};

const MODEL_RATES: Record<string, ModelRates> = {
  "gpt-4.1": { input: 2.0, cachedInput: 0.5, output: 8.0 },
  "gpt-5-mini": { input: 0.25, cachedInput: 0.025, output: 2.0 },
  "gpt-5.2": { input: 1.75, cachedInput: 0.175, output: 14.0 },
  "gpt-5.2-codex": { input: 1.75, cachedInput: 0.175, output: 14.0 },
  "gpt-5.3-codex": { input: 1.75, cachedInput: 0.175, output: 14.0 },
  "gpt-5.4": { input: 2.5, cachedInput: 0.25, output: 15.0 },
  "gpt-5.4-mini": { input: 0.75, cachedInput: 0.075, output: 4.5 },
  "gpt-5.4-nano": { input: 0.2, cachedInput: 0.02, output: 1.25 },
  "gpt-5.5": { input: 5.0, cachedInput: 0.5, output: 30.0 },
  "claude-haiku-4.5": { input: 1.0, cachedInput: 0.1, cacheWrite: 1.25, output: 5.0 },
  "claude-sonnet-4": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
  "claude-sonnet-4.5": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
  "claude-sonnet-4.6": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
  "claude-opus-4.5": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
  "claude-opus-4.6": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
  "claude-opus-4.7": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
  "claude-opus-4.8": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
  "mai-code-1-flash": { input: 0.75, cachedInput: 0.075, output: 4.5 },
};

function normalizeModelId(model: string | undefined): string {
  const raw = (model ?? "").trim().toLowerCase();
  const withoutBuildSuffix = raw.split("@")[0] || raw;
  const withoutThinkingSuffix = withoutBuildSuffix.replace(/:(off|minimal|low|medium|high|xhigh)$/, "");
  const withoutPathPrefix = withoutThinkingSuffix.split("/").pop() || withoutThinkingSuffix;
  const withoutProviderPrefix = withoutPathPrefix.includes(":")
    ? withoutPathPrefix.split(":").slice(1).join(":") || withoutPathPrefix
    : withoutPathPrefix;
  return withoutProviderPrefix.replace(/[_\s]+/g, "-").replace(/-+/g, "-");
}

function formatUsd(amount: number): string {
  if (amount >= 10) return `$${amount.toFixed(2)}`;
  if (amount >= 1) return `$${amount.toFixed(3)}`;
  return `$${amount.toFixed(4)}`;
}

function estimateUsageCost(message: AssistantMessage): { amount: number; estimated: boolean; knownRate: boolean } {
  const usage = message.usage;
  if (!usage) {
    return { amount: 0, estimated: false, knownRate: true };
  }

  const actualCost = usage.cost?.total;
  const provider = message.provider ?? "";
  if (
    typeof actualCost === "number" &&
    (actualCost > 0 || (actualCost === 0 && provider !== "" && provider !== "github-copilot"))
  ) {
    return { amount: actualCost, estimated: false, knownRate: true };
  }

  const rates = MODEL_RATES[normalizeModelId(message.model)];
  if (!rates) {
    return { amount: 0, estimated: true, knownRate: false };
  }

  const input = usage.input ?? 0;
  const cacheRead = usage.cacheRead ?? 0;
  const cacheWrite = usage.cacheWrite ?? 0;
  const output = usage.output ?? 0;
  const amount =
    (input * rates.input +
      cacheRead * rates.cachedInput +
      output * rates.output +
      cacheWrite * (rates.cacheWrite ?? 0)) /
    TOKENS_PER_MILLION;

  return { amount, estimated: true, knownRate: true };
}

function getSubagentDetails(message: unknown): ReviewerMetricsEvent | undefined {
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

function getSubagentMetrics(message: unknown): SubagentMetrics | undefined {
  return getSubagentDetails(message)?.subagentMetrics;
}

function buildCostSummary(ctx: ExtensionContext, pendingEvent?: ReviewerMetricsEvent): CostSummary {
  let mainTotal = 0;
  let subTotal = 0;
  let sawSubagentMessage = false;
  let hasUnknownSubCost = false;
  let latestPersistedGeneratedAt: number | undefined;
  const unknownModels = new Set<string>();

  const applySubagentMetrics = (metrics: SubagentMetrics | undefined) => {
    sawSubagentMessage ||= metrics !== undefined;

    const cost = metrics?.cost;
    if (typeof cost?.amount === "number") {
      subTotal += cost.amount;
      if (cost.knownRate === false) {
        unknownModels.add(cost.unknownModel || "unknown-model");
      }
    } else if (metrics !== undefined) {
      hasUnknownSubCost = true;
      if (cost?.knownRate === false) {
        unknownModels.add(cost.unknownModel || "unknown-model");
      }
    }
  };

  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") {
      continue;
    }

    const details = getSubagentDetails(entry.message);
    if (typeof details?.generatedAt === "number") {
      latestPersistedGeneratedAt = Math.max(latestPersistedGeneratedAt ?? details.generatedAt, details.generatedAt);
    }
    applySubagentMetrics(details?.subagentMetrics);

    if (entry.message.role !== "assistant") {
      continue;
    }

    const message = entry.message as AssistantMessage;
    if (message.provider !== "github-copilot") {
      continue;
    }

    const { amount, knownRate } = estimateUsageCost(message);
    mainTotal += amount;
    if (!knownRate) {
      unknownModels.add(normalizeModelId(message.model) || "unknown-model");
    }
  }

  if (
    pendingEvent?.subagentMetrics &&
    (latestPersistedGeneratedAt === undefined ||
      (pendingEvent.generatedAt ?? Number.POSITIVE_INFINITY) > latestPersistedGeneratedAt)
  ) {
    applySubagentMetrics(pendingEvent.subagentMetrics);
  }

  return {
    mainTotal,
    subTotal,
    hasUnknownSubCost,
    sawSubagentMessage,
    unknownModels,
  };
}

function formatSubLabel(summary: CostSummary) {
  return summary.sawSubagentMessage && summary.hasUnknownSubCost
    ? summary.subTotal > 0
      ? `${formatUsd(summary.subTotal)}+?`
      : "+?"
    : formatUsd(summary.subTotal);
}

function buildStatus(summary: CostSummary) {
  const unknownSuffix = summary.unknownModels.size > 0 ? ` +${summary.unknownModels.size} unk` : "";
  return `Main ${formatUsd(summary.mainTotal)} · Sub ${formatSubLabel(summary)}${unknownSuffix}`;
}

function buildCompactStatus(summary: CostSummary) {
  const unknownSuffix = summary.unknownModels.size > 0 ? " +u" : "";
  return `M${formatUsd(summary.mainTotal)} · S${formatSubLabel(summary)}${unknownSuffix}`;
}

export default function copilotCost(pi: ExtensionAPI) {
  let currentCtx: ExtensionContext | undefined;
  let currentSessionKey = "ephemeral";
  let pendingReviewerMetrics: ReviewerMetricsEvent | undefined;

  function renderStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) {
      return;
    }

    const summary = buildCostSummary(ctx, pendingReviewerMetrics);
    statuslineItem.set(
      {
        content: ctx.ui.theme.fg("dim", buildStatus(summary)),
        compactContent: ctx.ui.theme.fg("dim", buildCompactStatus(summary)),
      },
      getStatuslineSessionKey(ctx),
    );
  }

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    pendingReviewerMetrics = undefined;
    renderStatus(ctx);
  });

  pi.events.on("reviewer-subagent:metrics", (data) => {
    const event = (data ?? {}) as ReviewerMetricsEvent;
    if (event.sessionKey && event.sessionKey !== currentSessionKey) {
      return;
    }

    pendingReviewerMetrics = event;
    if (currentCtx) {
      renderStatus(currentCtx);
    }
  });

  pi.on("message_end", async (event, ctx) => {
    if (getSubagentMetrics(event.message)) {
      currentCtx = ctx;
      currentSessionKey = getStatuslineSessionKey(ctx);
      renderStatus(ctx);
    }
  });

  pi.on("agent_end", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    renderStatus(ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    renderStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    currentCtx = undefined;
    pendingReviewerMetrics = undefined;
    statuslineItem.clear(getStatuslineSessionKey(ctx));
  });
}
