import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { formatDuration } from "./lib/format.ts";
import {
  getSubagentDetails,
  getSubagentMetrics,
  type SubagentMetrics,
  type SubagentMetricsEvent,
} from "./lib/subagent-metrics.ts";
import { createStatuslineItem, getStatuslineSessionKey } from "./statusline/registry";

const STATUS_KEY = "token-throughput";
const STATUS_INTERVAL_MS = 100;

const USAGE_EMPTY = "In/Out —";

const statuslineItem = createStatuslineItem({
  id: STATUS_KEY,
  side: "left",
  order: 10,
  importance: 70,
  background: "toolPendingBg",
});

type ActiveRequest = {
  turnIndex?: number;
  startedAt: number;
  firstTokenAt?: number;
  failureStatusCode?: number;
  estimatedInputTokens?: number;
};

type CompletedSnapshot = {
  ttftMs?: number;
  generationDurationMs?: number;
  inputTokens?: number;
  outputTokens?: number;
  generationTokensPerSecond?: number;
};

type FailedSnapshot = {
  durationMs: number;
  statusCode?: number;
};

type UsageStats = {
  count: number;
  mean?: number;
  median?: number;
};

function formatTokensPerSecond(tokensPerSecond: number | undefined): string {
  if (!tokensPerSecond || !Number.isFinite(tokensPerSecond) || tokensPerSecond <= 0) {
    return "—";
  }

  if (tokensPerSecond >= 100) return `${Math.round(tokensPerSecond)} tok/s`;
  if (tokensPerSecond >= 10) return `${tokensPerSecond.toFixed(1)} tok/s`;
  return `${tokensPerSecond.toFixed(2)} tok/s`;
}

function formatTokenCount(tokens: number | undefined): string {
  if (tokens === undefined || !Number.isFinite(tokens) || tokens < 0) {
    return "—";
  }

  if (tokens >= 100_000) return `${Math.round(tokens / 1_000)}k`;
  if (tokens >= 10_000) return `${(tokens / 1_000).toFixed(1)}k`;
  if (tokens >= 1_000) return `${(tokens / 1_000).toFixed(2)}k`;
  return `${Math.round(tokens)}`;
}

function calculateMean(samples: number[]): number | undefined {
  if (samples.length === 0) {
    return undefined;
  }

  const total = samples.reduce((sum, sample) => sum + sample, 0);
  return total / samples.length;
}

function calculateMedian(samples: number[]): number | undefined {
  if (samples.length === 0) {
    return undefined;
  }

  const sorted = [...samples].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[middle];
  }

  return (sorted[middle - 1]! + sorted[middle]!) / 2;
}

function buildUsageStats(samples: number[]): UsageStats {
  return {
    count: samples.length,
    mean: calculateMean(samples),
    median: calculateMedian(samples),
  };
}

function buildUsageSummary(
  theme: ExtensionContext["ui"]["theme"],
  inputSamples: number[],
  outputSamples: number[],
): string {
  const separator = theme.fg("dim", " · ");
  const inputStats = buildUsageStats(inputSamples);
  const outputStats = buildUsageStats(outputSamples);

  if (inputStats.count === 0 && outputStats.count === 0) {
    return theme.fg("dim", USAGE_EMPTY);
  }

  const countLabel =
    inputStats.count === outputStats.count
      ? `${inputStats.count}`
      : `${inputStats.count}/${outputStats.count}`;

  const parts: string[] = [theme.fg("dim", countLabel)];

  if (inputStats.count > 0) {
    parts.push(
      theme.fg(
        "dim",
        `↑μ${formatTokenCount(inputStats.mean)} M${formatTokenCount(inputStats.median)}`,
      ),
    );
  } else {
    parts.push(theme.fg("dim", "↑—"));
  }

  if (outputStats.count > 0) {
    parts.push(
      theme.fg(
        "dim",
        `↓μ${formatTokenCount(outputStats.mean)} M${formatTokenCount(outputStats.median)}`,
      ),
    );
  } else {
    parts.push(theme.fg("dim", "↓—"));
  }

  return parts.join(separator);
}

function setStatus(ctx: ExtensionContext, content: string | undefined, compactContent = content) {
  if (!ctx.hasUI) {
    return;
  }

  if (!content) {
    statuslineItem.clear(getStatuslineSessionKey(ctx));
    return;
  }

  statuslineItem.set({ content, compactContent }, getStatuslineSessionKey(ctx));
}


