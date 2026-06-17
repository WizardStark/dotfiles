import type { AgentMessage, ThinkingLevel } from "@earendil-works/pi-agent-core";
import { StringEnum, type Message } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { relative } from "node:path";
import {
  buildSubagentMetrics,
  extractFinalAssistantText,
  runSubagentProcess,
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

import {
  entryToMessage,
  getSessionMessages,
  textFromMessage,
  truncate,
} from "./lib/session-messages.ts";

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

function buildConversationContext(branch: SessionEntry[]): string {
  const messages = getSessionMessages(branch)
    .filter((message) => {
      if (message.role === "system") return false;
      const text = textFromMessage(message);
      return text.length > 0;
    })
    .slice(-MAX_MESSAGES);

  if (messages.length === 0) return "(none)";

  const llmMessages = convertToLlm(messages);
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

    const finish = (value: string) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
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
      const onAbort = () => {
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

  const selected = files.slice(0, MAX_UNTRACKED_FILES);
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
  const stagedFiles = (await maybeRunGit(cwd, ["diff", "--cached", "--name-only", "--diff-filter=ACMR"], signal))
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  const unstagedFiles = (await maybeRunGit(cwd, ["diff", "--name-only", "--diff-filter=ACMR"], signal))
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
      ok: false as const,
      reason: "No uncommitted git changes found to review.",
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

async function runReviewerSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  auth: { apiKey?: string; headers?: Record<string, string> },
  signal?: AbortSignal,
  onProgress?: (progress: ReviewProgress) => void,
): Promise<ReviewRunState> {
  let completedTurns = 0;
  return await runSubagentProcess({
    cwd,
    prompt,
    modelArg,
    apiKey: auth.apiKey,
    providerName: modelArg.split("/", 1)[0],
    authHeaders: auth.headers,
    systemPrompt: REVIEW_SYSTEM_PROMPT,
    extraArgs: [
      "--no-tools",
      "--no-extensions",
      "-e",
      "@temp/timing-extension.ts",
      "--no-skills",
      "--no-prompt-templates",
      "--no-context-files",
    ],
    tempFiles: [
      {
        name: "timing-extension.ts",
        content: `export default function (pi) {
  const emit = (payload) => {
    process.stdout.write(JSON.stringify({ type: "reviewer_metric", ...payload }) + "\\n");
  };

  pi.on("before_provider_request", async () => {
    emit({ event: "before_provider_request", timestamp: Date.now() });
  });

  pi.on("after_provider_response", async (event) => {
    emit({ event: "after_provider_response", timestamp: Date.now(), status: event.status });
  });
}
`,
      },
    ],
    signal,
    onEvent: (event, state) => {
      if (event.type === "reviewer_metric" && event.event === "before_provider_request") {
        state.providerRequestStartedAt ??= typeof event.timestamp === "number" ? event.timestamp : Date.now();
        onProgress?.({ phase: "thinking", turns: completedTurns });
      }
      if (event.type === "message_update") {
        onProgress?.({ phase: "responding", turns: completedTurns });
      }
      if (event.type === "turn_end") {
        completedTurns += 1;
        onProgress?.({ phase: "responding", turns: completedTurns });
      }
    },
  });
}

async function generateReview(
  ctx: ExtensionContext,
  defaultThinkingLevel: ThinkingLevel,
  input: ReviewParams,
  signal?: AbortSignal,
  onProgress?: (progress: ReviewProgress) => void,
): Promise<ReviewResult> {
  const git = await collectGitContext(ctx.cwd, signal);
  if (!git.ok) {
    throw new Error(git.reason);
  }

  const conversationContext = buildConversationContext(ctx.sessionManager.getBranch());
  const prompt = buildReviewPrompt({
    context: input.context,
    focus: input.focus,
    conversationContext,
    gitContext: git.gitContext,
  });

  const stage = input.stage ?? "interim";
  let modelToUse = undefined as typeof ctx.model | undefined;
  let thinkingLevelToUse = defaultThinkingLevel;

  if (stage === "interim") {
    // Attempt to load supervisor-worker state to find the cheap reviewer model
    const stateEntry = [...ctx.sessionManager.getEntries()]
      .reverse()
      .find((e) => e.type === "custom" && e.customType === "supervisor-worker-state") as { data?: any } | undefined;

    thinkingLevelToUse = stateEntry?.data?.reviewerThinkingLevel ?? "minimal";

    if (stateEntry?.data?.reviewerOverride) {
      const ref = stateEntry.data.reviewerOverride;
      modelToUse = ctx.modelRegistry.find(ref.provider, ref.id);
    }

    if (!modelToUse) {
      modelToUse = ctx.modelRegistry.find("github-copilot", "gemini-3-flash-preview");
    }
  } else {
    if (!ctx.model) {
      throw new Error("No active model selected for final reviewer subagent.");
    }
    modelToUse = ctx.model;
  }

  if (!modelToUse) {
    throw new Error("No reviewer model could be resolved.");
  }

  const modelArg =
    thinkingLevelToUse === "off" ? `${modelToUse.provider}/${modelToUse.id}` : `${modelToUse.provider}/${modelToUse.id}:${thinkingLevelToUse}`;
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(modelToUse);
  if (!auth.ok) {
    throw new Error(`Unable to resolve auth for reviewer subagent: ${auth.error}`);
  }
  onProgress?.({ phase: "starting" });
  const run = await runReviewerSubagent(ctx.cwd, prompt, modelArg, auth, signal, onProgress);
  const final = extractFinalAssistantText(
    [
      ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
      ...run.messages,
      ...(run.turnEndMessage ? [run.turnEndMessage] : []),
      ...(run.agentEndMessage ? [run.agentEndMessage] : []),
    ],
    run.streamedText,
  );
  if (final.text) {
    return {
      report: final.text,
      repoRoot: git.repoRoot,
      changedFiles: git.changedFiles,
      reviewerModel: modelArg,
      subagentMetrics: buildReviewSubagentMetrics(run),
    };
  }

  const stderr = run.stderr.trim();
  const errorSuffix = final.errorMessage ? `; error: ${final.errorMessage}` : stderr ? `; stderr: ${stderr}` : "";
  const streamedPreview = run.streamedText.trim();
  const streamedSuffix = streamedPreview ? `; streamedText: ${JSON.stringify(truncate(streamedPreview, 400))}` : "";
  const contentTypes = [run.lastAssistantPartial, run.turnEndMessage, run.agentEndMessage]
    .filter((message): message is Message => Boolean(message))
    .map((message) => `${message.role}:${message.content.map((part) => part.type).join(",") || "(none)"}`)
    .join(" | ");
  const contentSuffix = contentTypes ? `; fallbackMessages: ${contentTypes}` : "";
  throw new Error(
    `Reviewer subagent returned no text content (exitCode: ${run.exitCode}; stopReason: ${run.stopReason ?? "none"}${errorSuffix}${streamedSuffix}${contentSuffix}).`,
  );
}

export default function (pi: ExtensionAPI) {
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
    label: "Review changes",
    description:
      "Spawn a reviewer subagent in a fresh no-session pi process to inspect current git changes and report issues, improvements, and style drift. Interim reviews use a cheaper reviewer model; final reviews use the active model.",
    promptSnippet:
      "Spawn a reviewer subagent to inspect code changes; use a cheaper model for interim reviews and the active model only for final reviews.",
    promptGuidelines: [
      "Use review_changes when the user explicitly asks for review, or after large/risky changes such as multi-file edits, refactors, migrations, non-trivial behavior changes, or broad code generation.",
      "Do not use review_changes for tiny, obvious, or single-line changes unless the user specifically asks for a review.",
      "When using review_changes, pass a short context summary describing what changed and why so the reviewer can judge correctness against intent.",
      "When bounded worker tasks are succeeding with clean validation, trust those sub-steps by default and avoid calling review_changes after each successful worker return.",
      "Prefer one final review pass once you believe the full user request is implemented, unless the user asked for an interim review, a worker escalated or failed validation, or you need to inspect risky supervisor-owned integration.",
      "Use stage: interim for automated or early-cycle checks to save costs. Use stage: final only for the definitive review before completion.",
    ],
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
        StringEnum(["interim", "final"], {
          description: "Review stage. interim uses a cheaper model for early checks. final uses the current active model. Defaults to interim.",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      onUpdate?.({ content: [{ type: "text", text: "Collecting changed files and recent context..." }] });
      const result = await generateReview(ctx, pi.getThinkingLevel(), params, signal, (progress) => {
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
      onUpdate?.({ content: [{ type: "text", text: "Reviewer subagent finished." }] });
      return {
        content: [{ type: "text", text: result.report }],
        details: {
          generatedAt,
          sessionKey,
          repoRoot: result.repoRoot,
          changedFiles: result.changedFiles,
          reviewer: result.reviewerModel,
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
        const result = await generateReview(ctx, pi.getThinkingLevel(), { stage, context: rest || undefined }, ctx.signal);
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
