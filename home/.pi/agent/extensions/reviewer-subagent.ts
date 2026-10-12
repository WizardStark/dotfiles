import { domainRenderers } from "./lib/domain-tool-renderers.ts";
import { runReviewerRequest } from "./lib/reviewer-request.ts";
import type { AgentMessage, ThinkingLevel } from "@earendil-works/pi-agent-core";
import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { relative } from "node:path";
import {
  buildSubagentMetrics,
  extractFinalAssistantText,
  type SubagentMetrics,
  type SubagentRunState,
} from "./lib/subagent-runtime.ts";

const REVIEW_REPORT_TYPE = "reviewer-report";
const MAX_CONTEXT_CHARS = 12_000;
const MAX_DIFF_CHARS = 40_000;
const MAX_UNTRACKED_FILES = 3;
const MAX_UNTRACKED_FILE_CHARS = 4_000;
const MAX_MESSAGES = 12;

const REVIEW_SYSTEM_PROMPT = `You are a reviewer subagent for a coding session.

Your job:
- Review the CURRENT code changes against the stated intent.
- Look for correctness issues, regressions, missing edge cases, risky assumptions, maintainability problems, and style drift from nearby code.
- Prefer actionable findings over praise.
- Be concise but specific.
- Only call out style drift when it meaningfully diverges from surrounding code or project conventions visible in the diff/context.
- Avoid nitpicks unless they are likely to matter.
- If there are no material issues, say so plainly.

Output exactly this Markdown structure:

## Verdict
- [short overall verdict]

## Findings
- [severity] file/path[:line if clear] - issue, why it matters, concrete fix
- If no material findings: (none)

## Style Drift
- [file/path] - drift from surrounding code and how to align it
- If none: (none)

## Positives
- [brief note]
- If none: (none)`;

type ReviewResult = {
  report: string;
  repoRoot?: string;
  changedFiles: string[];
  reviewerModel: string;
  subagentMetrics?: SubagentMetrics;
  isError?: boolean;
};

type ReviewParams = {
  context?: string;
  focus?: string;
  stage?: "interim" | "final";
};

type ReviewRunState = SubagentRunState;

type ReviewProgress = {
  phase: string;
  turns?: number;
};

import { getScopedThinkingLevel, getSelectableModels } from "./lib/model-ref.ts";
import { textFromMessage, truncate } from "./lib/session-messages.ts";

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

function buildConversationContext(messages: AgentMessage[]): string {
  const visibleMessages = messages
    .filter((message) => {
      if (message.role === "system") return false;
      const text = textFromMessage(message);
      return text.length > 0;
    })
    .slice(-MAX_MESSAGES);

  if (visibleMessages.length === 0) return "(none)";

  const llmMessages = convertToLlm(visibleMessages);
  return truncate(serializeConversation(llmMessages), MAX_CONTEXT_CHARS);
}

function buildReviewSubagentMetrics(run: ReviewRunState): SubagentMetrics | undefined {
  return buildSubagentMetrics(run);
}

function buildReviewerProgressText(progress: ReviewProgress): string {
  return [
    progress.phase,
    progress.turns !== undefined && progress.turns > 0 ? `${progress.turns} turns` : "",
  ].filter(Boolean).join(" · ");
}

async function runGit(cwd: string, args: string[], signal?: AbortSignal, timeout = 15000): Promise<string> {
  return await new Promise<string>((resolve) => {
    const proc = spawn("git", args, {
      cwd,
      stdio: ["ignore", "pipe", "ignore"],
    });

    let stdout = "";
    let settled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let onAbort: (() => void) | undefined;

    const finish = (value: string) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      if (onAbort) signal?.removeEventListener("abort", onAbort);
      resolve(value);
    };

    if (timeout > 0) {
      timer = setTimeout(() => {
        proc.kill("SIGTERM");
        finish("");
      }, timeout);
    }

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    proc.on("close", (code) => {
      finish(code === 0 ? stdout.trim() : "");
    });
    proc.on("error", () => finish(""));

    if (signal) {
      onAbort = () => {
        proc.kill("SIGTERM");
        finish("");
      };
      if (signal.aborted) onAbort();
      else signal.addEventListener("abort", onAbort, { once: true });
    }
  });
}