function isSubagentMessage(message: unknown): boolean {
  if (!message || typeof message !== "object") {
    return false;
  }

  const typedMessage = message as {
    role?: string;
    toolName?: string;
    customType?: string;
    details?: unknown;
  };

  return (
    typedMessage.toolName === "review_changes" ||
    typedMessage.customType === "reviewer-report" ||
    getSubagentMetrics(typedMessage)?.throughput !== undefined
  );
}

function withEstimatedInputUsage(
  message: AssistantMessage,
  estimatedInputTokens: number | undefined,
): AssistantMessage {
  if (
    estimatedInputTokens === undefined ||
    !Number.isFinite(estimatedInputTokens) ||
    message.usage?.input !== undefined
  ) {
    return message;
  }

  return {
    ...message,
    usage: {
      ...(message.usage ?? {}),
      input: estimatedInputTokens,
    },
  };
}

function buildSubagentSummary(ctx: ExtensionContext, pendingEvent?: SubagentMetricsEvent): string {
  const branch = ctx.sessionManager.getBranch();
  let latestPersistedGeneratedAt: number | undefined;
  let latestPersistedThroughput: SubagentMetrics["throughput"] | undefined;

  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type !== "message" || !isSubagentMessage(entry.message)) {
      continue;
    }

    const details = getSubagentDetails(entry.message);
    if (typeof details?.generatedAt === "number" && latestPersistedGeneratedAt === undefined) {
      latestPersistedGeneratedAt = details.generatedAt;
    }

    const throughput = details?.subagentMetrics?.throughput;
    if (!throughput) {
      continue;
    }

    latestPersistedThroughput = throughput;
    break;
  }

  const throughput =
    pendingEvent?.subagentMetrics?.throughput &&
    (latestPersistedGeneratedAt === undefined ||
      (pendingEvent.generatedAt ?? Number.POSITIVE_INFINITY) > latestPersistedGeneratedAt)
      ? pendingEvent.subagentMetrics.throughput
      : latestPersistedThroughput;

  if (!throughput) {
    return "Sub —";
  }

  const ttft = throughput.ttftMs === undefined ? "TTFT —" : `TTFT ${formatDuration(throughput.ttftMs)}`;
  return `Sub ${ttft} · ${formatTokensPerSecond(throughput.generationTokensPerSecond)}`;
}

