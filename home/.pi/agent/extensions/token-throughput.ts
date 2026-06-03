import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "token-throughput";
const STATUS_INTERVAL_MS = 100;

type ActiveRequest = {
  turnIndex?: number;
  startedAt: number;
  firstTokenAt?: number;
  failureStatusCode?: number;
};

type CompletedSnapshot = {
  ttftMs?: number;
  generationDurationMs?: number;
  outputTokens: number;
  generationTokensPerSecond?: number;
};

type FailedSnapshot = {
  durationMs: number;
  statusCode?: number;
};

type SubagentMetrics = {
  throughput?: {
    ttftMs?: number;
    generationDurationMs?: number;
    outputTokens?: number;
    generationTokensPerSecond?: number;
  };
};

type ReviewerMetricsEvent = {
  generatedAt?: number;
  subagentMetrics?: SubagentMetrics;
};

function formatDuration(durationMs: number): string {
  if (durationMs < 1_000) return `${durationMs}ms`;
  if (durationMs < 10_000) return `${(durationMs / 1_000).toFixed(1)}s`;
  if (durationMs < 60_000) return `${Math.round(durationMs / 1_000)}s`;

  const totalSeconds = Math.round(durationMs / 1_000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return seconds === 0 ? `${minutes}m` : `${minutes}m ${seconds}s`;
}

function formatTokensPerSecond(tokensPerSecond: number | undefined): string {
  if (!tokensPerSecond || !Number.isFinite(tokensPerSecond) || tokensPerSecond <= 0) {
    return "—";
  }

  if (tokensPerSecond >= 100) return `${Math.round(tokensPerSecond)} tok/s`;
  if (tokensPerSecond >= 10) return `${tokensPerSecond.toFixed(1)} tok/s`;
  return `${tokensPerSecond.toFixed(2)} tok/s`;
}

function setStatus(ctx: ExtensionContext, content: string | undefined) {
  if (!ctx.hasUI) {
    return;
  }

  ctx.ui.setStatus(STATUS_KEY, content);
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

function buildSubagentSummary(ctx: ExtensionContext, pendingEvent?: ReviewerMetricsEvent): string {
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
  let pendingReviewerMetrics: ReviewerMetricsEvent | undefined;
  let activeRequest: ActiveRequest | undefined;
  let currentTurnIndex: number | undefined;
  let lastCompleted: CompletedSnapshot | undefined;
  let lastFailure: FailedSnapshot | undefined;
  let statusTimer: ReturnType<typeof setInterval> | undefined;

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

  function renderIdleStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) {
      return;
    }

    const subagentSummary = buildSubagentSummary(ctx, pendingReviewerMetrics);

    if (lastFailure) {
      const code = lastFailure.statusCode ? ` HTTP ${lastFailure.statusCode}` : "";
      setStatus(
        ctx,
        `${ctx.ui.theme.fg("warning", "⚠")}${ctx.ui.theme.fg("dim", ` Resp failed${code} after ${formatDuration(lastFailure.durationMs)} · ${subagentSummary}`)}`,
      );
      return;
    }

    if (!lastCompleted) {
      setStatus(ctx, ctx.ui.theme.fg("dim", `Resp — · ${subagentSummary}`));
      return;
    }

    const ttft =
      lastCompleted.ttftMs === undefined ? "TTFT —" : `TTFT ${formatDuration(lastCompleted.ttftMs)}`;
    setStatus(
      ctx,
      `${ctx.ui.theme.fg("accent", "⚡")}${ctx.ui.theme.fg("dim", ` Main ${ttft} · ${formatTokensPerSecond(lastCompleted.generationTokensPerSecond)} · ${subagentSummary}`)}`,
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
      setStatus(
        ctx,
        `${ctx.ui.theme.fg("warning", "…")}${ctx.ui.theme.fg("dim", ` Main waiting ${elapsed} · ${subagentSummary}`)}`,
      );
      return;
    }

    const ttft = Math.max(0, activeRequest.firstTokenAt - activeRequest.startedAt);
    const streamingFor = formatDuration(Math.max(0, Date.now() - activeRequest.firstTokenAt));
    setStatus(
      ctx,
      `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` Main TTFT ${formatDuration(ttft)} · streaming ${streamingFor} · ${subagentSummary}`)}`,
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
    const outputTokens = Math.max(0, message.usage?.output ?? 0);
    const generationTokensPerSecond =
      outputTokens > 0 && generationDurationMs !== undefined
        ? outputTokens / (generationDurationMs / 1_000)
        : undefined;

    lastCompleted = {
      ttftMs,
      generationDurationMs,
      outputTokens,
      generationTokensPerSecond,
    };
    lastFailure = undefined;
    activeRequest = undefined;

    clearLiveStatus();
    renderIdleStatus(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
    pendingReviewerMetrics = undefined;
    clearLiveStatus();
    activeRequest = undefined;
    currentTurnIndex = undefined;
    lastCompleted = undefined;
    lastFailure = undefined;
    renderIdleStatus(ctx);
  });

  pi.events.on("reviewer-subagent:metrics", (data) => {
    pendingReviewerMetrics = (data ?? {}) as ReviewerMetricsEvent;
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
    if (getSubagentMetrics(event.message)?.throughput) {
      renderIdleStatus(ctx);
    }

    if (event.message.role !== "assistant" || !isCurrentRequestActive()) {
      return;
    }

    const message = event.message as AssistantMessage;
    finishRequest(ctx, message);
  });

  pi.on("turn_end", async (event) => {
    if (currentTurnIndex === event.turnIndex) {
      currentTurnIndex = undefined;
    }
  });

  pi.on("agent_end", async (_event, ctx) => {
    currentCtx = ctx;
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
    setStatus(ctx, undefined);
  });
}