async function maybeRunGit(cwd: string, args: string[], signal?: AbortSignal, timeout = 15000): Promise<string> {
  try {
    return await runGit(cwd, args, signal, timeout);
  } catch {
    return "";
  }
}

async function collectUntrackedSnippets(cwd: string, repoRoot: string, files: string[]): Promise<string> {
  if (files.length === 0) return "";

  // Extension-owned reads do not pass through tool_call secret guards.
  const safeFiles = files.filter((file) => {
    const name = file.split("/").at(-1) ?? "";
    return !/^\.env(?:\..+)?$/.test(name) || name === ".env.example";
  });
  const selected = safeFiles.slice(0, MAX_UNTRACKED_FILES);
  const parts: string[] = [];

  for (const file of selected) {
    try {
      const content = await readFile(`${repoRoot}/${file}`, "utf8");
      parts.push(`### ${file}\n\n\`\`\`\n${truncate(content, MAX_UNTRACKED_FILE_CHARS)}\n\`\`\``);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      parts.push(`### ${file}\n\n(unable to read file: ${message})`);
    }
  }

  if (files.length > selected.length) {
    parts.push(`...and ${files.length - selected.length} more untracked file(s) omitted.`);
  }

  return parts.join("\n\n");
}

async function collectGitContext(cwd: string, signal?: AbortSignal) {
  const repoRoot = await maybeRunGit(cwd, ["rev-parse", "--show-toplevel"], signal);
  if (!repoRoot) {
    return {
      ok: false as const,
      reason: `No git repository found for ${cwd}`,
      changedFiles: [] as string[],
      repoRoot: undefined,
      gitContext: "",
    };
  }

  const status = await maybeRunGit(cwd, ["status", "--short"], signal);
  const stagedFiles = (await maybeRunGit(cwd, ["diff", "--cached", "--name-only", "--diff-filter=ACMRD"], signal))
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  const unstagedFiles = (await maybeRunGit(cwd, ["diff", "--name-only", "--diff-filter=ACMRD"], signal))
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  const untrackedFiles = (await maybeRunGit(cwd, ["ls-files", "--others", "--exclude-standard"], signal))
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

  const changedFiles = unique([...stagedFiles, ...unstagedFiles, ...untrackedFiles]);
  if (changedFiles.length === 0) {
    return {
      ok: true as const,
      noChanges: true as const,
      changedFiles,
      repoRoot,
      gitContext: "",
    };
  }

  const stagedStat = await maybeRunGit(cwd, ["diff", "--cached", "--stat", "--summary", "--find-renames"], signal);
  const unstagedStat = await maybeRunGit(cwd, ["diff", "--stat", "--summary", "--find-renames"], signal);
  const stagedPatch = await maybeRunGit(cwd, ["diff", "--cached", "--minimal", "--find-renames", "--unified=12"], signal, 20000);
  const unstagedPatch = await maybeRunGit(cwd, ["diff", "--minimal", "--find-renames", "--unified=12"], signal, 20000);
  const untrackedSnippets = await collectUntrackedSnippets(cwd, repoRoot, untrackedFiles);

  const repoLabel = relative(repoRoot, cwd) || ".";
  const gitContext = truncate(
    [
      `Repository root: ${repoRoot}`,
      `Working directory: ${cwd} (${repoLabel})`,
      `Changed files (${changedFiles.length}): ${changedFiles.join(", ")}`,
      "",
      "## git status --short",
      status || "(none)",
      "",
      "## staged diff --stat --summary",
      stagedStat || "(none)",
      "",
      "## unstaged diff --stat --summary",
      unstagedStat || "(none)",
      "",
      "## staged patch",
      stagedPatch || "(none)",
      "",
      "## unstaged patch",
      unstagedPatch || "(none)",
      "",
      "## untracked file snippets",
      untrackedSnippets || "(none)",
    ].join("\n"),
    MAX_DIFF_CHARS,
  );

  return {
    ok: true as const,
    noChanges: false as const,
    changedFiles,
    repoRoot,
    gitContext,
  };
}

