import type { AssistantMessage } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { matchesKey, visibleWidth } from "@earendil-works/pi-tui";
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

const USAGE_EMPTY = "μ In/Out —";
let latestContextTokens: number | undefined;

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
  uncachedInputTokens?: number;
  cacheReadInputTokens?: number;
  cacheWriteInputTokens?: number;
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
  const inputStats = buildUsageStats(inputSamples);
  const outputStats = buildUsageStats(outputSamples);

  if (inputStats.count === 0 && outputStats.count === 0) {
    return theme.fg("dim", USAGE_EMPTY);
  }

  const input = inputStats.count > 0 ? formatTokenCount(inputStats.mean) : "—";
  const output = outputStats.count > 0 ? formatTokenCount(outputStats.mean) : "—";
  return theme.fg("dim", `μ In ${input} · Out ${output}`);
}

class MetricsOverlay {
  private readonly width: number;

  constructor(
    private readonly theme: Theme,
    private readonly lines: string[],
    private readonly done: () => void,
  ) {
    const contentWidth = Math.max(...lines.map((line) => visibleWidth(line)), 40);
    this.width = Math.min(110, Math.max(56, contentWidth + 4));
  }

  handleInput(data: string) {
    if (matchesKey(data, "escape") || matchesKey(data, "return") || matchesKey(data, "q")) {
      this.done();
    }
  }

  render(_width: number): string[] {
    const innerWidth = this.width - 2;
    const pad = (text = "") => text + " ".repeat(Math.max(0, innerWidth - visibleWidth(text)));
    const row = (content = "") =>
      this.theme.fg("border", "│") + pad(content) + this.theme.fg("border", "│");
    return [
      this.theme.fg("border", `╭${"─".repeat(innerWidth)}╮`),
      row(` ${this.theme.bold(this.theme.fg("accent", "Session metrics"))}`),
      row(),
      ...this.lines.map((line) => row(` ${line}`)),
      row(),
      row(` ${this.theme.fg("dim", "Enter / Esc / q to close")}`),
      this.theme.fg("border", `╰${"─".repeat(innerWidth)}╯`),
    ];
  }

  invalidate() {}
}

function buildContextSummary(ctx: ExtensionContext, retainedTokens?: number) {
  const contextUsage = ctx.getContextUsage();
  const usageTokens = contextUsage?.tokens;
  const hasNumericUsage = typeof usageTokens === "number" && Number.isFinite(usageTokens) && usageTokens >= 0;
  if (hasNumericUsage) latestContextTokens = usageTokens;
  const tokens = hasNumericUsage ? usageTokens : retainedTokens;
  const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow;
  if (!Number.isFinite(tokens) || tokens === undefined || tokens < 0) {
    return {
      full: ctx.ui.theme.fg("dim", "Ctx —"),
      compact: ctx.ui.theme.fg("dim", "Ctx —"),
    };
  }

  if (!Number.isFinite(contextWindow) || contextWindow === undefined || contextWindow <= 0) {
    return {
      full: ctx.ui.theme.fg("dim", `Ctx ${formatTokenCount(tokens)}`),
      compact: ctx.ui.theme.fg("dim", `Ctx ${formatTokenCount(tokens)}`),
    };
  }

  const percent = Math.round((tokens / contextWindow) * 100);
  return {
    full: ctx.ui.theme.fg(
      "dim",
      `Ctx ${formatTokenCount(tokens)}/${formatTokenCount(contextWindow)} (${percent}%)`,
    ),
    compact: ctx.ui.theme.fg("dim", `Ctx ${percent}%`),
  };
}

