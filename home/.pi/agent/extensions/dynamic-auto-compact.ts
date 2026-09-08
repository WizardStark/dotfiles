import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type MutableModel = {
  id: string;
  contextWindow?: number;
};

const GPT_SHORT_CONTEXT_WINDOW = 272_000;
const AUTO_COMPACT_RESERVE = 27_200;
const MODEL_CONTEXT_WINDOWS = new WeakMap<MutableModel, number>();

function isGptModel(id: string): boolean {
  return /^gpt(?:[-_.]?\d|$)/i.test(id);
}

function originalContextWindow(model: MutableModel): number | undefined {
  const existing = MODEL_CONTEXT_WINDOWS.get(model);
  if (existing !== undefined) return existing;

  const contextWindow = model.contextWindow;
  if (!Number.isFinite(contextWindow) || contextWindow === undefined || contextWindow <= 0) {
    return undefined;
  }

  MODEL_CONTEXT_WINDOWS.set(model, contextWindow);
  return contextWindow;
}

function applyAutoCompactWindow(ctx: ExtensionContext): void {
  const model = ctx.model as MutableModel | undefined;
  if (!model) return;

  const contextWindow = originalContextWindow(model);
  if (contextWindow === undefined) return;

  // Pi's built-in trigger is `contextWindow - reserveTokens`. With the
  // configured 27,200-token reserve, this makes each model with at least a
  // 272k context window compact at 90% of its real window. GPT models use
  // Copilot's 272k short-context tier rather than their advertised 1.05M
  // maximum context.
  const effectiveWindow = isGptModel(model.id)
    ? Math.min(contextWindow, GPT_SHORT_CONTEXT_WINDOW)
    : Math.min(contextWindow, Math.floor(contextWindow * 0.9) + AUTO_COMPACT_RESERVE);

  model.contextWindow = effectiveWindow;
}

export default function dynamicAutoCompact(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    applyAutoCompactWindow(ctx);
  });

  pi.on("model_select", (_event, ctx) => {
    applyAutoCompactWindow(ctx);
  });
}