export default function tokenThroughput(pi: ExtensionAPI) {
  let currentCtx: ExtensionContext | undefined;
  let currentSessionKey = "ephemeral";
  let pendingReviewerMetrics: SubagentMetricsEvent | undefined;
  let activeRequest: ActiveRequest | undefined;
  let currentTurnIndex: number | undefined;
  let lastCompleted: CompletedSnapshot | undefined;
  let lastFailure: FailedSnapshot | undefined;
  let statusTimer: ReturnType<typeof setInterval> | undefined;
  let promptTokenSamples: number[] = [];
  let outputTokenSamples: number[] = [];

  function isCurrentRequestActive() {
    if (!activeRequest) {
      return false;
    }

    if (activeRequest.turnIndex === undefined) {
      return true;
    }

    if (currentTurnIndex === undefined) {
      return false;
    }

    return activeRequest.turnIndex === currentTurnIndex;
  }

  function clearLiveStatus() {
    if (statusTimer) {
      clearInterval(statusTimer);
      statusTimer = undefined;
    }
  }

  function buildStatusWithUsage(ctx: ExtensionContext, status: string): string {
    return `${status}${ctx.ui.theme.fg("dim", " · ")}${buildUsageSummary(
      ctx.ui.theme,
      promptTokenSamples,
      outputTokenSamples,
    )}`;
  }

  function resetUsageSamples() {
    promptTokenSamples = [];
    outputTokenSamples = [];
  }

  function recordUsageSample(inputTokens: number | undefined, outputTokens: number | undefined) {
    if (inputTokens !== undefined && Number.isFinite(inputTokens) && inputTokens >= 0) {
      promptTokenSamples.push(inputTokens);
    }

    if (outputTokens !== undefined && Number.isFinite(outputTokens) && outputTokens >= 0) {
      outputTokenSamples.push(outputTokens);
    }
  }

  function rebuildUsageSamples(ctx: ExtensionContext) {
    resetUsageSamples();

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message" || entry.message.role !== "assistant" || isSubagentMessage(entry.message)) {
        continue;
      }

      const message = entry.message as AssistantMessage;
      recordUsageSample(message.usage?.input, message.usage?.output);
    }
  }

  function resetBranchScopedState(ctx: ExtensionContext) {
    clearLiveStatus();
    activeRequest = undefined;
    currentTurnIndex = undefined;
    lastCompleted = undefined;
    lastFailure = undefined;
    pendingReviewerMetrics = undefined;
    rebuildUsageSamples(ctx);
  }

  function refreshUsageSamples(ctx: ExtensionContext) {
    rebuildUsageSamples(ctx);
  }

  function renderIdleStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) {
      return;
    }

    const subagentSummary = buildSubagentSummary(ctx, pendingReviewerMetrics);

    if (lastFailure) {
      const code = lastFailure.statusCode ? ` HTTP ${lastFailure.statusCode}` : "";
      setStatus(
        ctx,
        buildStatusWithUsage(
          ctx,
          `${ctx.ui.theme.fg("warning", "⚠")}${ctx.ui.theme.fg("dim", ` Resp failed${code} after ${formatDuration(lastFailure.durationMs)} · ${subagentSummary}`)}`,
        ),
        `${ctx.ui.theme.fg("warning", "⚠")}${ctx.ui.theme.fg("dim", ` Fail${code || ""} · ${formatDuration(lastFailure.durationMs)}`)}`,
      );
      return;
    }

    if (!lastCompleted) {
      setStatus(
        ctx,
        buildStatusWithUsage(ctx, ctx.ui.theme.fg("dim", `Resp — · ${subagentSummary}`)),
        ctx.ui.theme.fg("dim", "Resp —"),
      );
      return;
    }

    const ttft =
      lastCompleted.ttftMs === undefined ? "TTFT —" : `TTFT ${formatDuration(lastCompleted.ttftMs)}`;
    const prompt =
      lastCompleted.inputTokens === undefined ? "P —" : `P ${formatTokenCount(lastCompleted.inputTokens)}`;
    const output =
      lastCompleted.outputTokens === undefined ? "O —" : `O ${formatTokenCount(lastCompleted.outputTokens)}`;
    const rate = formatTokensPerSecond(lastCompleted.generationTokensPerSecond);
    setStatus(
      ctx,
      buildStatusWithUsage(
        ctx,
        `${ctx.ui.theme.fg("accent", "⚡")}${ctx.ui.theme.fg("dim", ` Main ${ttft} · ${prompt} · ${output} · ${rate} · ${subagentSummary}`)}`,
      ),
      `${ctx.ui.theme.fg("accent", "⚡")}${ctx.ui.theme.fg("dim", ` ${ttft} · ${rate}`)}`,
    );
  }

  function renderRunningStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) {
      return;
    }

    if (!activeRequest) {
      renderIdleStatus(ctx);
      return;
    }

    const subagentSummary = buildSubagentSummary(ctx, pendingReviewerMetrics);

    if (activeRequest.firstTokenAt === undefined) {
      const elapsed = formatDuration(Math.max(0, Date.now() - activeRequest.startedAt));
      const promptEstimate =
        activeRequest.estimatedInputTokens === undefined
          ? "P ~—"
          : `P ~${formatTokenCount(activeRequest.estimatedInputTokens)}`;
      setStatus(
        ctx,
        buildStatusWithUsage(
          ctx,
          `${ctx.ui.theme.fg("warning", "…")}${ctx.ui.theme.fg("dim", ` Main waiting ${elapsed} · ${promptEstimate} · ${subagentSummary}`)}`,
        ),
        `${ctx.ui.theme.fg("warning", "…")}${ctx.ui.theme.fg("dim", ` Wait ${elapsed}`)}`,
      );
      return;
    }

    const ttft = Math.max(0, activeRequest.firstTokenAt - activeRequest.startedAt);
    const streamingFor = formatDuration(Math.max(0, Date.now() - activeRequest.firstTokenAt));
    const promptEstimate =
      activeRequest.estimatedInputTokens === undefined ? "P ~—" : `P ~${formatTokenCount(activeRequest.estimatedInputTokens)}`;
    setStatus(
      ctx,
      buildStatusWithUsage(
        ctx,
        `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` Main TTFT ${formatDuration(ttft)} · ${promptEstimate} · streaming ${streamingFor} · ${subagentSummary}`)}`,
      ),
      `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` TTFT ${formatDuration(ttft)} · ${streamingFor}`)}`,
    );
  }

  function startLiveStatus(ctx: ExtensionContext) {
    clearLiveStatus();

    if (!ctx.hasUI) {
      return;
    }

    const refresh = () => {
      renderRunningStatus(ctx);
    };

    refresh();
    statusTimer = setInterval(refresh, STATUS_INTERVAL_MS);
  }

  function finishRequest(ctx: ExtensionContext, message: AssistantMessage) {
    if (!activeRequest || !isCurrentRequestActive()) {
      return;
    }

    const finishedAt = Date.now();
    const ttftMs =
      activeRequest.firstTokenAt === undefined
        ? undefined
        : Math.max(0, activeRequest.firstTokenAt - activeRequest.startedAt);
    const generationDurationMs =
      activeRequest.firstTokenAt === undefined
        ? undefined
        : Math.max(1, finishedAt - activeRequest.firstTokenAt);
    const inputTokens =
      message.usage?.input !== undefined && Number.isFinite(message.usage.input)
        ? message.usage.input
        : activeRequest.estimatedInputTokens;
    const outputTokens =
      message.usage?.output !== undefined && Number.isFinite(message.usage.output)
        ? Math.max(0, message.usage.output)
        : undefined;
    const generationTokensPerSecond =
      outputTokens !== undefined && outputTokens > 0 && generationDurationMs !== undefined
        ? outputTokens / (generationDurationMs / 1_000)
        : undefined;

    lastCompleted = {
      ttftMs,
      generationDurationMs,
      inputTokens,
      outputTokens,
      generationTokensPerSecond,
    };
    recordUsageSample(inputTokens, outputTokens);
    lastFailure = undefined;
    activeRequest = undefined;

    clearLiveStatus();
    renderIdleStatus(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    resetBranchScopedState(ctx);
    renderIdleStatus(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    refreshUsageSamples(ctx);
    renderIdleStatus(ctx);
  });

  pi.on("session_compact", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    refreshUsageSamples(ctx);
    renderIdleStatus(ctx);
  });

  pi.events.on("subagent:metrics", (data) => {
    const event = (data ?? {}) as SubagentMetricsEvent;
    if (event.sessionKey && event.sessionKey !== currentSessionKey) {
      return;
    }

    pendingReviewerMetrics = event;
    if (currentCtx) {
      renderIdleStatus(currentCtx);
    }
  });

  pi.on("turn_start", async (event) => {
    currentTurnIndex = event.turnIndex;

    if (activeRequest && activeRequest.turnIndex === undefined) {
      activeRequest.turnIndex = event.turnIndex;
    }
  });

  pi.on("before_provider_request", async (_event, ctx) => {
    activeRequest = {
      turnIndex: currentTurnIndex,
      startedAt: Date.now(),
      estimatedInputTokens: ctx.getContextUsage()?.tokens,
    };
    startLiveStatus(ctx);
  });

  pi.on("after_provider_response", async (event) => {
    if (!activeRequest || !isCurrentRequestActive() || event.status < 400) {
      return;
    }

    activeRequest.failureStatusCode = event.status;
  });

  pi.on("message_update", async (event, ctx) => {
    if (
      event.message.role !== "assistant" ||
      !activeRequest ||
      !isCurrentRequestActive() ||
      activeRequest.firstTokenAt !== undefined
    ) {
      return;
    }

    activeRequest.firstTokenAt = Date.now();
    renderRunningStatus(ctx);
  });

  pi.on("message_end", async (event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    if (getSubagentMetrics(event.message)?.throughput) {
      renderIdleStatus(ctx);
    }

    if (event.message.role !== "assistant" || isSubagentMessage(event.message) || !isCurrentRequestActive()) {
      return;
    }

    const originalMessage = event.message as AssistantMessage;
    const message = withEstimatedInputUsage(originalMessage, activeRequest?.estimatedInputTokens);
    finishRequest(ctx, message);

    if (message !== originalMessage) {
      return { message };
    }
  });

  pi.on("turn_end", async (event) => {
    if (currentTurnIndex === event.turnIndex) {
      currentTurnIndex = undefined;
    }
  });

  pi.on("agent_end", async (_event, ctx) => {
    currentCtx = ctx;
    currentSessionKey = getStatuslineSessionKey(ctx);
    if (!activeRequest) {
      renderIdleStatus(ctx);
      return;
    }

    if (activeRequest.failureStatusCode !== undefined) {
      lastFailure = {
        durationMs: Math.max(0, Date.now() - activeRequest.startedAt),
        statusCode: activeRequest.failureStatusCode,
      };
    }

    activeRequest = undefined;
    clearLiveStatus();
    renderIdleStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    currentCtx = undefined;
    pendingReviewerMetrics = undefined;
    clearLiveStatus();
    activeRequest = undefined;
    lastCompleted = undefined;
    lastFailure = undefined;
    resetUsageSamples();
    statuslineItem.clear(getStatuslineSessionKey(ctx));
  });
}
