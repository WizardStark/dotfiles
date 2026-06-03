import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "copilot-cost";
const TOKENS_PER_MILLION = 1_000_000;

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
  const withoutSuffix = raw.split("@")[0] || raw;
  const withoutSlashPrefix = withoutSuffix.split("/").pop() || withoutSuffix;
  const unscoped = withoutSlashPrefix.split(":").pop() || withoutSlashPrefix;
  return unscoped.replace(/[_\s]+/g, "-").replace(/-+/g, "-");
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

function buildStatus(ctx: ExtensionContext): string {
  let total = 0;
  let hasEstimate = false;
  const unknownModels = new Set<string>();

  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") {
      continue;
    }

    const message = entry.message as AssistantMessage;
    if (message.provider !== "github-copilot") {
      continue;
    }
    const { amount, estimated, knownRate } = estimateUsageCost(message);
    total += amount;
    hasEstimate ||= estimated;
    if (!knownRate) {
      unknownModels.add(normalizeModelId(message.model) || "unknown-model");
    }
  }

  const prefix = hasEstimate ? "Est " : "Cost ";
  const unknownSuffix = unknownModels.size > 0 ? ` +${unknownModels.size} unk` : "";
  return `${prefix}${formatUsd(total)}${unknownSuffix}`;
}

function renderStatus(ctx: ExtensionContext) {
  if (!ctx.hasUI) {
    return;
  }

  ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", buildStatus(ctx)));
}

export default function copilotCost(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    renderStatus(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    renderStatus(ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    renderStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }

    ctx.ui.setStatus(STATUS_KEY, undefined);
  });
}
