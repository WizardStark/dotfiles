import type { AgentMessage, ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Message } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative } from "node:path";

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
};

type ReviewParams = {
  context?: string;
  focus?: string;
};

type ReviewRunState = {
  messages: Message[];
  streamedText: string;
  lastAssistantPartial?: Message;
  turnEndMessage?: Message;
  agentEndMessage?: Message;
  stderr: string;
  exitCode: number;
  stopReason?: string;
  errorMessage?: string;
};

function truncate(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n...[truncated ${text.length - maxChars} chars]`;
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

function textFromMessage(message: AgentMessage): string {
  if (message.role === "assistant" || message.role === "user" || message.role === "system") {
    return (message.content ?? [])
      .map((part) => {
        if (part.type === "text") return part.text ?? "";
        if (part.type === "thinking") return "";
        return "";
      })
      .join("\n")
      .trim();
  }

  if (message.role === "compactionSummary") {
    return message.summary?.trim() ?? "";
  }

  return "";
}

function entryToMessage(entry: SessionEntry): AgentMessage | undefined {
  if (entry.type === "message") {
    return entry.message;
  }
  if (entry.type === "compaction") {
    return {
      role: "compactionSummary",
      summary: entry.summary,
      tokensBefore: entry.tokensBefore,
      timestamp: new Date(entry.timestamp).getTime(),
    };
  }
  return undefined;
}

function getSessionMessages(branch: SessionEntry[]): AgentMessage[] {
  let compactionIndex = -1;
  for (let i = branch.length - 1; i >= 0; i--) {
    if (branch[i].type === "compaction") {
      compactionIndex = i;
      break;
    }
  }

  if (compactionIndex < 0) {
    return branch.map(entryToMessage).filter((message): message is AgentMessage => message !== undefined);
  }

  const compaction = branch[compactionIndex];
  const firstKeptIndex =
    compaction.type === "compaction" ? branch.findIndex((entry) => entry.id === compaction.firstKeptEntryId) : -1;
  const compactedBranch = [
    compaction,
    ...(firstKeptIndex >= 0 ? branch.slice(firstKeptIndex, compactionIndex) : []),
    ...branch.slice(compactionIndex + 1),
  ];

  return compactedBranch.map(entryToMessage).filter((message): message is AgentMessage => message !== undefined);
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

function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
  if (currentScript && !isBunVirtualScript && existsSync(currentScript)) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }

  const execName = basename(process.execPath).toLowerCase();
  const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
  if (!isGenericRuntime) {
    return { command: process.execPath, args };
  }

  return { command: "pi", args };
}

function extractFinalAssistantText(
  messages: Message[],
  streamedText = "",
): { text: string; stopReason?: string; errorMessage?: string } {
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg.role !== "assistant") continue;

    const text = msg.content
      .filter((part): part is { type: "text"; text: string } => part.type === "text")
      .map((part) => part.text)
      .join("\n")
      .trim();

    return {
      text: text || streamedText.trim(),
      stopReason: msg.stopReason,
      errorMessage: msg.errorMessage,
    };
  }

  return { text: "" };
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
  apiKey: string | undefined,
  signal?: AbortSignal,
): Promise<ReviewRunState> {
  const tempDir = await mkdtemp(join(tmpdir(), "pi-reviewer-"));
  const systemPromptPath = join(tempDir, "system-prompt.md");
  await writeFile(systemPromptPath, REVIEW_SYSTEM_PROMPT, "utf8");

  try {
    const args = [
      "--mode",
      "json",
      "-p",
      "--no-session",
      "--model",
      modelArg,
      ...(apiKey ? ["--api-key", apiKey] : []),
      "--append-system-prompt",
      systemPromptPath,
      prompt,
    ];
    const invocation = getPiInvocation(args);

    return await new Promise<ReviewRunState>((resolve) => {
      const proc = spawn(invocation.command, invocation.args, {
        cwd,
        stdio: ["ignore", "pipe", "pipe"],
      });

      const state: ReviewRunState = {
        messages: [],
        streamedText: "",
        stderr: "",
        exitCode: 1,
      };
      let buffer = "";
      let settled = false;
      const streamedTextParts: string[] = [];

      const finish = (exitCode: number) => {
        if (settled) return;
        settled = true;
        state.exitCode = exitCode;
        state.streamedText = streamedTextParts.map((part) => part ?? "").join("").trim();
        const final = extractFinalAssistantText(
          [
            ...state.messages,
            ...(state.turnEndMessage ? [state.turnEndMessage] : []),
            ...(state.agentEndMessage ? [state.agentEndMessage] : []),
            ...(state.lastAssistantPartial ? [state.lastAssistantPartial] : []),
          ],
          state.streamedText,
        );
        state.stopReason = final.stopReason;
        state.errorMessage = final.errorMessage;
        resolve(state);
      };

      const processLine = (line: string) => {
        if (!line.trim()) return;
        try {
          const event = JSON.parse(line);
          if (event.type === "message_update") {
            const assistantEvent = event.assistantMessageEvent;
            if (assistantEvent?.partial) {
              state.lastAssistantPartial = assistantEvent.partial as Message;
            }
            if (assistantEvent?.type === "text_start") {
              streamedTextParts[assistantEvent.contentIndex] ??= "";
            }
            if (assistantEvent?.type === "text_delta") {
              const index = assistantEvent.contentIndex;
              streamedTextParts[index] = `${streamedTextParts[index] ?? ""}${assistantEvent.delta ?? ""}`;
            }
            if (assistantEvent?.type === "text_end") {
              streamedTextParts[assistantEvent.contentIndex] = assistantEvent.content ?? "";
            }
          }
          if (event.type === "message_end" && event.message) {
            state.messages.push(event.message as Message);
          }
          if (event.type === "turn_end" && event.message) {
            state.turnEndMessage = event.message as Message;
          }
          if (event.type === "agent_end" && Array.isArray(event.messages)) {
            for (let i = event.messages.length - 1; i >= 0; i--) {
              if (event.messages[i]?.role === "assistant") {
                state.agentEndMessage = event.messages[i] as Message;
                break;
              }
            }
          }
          if (event.type === "error" && typeof event.error === "string") {
            state.stderr += `${event.error}\n`;
          }
        } catch {
          // ignore malformed lines
        }
      };

      proc.stdout.on("data", (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) processLine(line);
      });

      proc.stderr.on("data", (chunk) => {
        state.stderr += chunk.toString();
      });

      proc.on("close", (code) => {
        if (buffer.trim()) processLine(buffer);
        finish(code ?? 1);
      });
      proc.on("error", (error) => {
        state.stderr += `${error instanceof Error ? error.message : String(error)}\n`;
        finish(1);
      });

      if (signal) {
        const onAbort = () => {
          proc.kill("SIGTERM");
          setTimeout(() => {
            try {
              proc.kill("SIGKILL");
            } catch {
              // ignore
            }
          }, 5000);
        };
        if (signal.aborted) onAbort();
        else signal.addEventListener("abort", onAbort, { once: true });
      }
    });
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}

async function generateReview(
  ctx: ExtensionContext,
  thinkingLevel: ThinkingLevel,
  input: ReviewParams,
  signal?: AbortSignal,
): Promise<ReviewResult> {
  if (!ctx.model) {
    throw new Error("No active model selected for reviewer subagent.");
  }

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

  const modelArg =
    thinkingLevel === "off" ? `${ctx.model.provider}/${ctx.model.id}` : `${ctx.model.provider}/${ctx.model.id}:${thinkingLevel}`;
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!auth.ok) {
    throw new Error(`Unable to resolve auth for reviewer subagent: ${auth.error}`);
  }
  if (auth.headers && Object.keys(auth.headers).length > 0) {
    throw new Error(
      "Reviewer subagent cannot inherit current-session auth headers for this model; strict same-model subprocess review is not supported for header-based auth.",
    );
  }
  const run = await runReviewerSubagent(ctx.cwd, prompt, modelArg, auth.apiKey, signal);
  const final = extractFinalAssistantText(
    [
      ...run.messages,
      ...(run.turnEndMessage ? [run.turnEndMessage] : []),
      ...(run.agentEndMessage ? [run.agentEndMessage] : []),
      ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
    ],
    run.streamedText,
  );
  if (final.text) {
    return {
      report: final.text,
      repoRoot: git.repoRoot,
      changedFiles: git.changedFiles,
      reviewerModel: modelArg,
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
      "Spawn a reviewer subagent in a fresh no-session pi process using the exact current model to inspect current git changes and report issues, improvements, and style drift.",
    promptSnippet:
      "Spawn a reviewer subagent in a fresh isolated pi process using the exact current model to inspect code changes and report issues.",
    promptGuidelines: [
      "Use review_changes when the user explicitly asks for review, or after large/risky changes such as multi-file edits, refactors, migrations, non-trivial behavior changes, or broad code generation.",
      "Do not use review_changes for tiny, obvious, or single-line changes unless the user specifically asks for a review.",
      "When using review_changes, pass a short context summary describing what changed and why so the reviewer can judge correctness against intent.",
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
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      onUpdate?.({ content: [{ type: "text", text: "Collecting changed files and recent context..." }] });
      const result = await generateReview(ctx, pi.getThinkingLevel(), params, signal);
      onUpdate?.({ content: [{ type: "text", text: "Reviewer subagent finished." }] });
      return {
        content: [{ type: "text", text: result.report }],
        details: {
          repoRoot: result.repoRoot,
          changedFiles: result.changedFiles,
          reviewer: result.reviewerModel,
        },
      };
    },
  });

  pi.registerCommand("review", {
    description: "Run a reviewer subagent on current git changes using the exact current model. Usage: /review [focus or context]",
    handler: async (args, ctx) => {
      try {
        ctx.ui.notify("Reviewer subagent: collecting context and reviewing changes...", "info");
        const result = await generateReview(ctx, pi.getThinkingLevel(), { context: args.trim() || undefined }, ctx.signal);
        pi.sendMessage({
          customType: REVIEW_REPORT_TYPE,
          content: `## Reviewer report\n\n${result.report}`,
          display: true,
          details: {
            generatedAt: Date.now(),
            repoRoot: result.repoRoot,
            changedFiles: result.changedFiles,
            reviewer: result.reviewerModel,
          },
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Reviewer subagent failed: ${message}`, "error");
      }
    },
  });
}
