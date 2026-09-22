import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import {
  buildSubagentMetrics,
  extractFinalAssistantText,
  runSubagentProcess,
} from "./lib/subagent-runtime.ts";
import { getScopedThinkingLevel, getSelectableModels } from "./lib/model-ref.ts";

const ADVISOR_MESSAGE_TYPE = "advisor-task-packet";
const ASTRA_PROVIDER = "github-copilot";
const ASTRA_MODEL = "gpt-6-astra";
const PACKET_MARKER = "<!-- pi-advisor-task-packet -->";
const ADVISOR_CHILD_MARKER = "PI_THREE_TIER_ADVISOR_CHILD";
const ADVISOR_PROGRESS_WIDGET = "three-tier-advisor-progress";
const advisedPrompts = new Set<string>();

declare global {
  // Reloaded extensions share a process, while their UI widget IDs do not.
  // Track ownership so an outgoing runtime cannot erase the new runtime's UI.
  // eslint-disable-next-line no-var
  var __PI_ADVISOR_PROGRESS_OWNER__: string | undefined;
}

type AdvisorActivityEvent = {
  id: string;
  sessionKey: string;
  phase: "start" | "update" | "end";
  model: string;
  message?: unknown;
  turn?: number;
  error?: string;
};

const ADVISOR_SYSTEM_PROMPT = `You are Astra, a high-risk implementation advisor inside Pi.
Return only a concise structured task packet in Markdown with exactly these sections:
## Objective
## Invariants / Risks
## Scope / Non-goals
## Recommended Delegation Slices
## Validation
## Escalation / Review Triggers

You may use relevant Pi tools and inspect repository evidence to ground your advice. Do not edit files, delegate to other agents, read dotenv or other secret files, or cause external side effects. Never expose credentials. Preserve uncertainty as an escalation trigger.`;

function redactCredentials(prompt: string): string {
  return prompt
    .replace(/(bearer\s+)[^\s,;]+/gi, "$1[REDACTED]")
    .replace(/((?:api[_-]?key|token|secret|password|credential)\s*[:=]\s*)[^\s,;]+/gi, "$1[REDACTED]");
}

function isHighRiskMutation(prompt: string): boolean {
  const text = prompt.toLowerCase();
  const risk = /\b(execut(?:e|ion|ing)|broker(?:age)?|persist(?:ence|ent)|database|\bdb\b|migration|migrat(?:e|ing)|security|secure|auth(?:entication|orization)?|concurren(?:cy|t)|parallel|cross[- ]cutting|refactor(?:ing)?|architecture|global|system[- ]wide)\b/;
  const mutation = /\b(implement|build|create|add|change|modify|update|edit|write|remove|delete|migrat(?:e|ion)|refactor|replace|fix|patch|introduce|enable|disable|configure|wire|integrate)\b/;
  return risk.test(text) && mutation.test(text);
}

