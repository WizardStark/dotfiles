import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  estimateUsageCost,
  formatUsd,
  normalizeModelId,
} from "./lib/model-cost";
import { createStatuslineItem, getStatuslineSessionKey } from "./statusline/registry";

import {
  getSubagentDetails,
  getSubagentMetrics,
  type SubagentMetrics,
  type SubagentMetricsEvent,
} from "./lib/subagent-metrics.ts";

type CostSummary = {
  mainTotal: number;
  subTotal: number;
  hasUnknownSubCost: boolean;
  sawSubagentMessage: boolean;
  unknownModels: Set<string>;
};

const STATUS_KEY = "copilot-cost";

const statuslineItem = createStatuslineItem({
  id: STATUS_KEY,
  side: "left",
  order: 30,
  importance: 40,
  background: "userMessageBg",
});


function buildCostSummary(ctx: ExtensionContext, pendingEvent?: SubagentMetricsEvent): CostSummary {
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
  let pendingReviewerMetrics: SubagentMetricsEvent | undefined;

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

  pi.events.on("subagent:metrics", (data) => {
    const event = (data ?? {}) as SubagentMetricsEvent;
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
