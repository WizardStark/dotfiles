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
const advisedPrompts = new Set<string>();

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
  return { packet: final.text.trim(), model: `${advisor.provider}/${advisor.id}`, metrics: buildSubagentMetrics(run) };
}

function packetContent(packet: string): string {
  return `${PACKET_MARKER}\n\n## Astra advisor task packet\n\n${packet}`;
}

function packetDetails(result: Awaited<ReturnType<typeof runAdvisor>>, source: "tool" | "command" | "auto") {
  return {
    source,
    advisor: result.model,
    generatedAt: Date.now(),
    subagentMetrics: result.metrics,
  };
}

export default function threeTierRouting(pi: ExtensionAPI) {
  pi.registerTool({
    name: "advisor_design",
    label: "Astra advisor design",
    description: "Generate a concise, structured Astra task packet for a risky implementation request.",
    parameters: Type.Object({
      task: Type.String({ description: "The implementation request to analyze." }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const result = await runAdvisor(ctx, params.task, signal);
      return {
        content: [{ type: "text", text: packetContent(result.packet) }],
        details: packetDetails(result, "tool"),
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
        const result = await runAdvisor(ctx, task, ctx.signal);
        pi.sendMessage({
          customType: ADVISOR_MESSAGE_TYPE,
          content: packetContent(result.packet),
          display: true,
          details: packetDetails(result, "command"),
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
    try {
      const result = await runAdvisor(ctx, event.prompt, ctx.signal);
      return {
        message: {
          customType: ADVISOR_MESSAGE_TYPE,
          content: packetContent(result.packet),
          display: true,
          details: packetDetails(result, "auto"),
        },
      };
    } catch {
      // Advisory failure must never prevent the conversational model from running.
      return undefined;
    }
  });
}