function setStatus(ctx: ExtensionContext, content: string | undefined, compactContent = content, retainedTokens = latestContextTokens) {
  if (!ctx.hasUI) {
    return;
  }

  if (!content) {
    statuslineItem.clear(getStatuslineSessionKey(ctx));
    return;
  }

  const context = buildContextSummary(ctx, retainedTokens);
  const separator = ctx.ui.theme.fg("dim", " · ");
  statuslineItem.set(
    {
      content: `${content}${separator}${context.full}`,
      compactContent: `${compactContent ?? content}${separator}${context.compact}`,
    },
    getStatuslineSessionKey(ctx),
  );
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

export function getCacheReadInputTokens(
  usage: AssistantMessage["usage"] | undefined,
): number | undefined {
  const tokens = usage?.cacheRead;
  return Number.isFinite(tokens) && tokens >= 0 ? tokens : undefined;
}

export function getCacheWriteInputTokens(
  usage: AssistantMessage["usage"] | undefined,
): number | undefined {
  const tokens = usage?.cacheWrite;
  return Number.isFinite(tokens) && tokens >= 0 ? tokens : undefined;
}

export function getUncachedInputTokens(
  usage: AssistantMessage["usage"] | undefined,
  fallback: number | undefined,
): number | undefined {
  const input = usage?.input;
  if (Number.isFinite(input) && input >= 0) return input;
  return Number.isFinite(fallback) && fallback >= 0 ? fallback : undefined;
}

export function getInputTokens(
  usage: AssistantMessage["usage"] | undefined,
  fallback: number | undefined,
): number | undefined {
  const uncached = getUncachedInputTokens(usage, fallback);
  const cacheRead = getCacheReadInputTokens(usage);
  const cacheWrite = getCacheWriteInputTokens(usage);
  if (uncached === undefined) {
    return cacheRead === undefined && cacheWrite === undefined
      ? undefined
      : (cacheRead ?? 0) + (cacheWrite ?? 0);
  }
  return uncached + (cacheRead ?? 0) + (cacheWrite ?? 0);
}

function withEstimatedInputUsage(
  message: AssistantMessage,
  estimatedInputTokens: number | undefined,
): AssistantMessage {
  const input = message.usage?.input;
  if (
    (Number.isFinite(input) && input >= 0) ||
    !Number.isFinite(estimatedInputTokens) ||
    estimatedInputTokens < 0
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
  let inputTokenSamples: number[] = [];
  let uncachedInputTokenSamples: number[] = [];
  let cacheReadInputTokenSamples: number[] = [];
  let cacheWriteInputTokenSamples: number[] = [];
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
      inputTokenSamples,
      outputTokenSamples,
    )}`;
  }

  function resetUsageSamples() {
    inputTokenSamples = [];
    uncachedInputTokenSamples = [];
    cacheReadInputTokenSamples = [];
    cacheWriteInputTokenSamples = [];
    outputTokenSamples = [];
  }

  function recordUsageSample(
    inputTokens: number | undefined,
    uncachedInputTokens: number | undefined,
    cacheReadInputTokens: number | undefined,
    cacheWriteInputTokens: number | undefined,
    outputTokens: number | undefined,
  ) {
    if (inputTokens !== undefined && Number.isFinite(inputTokens) && inputTokens >= 0) inputTokenSamples.push(inputTokens);
    if (uncachedInputTokens !== undefined && Number.isFinite(uncachedInputTokens) && uncachedInputTokens >= 0) uncachedInputTokenSamples.push(uncachedInputTokens);
    if (cacheReadInputTokens !== undefined && Number.isFinite(cacheReadInputTokens) && cacheReadInputTokens >= 0) cacheReadInputTokenSamples.push(cacheReadInputTokens);
    if (cacheWriteInputTokens !== undefined && Number.isFinite(cacheWriteInputTokens) && cacheWriteInputTokens >= 0) cacheWriteInputTokenSamples.push(cacheWriteInputTokens);
    if (outputTokens !== undefined && Number.isFinite(outputTokens) && outputTokens >= 0) outputTokenSamples.push(outputTokens);
  }

  function rebuildUsageSamples(ctx: ExtensionContext) {
    resetUsageSamples();

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message" || entry.message.role !== "assistant" || isSubagentMessage(entry.message)) {
        continue;
      }

      const message = entry.message as AssistantMessage;
      recordUsageSample(
        getInputTokens(message.usage, undefined),
        getUncachedInputTokens(message.usage, undefined),
        getCacheReadInputTokens(message.usage),
        getCacheWriteInputTokens(message.usage),
        message.usage?.output,
      );
    }
  }

  function resetBranchScopedState(ctx: ExtensionContext) {
    clearLiveStatus();
    activeRequest = undefined;
    currentTurnIndex = undefined;
    lastCompleted = undefined;
    lastFailure = undefined;
    pendingReviewerMetrics = undefined;
    latestContextTokens = undefined;
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
    const rate = formatTokensPerSecond(lastCompleted.generationTokensPerSecond);
    setStatus(
      ctx,
      buildStatusWithUsage(
        ctx,
        `${ctx.ui.theme.fg("accent", "⚡")}${ctx.ui.theme.fg("dim", ` ${ttft} · ${rate} · ${subagentSummary}`)}`,
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
    // A completed response is meaningful even if no intermediate update was emitted.
    const firstTokenAt = activeRequest.firstTokenAt ?? finishedAt;
    const ttftMs = Math.max(0, firstTokenAt - activeRequest.startedAt);
    const generationDurationMs = Math.max(1, finishedAt - firstTokenAt);
    const uncachedInputTokens = getUncachedInputTokens(message.usage, activeRequest.estimatedInputTokens);
    const cacheReadInputTokens = getCacheReadInputTokens(message.usage);
    const cacheWriteInputTokens = getCacheWriteInputTokens(message.usage);
    const inputTokens = getInputTokens(message.usage, activeRequest.estimatedInputTokens);
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
      uncachedInputTokens,
      cacheReadInputTokens,
      cacheWriteInputTokens,
      outputTokens,
      generationTokensPerSecond,
    };
    recordUsageSample(
      inputTokens,
      uncachedInputTokens,
      cacheReadInputTokens,
      cacheWriteInputTokens,
      outputTokens,
    );
    lastFailure = undefined;
    activeRequest = undefined;

    clearLiveStatus();
    renderIdleStatus(ctx);
  }

  function formatStats(label: string, samples: number[]) {
    const stats = buildUsageStats(samples);
    return `${label}: μ ${formatTokenCount(stats.mean)} · M ${formatTokenCount(stats.median)} (${stats.count})`;
  }

  function buildMetricsLines(ctx: ExtensionContext) {
    const usage = ctx.getContextUsage();
    const tokens = typeof usage?.tokens === "number" ? usage.tokens : latestContextTokens;
    const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow;
    const context =
      Number.isFinite(tokens) && tokens !== undefined && tokens >= 0
        ? Number.isFinite(contextWindow) && contextWindow !== undefined && contextWindow > 0
          ? `${formatTokenCount(tokens)}/${formatTokenCount(contextWindow)} (${Math.round((tokens / contextWindow) * 100)}%)`
          : formatTokenCount(tokens)
        : "—";
    const last = lastCompleted;
    return [
      "Last response",
      `  TTFT: ${last?.ttftMs === undefined ? "—" : formatDuration(last.ttftMs)}`,
      `  Generation: ${last?.generationDurationMs === undefined ? "—" : formatDuration(last.generationDurationMs)} · ${formatTokensPerSecond(last?.generationTokensPerSecond)}`,
      `  Input: ${formatTokenCount(last?.inputTokens)} (uncached ${formatTokenCount(last?.uncachedInputTokens)}, read ${formatTokenCount(last?.cacheReadInputTokens)}, write ${formatTokenCount(last?.cacheWriteInputTokens)})`,
      `  Output: ${formatTokenCount(last?.outputTokens)}`,
      "",
      "Session token samples (mean · median · count)",
      `  ${formatStats("Input", inputTokenSamples)}`,
      `  ${formatStats("Uncached", uncachedInputTokenSamples)}`,
      `  ${formatStats("Cache read", cacheReadInputTokenSamples)}`,
      `  ${formatStats("Cache write", cacheWriteInputTokenSamples)}`,
      `  ${formatStats("Output", outputTokenSamples)}`,
      "",
      `Context: ${context}`,
    ];
  }

  pi.registerCommand("metrics", {
    description: "Show detailed response, token, cache, and context metrics for this session",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;
      const lines = buildMetricsLines(ctx);
      if (ctx.mode !== "tui") {
        ctx.ui.notify(lines.filter(Boolean).join(" · "), "info");
        return;
      }
      const width = Math.min(110, Math.max(56, Math.max(...lines.map((line) => visibleWidth(line)), 40) + 4));
      await ctx.ui.custom<void>(
        (_tui, theme, _keybindings, done) => new MetricsOverlay(theme, lines, () => done()),
        {
          overlay: true,
          overlayOptions: {
            anchor: "center",
            width,
            margin: 1,
          },
        },
      );
    },
  });

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
    const contextTokens = ctx.getContextUsage()?.tokens;
    if (Number.isFinite(contextTokens) && contextTokens !== undefined && contextTokens >= 0) {
      latestContextTokens = contextTokens;
    }
    activeRequest = {
      turnIndex: currentTurnIndex,
      startedAt: Date.now(),
      estimatedInputTokens: contextTokens ?? latestContextTokens,
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

    const content = (event.message as AssistantMessage).content;
    const meaningful = Array.isArray(content) && content.some((block) => {
      if (!block || typeof block !== "object") return false;
      const value = block as { type?: string; text?: string; thinking?: string; name?: string };
      return (typeof value.text === "string" && value.text.length > 0) ||
        (typeof value.thinking === "string" && value.thinking.length > 0) ||
        value.type === "toolCall" || typeof value.name === "string";
    });
    if (!meaningful) return;

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