function isAdvisorPacket(prompt: string): boolean {
  return prompt.includes(PACKET_MARKER) || /^\s*(?:advisor task packet|## objective)\b/i.test(prompt);
}

function modelArg(model: { provider: string; id: string }, thinkingLevel = "high"): string {
  return thinkingLevel === "off"
    ? `${model.provider}/${model.id}`
    : `${model.provider}/${model.id}:${thinkingLevel}`;
}

async function runAdvisor(
  ctx: ExtensionContext,
  task: string,
  signal?: AbortSignal,
  activitySessionKey?: string,
  onActivity?: (event: AdvisorActivityEvent) => void,
): Promise<{ packet: string; model: string; metrics?: ReturnType<typeof buildSubagentMetrics> }> {
  const selectableModels = getSelectableModels(ctx);
  const active = ctx.model && selectableModels.find(
    (model) => model.provider === ctx.model!.provider && model.id === ctx.model!.id,
  );
  const astra = selectableModels.find(
    (model) => model.provider === ASTRA_PROVIDER && model.id === ASTRA_MODEL,
  );
  const candidates = [astra, active].filter(
    (model, index, all): model is NonNullable<typeof model> => Boolean(model) && all.indexOf(model) === index,
  );
  let advisor: NonNullable<typeof active> | undefined;
  let auth: { apiKey?: string; headers?: Record<string, string> } = {};
  let authError = "No Astra or active model is available for advisor_design.";
  for (const candidate of candidates) {
    const resolvedAuth = await ctx.modelRegistry.getApiKeyAndHeaders(candidate);
    if (!resolvedAuth.ok) {
      authError = `Unable to resolve advisor auth: ${resolvedAuth.error}`;
      continue;
    }
    advisor = candidate;
    // OAuth providers must resolve credentials in the child Pi process; never pass a derived token.
    auth = ctx.modelRegistry.isUsingOAuth(candidate)
      ? {}
      : { apiKey: resolvedAuth.apiKey, headers: resolvedAuth.headers };
    break;
  }
  if (!advisor) throw new Error(authError);

  const model = `${advisor.provider}/${advisor.id}`;
  const activity = {
    id: `advisor-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`,
    sessionKey: activitySessionKey ?? "ephemeral",
    model,
  };
  onActivity?.({ ...activity, phase: "start" });

  try {
    const run = await runSubagentProcess({
    cwd: ctx.cwd,
    prompt: `Prepare the task packet for this request:\n\n${task.trim()}`,
    modelArg: modelArg(advisor, getScopedThinkingLevel(ctx, advisor) ?? "high"),
    providerName: advisor.provider,
    apiKey: auth.apiKey,
    authHeaders: auth.headers,
    systemPrompt: `${ADVISOR_SYSTEM_PROMPT}\n\nParent system prompt (reference context only; credentials redacted):\n${redactCredentials(ctx.getSystemPrompt())}`,
    env: { [ADVISOR_CHILD_MARKER]: "1" },
    signal,
    onEvent: (() => {
      let assistantTurn = 0;
      return (event: unknown) => {
      if (!event || typeof event !== "object") return;
      const record = event as {
        type?: unknown;
        turnIndex?: unknown;
        message?: unknown;
        assistantMessageEvent?: { partial?: unknown };
      };
      if (record.type === "turn_start") {
        assistantTurn = typeof record.turnIndex === "number" ? record.turnIndex + 1 : assistantTurn + 1;
        return;
      }
      const message = record.type === "message_update"
        ? record.assistantMessageEvent?.partial
        : record.type === "message_end"
          ? record.message
          : undefined;
      if (message && typeof message === "object" && (message as { role?: unknown }).role === "assistant") {
        // A child turn has one assistant response; subsequent stream snapshots replace it.
        if (assistantTurn === 0) assistantTurn = 1;
        onActivity?.({ ...activity, phase: "update", message, turn: assistantTurn });
      }
    };
    })(),
  });
  const final = extractFinalAssistantText(
    [
      ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
      ...run.messages,
      ...(run.turnEndMessage ? [run.turnEndMessage] : []),
      ...(run.agentEndMessage ? [run.agentEndMessage] : []),
    ],
    run.streamedText,
  );
    if (!final.text) {
      throw new Error(`Advisor returned no task packet (exitCode: ${run.exitCode}; ${run.stderr.trim() || "no error details"}).`);
    }
    onActivity?.({ ...activity, phase: "end" });
    return { packet: final.text.trim(), model, metrics: buildSubagentMetrics(run) };
  } catch (error) {
    onActivity?.({
      ...activity,
      phase: "end",
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

function packetContent(packet: string): string {
  return `${PACKET_MARKER}\n\n## Astra advisor task packet\n\n${packet}`;
}

function setAdvisorProgress(
  ctx: ExtensionContext,
  message: string | undefined,
  owner: string,
): void {
  if (globalThis.__PI_ADVISOR_PROGRESS_OWNER__ !== owner || !ctx.hasUI) return;
  ctx.ui.setWidget(
    ADVISOR_PROGRESS_WIDGET,
    message ? [ctx.ui.theme.fg("accent", `● ${message}`)] : undefined,
    { placement: "aboveEditor" },
  );
}

function packetDetails(result: Awaited<ReturnType<typeof runAdvisor>>, source: "tool" | "command" | "auto") {
  return {
    source,
    advisor: result.model,
    generatedAt: Date.now(),
    subagentMetrics: result.metrics,
  };
}

function emitAdvisorMetrics(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  details: ReturnType<typeof packetDetails>,
): void {
  pi.events.emit("subagent:metrics", {
    generatedAt: details.generatedAt,
    sessionKey: ctx.sessionManager.getSessionFile() ?? "ephemeral",
    subagentMetrics: details.subagentMetrics,
  });
}

export default function threeTierRouting(pi: ExtensionAPI) {
  const progressOwner = `advisor-progress-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  globalThis.__PI_ADVISOR_PROGRESS_OWNER__ = progressOwner;
  let sessionGeneration = 0;
  let activeSessionGeneration: number | undefined;
  let activeSessionKey: string | undefined;

  pi.on("session_start", async (_event, ctx) => {
    activeSessionGeneration = ++sessionGeneration;
    activeSessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
    advisedPrompts.clear();
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    activeSessionGeneration = undefined;
    activeSessionKey = undefined;
    setAdvisorProgress(ctx, undefined, progressOwner);
  });

  const runAdvisorWithActivity = (
    ctx: ExtensionContext,
    task: string,
    signal?: AbortSignal,
  ) => {
    const generation = activeSessionGeneration;
    const sessionKey = activeSessionKey;
    return runAdvisor(ctx, task, signal, sessionKey, (activity) => {
      // A child may finish after its parent session is replaced. Do not let its
      // late events appear in the new session's activity panel.
      if (
        generation !== undefined &&
        generation === activeSessionGeneration &&
        sessionKey === activeSessionKey
      ) {
        pi.events.emit("subagent:activity", activity);
      }
    });
  };

  pi.registerTool({
    name: "advisor_design",
    label: "Astra advisor design",
    description: "Generate a concise, structured Astra task packet for a risky implementation request.",
    parameters: Type.Object({
      task: Type.String({ description: "The implementation request to analyze." }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const result = await runAdvisorWithActivity(ctx, params.task, signal);
      const details = packetDetails(result, "tool");
      emitAdvisorMetrics(pi, ctx, details);
      return {
        content: [{ type: "text", text: packetContent(result.packet) }],
        details,
      };
    },
  });

  pi.registerCommand("advisor", {
    description: "Run Astra advisor and inject a task packet. Usage: /advisor [task]",
    handler: async (args, ctx) => {
      const task = args.trim();
      if (!task) {
        ctx.ui.notify("Usage: /advisor [task]", "error");
        return;
      }
      try {
        const result = await runAdvisorWithActivity(ctx, task, ctx.signal);
        const details = packetDetails(result, "command");
        emitAdvisorMetrics(pi, ctx, details);
        pi.sendMessage({
          customType: ADVISOR_MESSAGE_TYPE,
          content: packetContent(result.packet),
          display: true,
          details,
        });
      } catch (error) {
        ctx.ui.notify(`Astra advisor failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
    },
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (process.env[ADVISOR_CHILD_MARKER] === "1") return;
    const normalized = event.prompt.trim().replace(/\s+/g, " ");
    if (!normalized || isAdvisorPacket(event.prompt) || !isHighRiskMutation(event.prompt) || advisedPrompts.has(normalized)) {
      return;
    }
    advisedPrompts.add(normalized);
    const generation = activeSessionGeneration;
    const sessionKey = activeSessionKey;
    // before_agent_start is awaited before Pi starts the main model stream. Make
    // that otherwise silent wait visible immediately, especially for large
    // prompts whose advisor preflight can take a while.
    setAdvisorProgress(ctx, "Astra advisor is preparing a task packet…", progressOwner);
    try {
      const result = await runAdvisorWithActivity(ctx, event.prompt, ctx.signal);
      const details = packetDetails(result, "auto");
      emitAdvisorMetrics(pi, ctx, details);
      return {
        message: {
          customType: ADVISOR_MESSAGE_TYPE,
          content: packetContent(result.packet),
          display: true,
          details,
        },
      };
    } catch {
      // Advisory failure must never prevent the conversational model from running.
      return undefined;
    } finally {
      // A late advisor completion belongs to the old extension context after a
      // session replacement; it must not clear the new session's progress UI.
      if (
        generation === activeSessionGeneration &&
        sessionKey === activeSessionKey
      ) {
        setAdvisorProgress(ctx, undefined, progressOwner);
      }
    }
  });
}
