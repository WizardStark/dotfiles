import { complete, type Message } from "@earendil-works/pi-ai";
import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";
import { relative } from "node:path";

const execFileAsync = promisify(execFile);

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
};

type ReviewParams = {
  context?: string;
  focus?: string;
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

async function runGit(cwd: string, args: string[], signal?: AbortSignal, timeout = 15000): Promise<string> {
  const result = await execFileAsync("git", args, {
    cwd,
    signal,
    timeout,
    maxBuffer: 2 * 1024 * 1024,
  });
  return result.stdout.trim();
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
      parts.push(`### ${file}\n\n\
\`\`\`\n${truncate(content, MAX_UNTRACKED_FILE_CHARS)}\n\`\`\``);
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

async function generateReview(
  ctx: Parameters<ExtensionAPI["registerCommand"]>[1]["handler"] extends (args: any, ctx: infer T) => any ? T : never,
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

  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!auth.ok || !auth.apiKey) {
    throw new Error(auth.ok ? `No API key for ${ctx.model.provider}` : auth.error);
  }

  const response = await complete(
    ctx.model,
    {
      systemPrompt: REVIEW_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: prompt }],
          timestamp: Date.now(),
        } satisfies Message,
      ],
    },
    {
      apiKey: auth.apiKey,
      headers: auth.headers,
      maxTokens: 4096,
      signal,
    },
  );

  const report = response.content
    .filter((part): part is { type: "text"; text: string } => part.type === "text")
    .map((part) => part.text)
    .join("\n")
    .trim();

  if (!report) {
    throw new Error("Reviewer subagent returned an empty report.");
  }

  return {
    report,
    repoRoot: git.repoRoot,
    changedFiles: git.changedFiles,
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "review_changes",
    label: "Review changes",
    description:
      "Spawn a reviewer subagent that inspects current git changes, checks them against recent session context, and reports issues, improvements, and style drift.",
    promptSnippet:
      "Spawn a reviewer subagent to inspect current code changes and report problems, improvement opportunities, and style drift.",
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
      const result = await generateReview(ctx as any, params, signal);
      onUpdate?.({ content: [{ type: "text", text: "Reviewer subagent finished." }] });
      return {
        content: [{ type: "text", text: result.report }],
        details: {
          repoRoot: result.repoRoot,
          changedFiles: result.changedFiles,
          reviewer: `${ctx.model?.provider}/${ctx.model?.id}`,
        },
      };
    },
  });

  pi.registerCommand("review", {
    description: "Run a reviewer subagent on current git changes. Usage: /review [focus or context]",
    handler: async (args, ctx) => {
      try {
        ctx.ui.notify("Reviewer subagent: collecting context and reviewing changes...", "info");
        const result = await generateReview(ctx as any, { context: args.trim() || undefined }, ctx.signal);
        pi.sendMessage({
          customType: REVIEW_REPORT_TYPE,
          content: `## Reviewer report\n\n${result.report}`,
          display: true,
          details: {
            generatedAt: Date.now(),
            repoRoot: result.repoRoot,
            changedFiles: result.changedFiles,
          },
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Reviewer subagent failed: ${message}`, "error");
      }
    },
  });
}