function buildReviewPrompt(input: {
  context?: string;
  focus?: string;
  conversationContext: string;
  gitContext: string;
}) {
  return [
    input.context?.trim() ? `## Stated change context\n${input.context.trim()}` : "## Stated change context\n(none provided)",
    input.focus?.trim() ? `## Review focus\n${input.focus.trim()}` : "## Review focus\nGeneral review for issues, improvements, and style drift.",
    `## Recent session context\n${input.conversationContext}`,
    `## Current code changes\n${input.gitContext}`,
  ].join("\n\n");
}

async function generateReview(
  ctx: ExtensionContext,
  defaultThinkingLevel: ThinkingLevel,
  input: ReviewParams,
  signal?: AbortSignal,
  onProgress?: (progress: ReviewProgress) => void,
): Promise<ReviewResult> {
  signal?.throwIfAborted();
  const git = await collectGitContext(ctx.cwd, signal);
  signal?.throwIfAborted();
  if (!git.ok) {
    throw new Error(git.reason);
  }
  if (git.noChanges) {
    return {
      report: "No uncommitted git changes found to review.",
      repoRoot: git.repoRoot,
      changedFiles: git.changedFiles,
      reviewerModel: "(not run; no changes)",
    };
  }

  const conversationContext = buildConversationContext(ctx.sessionManager.buildSessionProjection().messages);
  const prompt = buildReviewPrompt({
    context: input.context,
    focus: input.focus,
    conversationContext,
    gitContext: git.gitContext,
  });

  const stage = input.stage ?? "interim";
  const selectableModels = getSelectableModels(ctx);
  const activeModel = ctx.model && selectableModels.find(
    (model) => model.provider === ctx.model!.provider && model.id === ctx.model!.id,
  );
  let modelToUse = undefined as typeof ctx.model | undefined;
  let thinkingLevelToUse = defaultThinkingLevel;

  if (stage === "interim") {
    thinkingLevelToUse = "minimal";
    modelToUse = getSelectableModels(ctx).find(
      (model) => model.provider === "github-copilot" && model.id === "gpt-6-luna",
    ) ?? activeModel;
  } else {
    if (!ctx.model) {
      throw new Error("No active model selected for final reviewer subagent.");
    }
    modelToUse = activeModel;
  }

  if (!modelToUse) {
    throw new Error("No reviewer model could be resolved.");
  }

  thinkingLevelToUse = getScopedThinkingLevel(ctx, modelToUse) ?? thinkingLevelToUse;
  const modelArg =
    thinkingLevelToUse === "off" ? `${modelToUse.provider}/${modelToUse.id}` : `${modelToUse.provider}/${modelToUse.id}:${thinkingLevelToUse}`;
  onProgress?.({ phase: "starting" });
  const run = await runReviewerRequest(
    ctx.modelRegistry, modelToUse, thinkingLevelToUse, REVIEW_SYSTEM_PROMPT, prompt, signal,
    (phase) => onProgress?.({ phase }),
  );
  const final = extractFinalAssistantText(
    [
      ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
      ...run.messages,
      ...(run.turnEndMessage ? [run.turnEndMessage] : []),
      ...(run.agentEndMessage ? [run.agentEndMessage] : []),
    ],
    run.streamedText,
  );
  const failed = run.stopReason === "error" || run.stopReason === "aborted" || !final.text;
  const report = failed
    ? run.stopReason === "aborted" ? "Reviewer cancelled."
      : `Reviewer failed: ${run.errorMessage ?? "The model returned no text."}`
    : final.text;
  return {
    report, isError: failed, repoRoot: git.repoRoot, changedFiles: git.changedFiles,
    reviewerModel: modelArg, subagentMetrics: buildReviewSubagentMetrics(run),
  };
}

export default function (pi: ExtensionAPI) {
  const controllers = new Set<AbortController>();
  let generation = 0;
  pi.on("session_shutdown", () => {
    generation += 1;
    for (const controller of controllers) controller.abort();
    controllers.clear();
  });
  async function runReview(ctx: ExtensionContext, input: ReviewParams, signal?: AbortSignal, progress?: (value: ReviewProgress) => void) {
    const owner = generation;
    const controller = new AbortController();
    const abort = () => controller.abort();
    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });
    controllers.add(controller);
    try {
      const result = await generateReview(ctx, pi.getThinkingLevel(), input, controller.signal,
        (value) => { if (owner === generation) progress?.(value); });
      if (owner !== generation) throw new Error("Reviewer session was replaced.");
      return result;
    } finally {
      signal?.removeEventListener("abort", abort);
      controllers.delete(controller);
    }
  }
  pi.registerMessageRenderer(REVIEW_REPORT_TYPE, (message, { expanded }, theme) => {
    const details = (message.details ?? {}) as { changedFiles?: string[]; reviewer?: string };
    const body = typeof message.content === "string" ? message.content : JSON.stringify(message.content);
    const lines = [body];

    if (expanded) {
      if (Array.isArray(details.changedFiles) && details.changedFiles.length > 0) {
        lines.push("", theme.fg("dim", `Changed files: ${details.changedFiles.join(", ")}`));
      }
      if (typeof details.reviewer === "string") {
        lines.push(theme.fg("dim", `Reviewer model: ${details.reviewer}`));
      }
    }

    const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
    box.addChild(new Text(lines.join("\n"), 0, 0));
    return box;
  });

  pi.registerTool({
    name: "review_changes",
    exposure: "model-only",
    label: "Review changes",
    ...domainRenderers("review", "Review"),
    description:
      "Inspect current git changes in a fresh reviewer subagent; interim uses a cheaper model and final uses the active model.",
    parameters: Type.Object({
      context: Type.Optional(
        Type.String({
          description: "Brief summary of what changed and why. Include user intent, invariants, or areas that deserve scrutiny.",
        }),
      ),
      focus: Type.Optional(
        Type.String({
          description: "Optional review focus, such as edge cases, correctness, API compatibility, or style drift.",
        }),
      ),
      stage: Type.Optional(
        StringEnum(["interim", "final"] as const, {
          description: "Review stage. interim uses a cheaper model for early checks. final uses the current active model. Defaults to interim.",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      onUpdate?.({ content: [{ type: "text", text: "Collecting changed files and recent context..." }], details: { phase: "collecting context" } });
      const result = await runReview(ctx, params, signal, (progress) => {
        onUpdate?.({
          content: [{ type: "text", text: buildReviewerProgressText(progress) }],
          details: progress,
        });
      });
      const generatedAt = Date.now();
      const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
      pi.events.emit("subagent:metrics", {
        generatedAt,
        sessionKey,
        subagentMetrics: result.subagentMetrics,
        source: "tool",
      });
      onUpdate?.({ content: [{ type: "text", text: "Reviewer finished." }], details: { phase: "finished" } });
      return {
        usage: result.subagentMetrics?.usage,
        isError: result.isError,
        content: [{ type: "text", text: result.report }],
        details: {
          generatedAt,
          sessionKey,
          repoRoot: result.repoRoot,
          changedFiles: result.changedFiles,
          reviewer: result.reviewerModel,
          stage: params.stage ?? "interim",
          subagentMetrics: result.subagentMetrics,
        },
      };
    },
  });

  pi.registerCommand("review", {
    description: "Run a reviewer subagent on current git changes. Usage: /review [interim|final] [focus or context]",
    handler: async (args, ctx) => {
      try {
        const trimmed = args.trim();
        const stageMatch = trimmed.match(/^(interim|final)\b/i);
        const stage = stageMatch?.[1]?.toLowerCase() as "interim" | "final" | undefined;
        const rest = stage ? trimmed.slice(stageMatch?.[0].length ?? 0).trim() : trimmed;
        ctx.ui.notify("Reviewer subagent: collecting context and reviewing changes...", "info");
        const result = await runReview(ctx, { stage, context: rest || undefined }, ctx.signal);
        const generatedAt = Date.now();
        const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
        pi.sendMessage({
          customType: REVIEW_REPORT_TYPE,
          content: `## Reviewer report\n\n${result.report}`,
          display: true,
          details: {
            generatedAt,
            sessionKey,
            repoRoot: result.repoRoot,
            changedFiles: result.changedFiles,
            reviewer: result.reviewerModel,
            subagentMetrics: result.subagentMetrics,
          },
        });
        pi.events.emit("subagent:metrics", {
          generatedAt,
          sessionKey,
          subagentMetrics: result.subagentMetrics,
          source: "command",
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Reviewer subagent failed: ${message}`, "error");
      }
    },
  });
}
