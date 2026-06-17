import type {
  AgentMessage,
  ThinkingLevel,
} from "@earendil-works/pi-agent-core";
import type { Api, Model } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import {
  convertToLlm,
  serializeConversation,
} from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readdir, readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { basename, join, relative, resolve } from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";
import {
  entryToMessage,
  getSessionMessages,
  textFromMessage,
  truncate,
} from "./lib/session-messages.ts";
import {
  findModel,
  resolveExactModelReference,
  sameModel,
  toRef,
  type ModelRef,
} from "./lib/model-ref.ts";
import {
  buildSubagentMetrics,
  extractFinalAssistantText,
  runSubagentProcess,
  type SubagentMetrics,
} from "./lib/subagent-runtime.ts";
import { ManagedWidget } from "./lib/ui-widgets.ts";

interface SupervisorWorkerState {
  override?: ModelRef;
  thinkingLevel?: ThinkingLevel;
  scoutOverride?: ModelRef;
  scoutThinkingLevel?: ThinkingLevel;
  reviewerOverride?: ModelRef;
  reviewerThinkingLevel?: ThinkingLevel;
  autoMode?: "conservative" | "off";
}

interface ActiveDelegation {
  id: string;
  title: string;
  workerModel: string;
  phase: string;
  role: "worker" | "scout";
  turns?: number;
  currentTool?: string;
  detailText?: string;
  recentActivity?: string[];
}

type SubagentProgress = {
  turns?: number;
  currentTool?: string;
  lastActivityLine?: string;
};

interface TurnDelegationState {
  prompt: string;
  enforcePlanSplit: boolean;
  completedWorkerDelegations: number;
  completedScoutDelegations: number;
  completedReviewDelegations: number;
  nudgedDirectMutation: boolean;
  nudgedReviewDeferral: boolean;
  usedExplicitReviewBypass: boolean;
  postHandoffReads: number;
  postHandoffEdits: number;
  nudgedExpensivePostHandoff: boolean;
}

type HandoffEditLocation = {
  path: string;
  startLine?: number;
  endLine?: number;
  summary?: string;
  sourceTool?: "edit" | "write" | "file";
  precision?: "range" | "file";
};

interface HandoffPointer {
  source: string;
  toolName: string;
  title: string;
  status: string;
  generatedAt: number;
  summary: string;
  filesChanged: string[];
  editLocations: HandoffEditLocation[];
  artifactSources: string[];
  artifactQueries: string[];
  artifactSummary?: string;
  indexed?: boolean;
}

type DelegateParams = {
  objective: string;
  scope?: string;
  allowedFiles?: string[];
  blockedFiles?: string[];
  acceptanceCriteria?: string[];
  validationCommands?: string[];
  escalationTriggers?: string[];
  workerModel?: string;
  workerThinkingLevel?: ThinkingLevel;
  cwd?: string;
  tools?: string[];
  artifactSources?: string[];
  artifactQueries?: string[];
  artifactSummary?: string;
};

type ScoutParams = {
  objective: string;
  scope?: string;
  questions?: string[];
  expectedOutputs?: string[];
  scoutModel?: string;
  scoutThinkingLevel?: ThinkingLevel;
  cwd?: string;
  tools?: string[];
  artifactSources?: string[];
  artifactQueries?: string[];
  artifactSummary?: string;
};

type DelegateStatus = "completed" | "escalated" | "blocked" | "unknown";

type ValidationOutcome = "pass" | "fail";

type ValidationResult = {
  command: string;
  outcome: ValidationOutcome;
  exitCode: number | null;
  note: string;
};

type WorkerToolExecution = {
  toolCallId?: string;
  toolName: string;
  args?: Record<string, unknown>;
  result?: unknown;
  isError?: boolean;
};

type DelegateResult = {
  report: string;
  fullReport: string;
  workerModel: string;
  status: DelegateStatus;
  filesChanged: string[];
  editLocations: HandoffEditLocation[];
  artifactSources: string[];
  artifactQueries: string[];
  artifactSummary?: string;
  boundaryViolations: string[];
  validation: ValidationResult[];
  subagentMetrics?: SubagentMetrics;
  stopReason?: string;
  errorMessage?: string;
};

type ParallelDelegateTask = DelegateParams & {
  label?: string;
};

type ParallelDelegateTaskResult = DelegateResult & {
  label: string;
};

type ScoutResult = {
  report: string;
  fullReport: string;
  status: DelegateStatus;
  scoutModel: string;
  artifactSources: string[];
  artifactQueries: string[];
  artifactSummary?: string;
  subagentMetrics?: SubagentMetrics;
  stopReason?: string;
  errorMessage?: string;
};

type ParallelScoutTask = ScoutParams & {
  label?: string;
};

type ParallelScoutTaskResult = ScoutResult & {
  label: string;
  status: "completed" | "blocked";
};

const STATE_ENTRY = "supervisor-worker-state";
const SUBAGENT_EVENT_ENTRY = "subagent-event";
const DEFAULT_WORKER_THINKING_LEVEL: ThinkingLevel = "minimal";

const DEFAULT_SCOUT_THINKING_LEVEL: ThinkingLevel = "minimal";

const DEFAULT_REVIEWER_THINKING_LEVEL: ThinkingLevel = "minimal";

const DEFAULT_AUTO_MODE = "conservative" as const;
const MAX_CONTEXT_CHARS = 6_000;
const MAX_MESSAGES = 6;
const DEFAULT_PARALLEL_SUBAGENT_CONCURRENCY = 2;
const MAX_PARALLEL_SUBAGENT_CONCURRENCY = 4;
const MAX_PARALLEL_SUBAGENT_TASKS = 4;
const MAX_PARALLEL_REPORT_CHARS = 4_000;
const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
] as const;
const WORKER_ENV_FLAG = "PI_SUPERVISOR_WORKER_ROLE";
const HANDOFF_ENTRY = "subagent-handoff";
const REVIEW_STATE_ENTRY = "review-dedupe-state";
const HANDOFF_SOURCE_PREFIX = "subagent-handoff";
const MAX_RECENT_HANDOFFS = 4;
const MAX_HANDOFF_PROMPT_CHARS = 4_000;
const MAX_PERSISTED_REVIEW_KEYS = 8;
const HANDOFF_RELEVANCE_STOP_WORDS = new Set([
  "about",
  "after",
  "again",
  "also",
  "and",
  "from",
  "have",
  "into",
  "just",
  "need",
  "that",
  "their",
  "them",
  "then",
  "this",
  "with",
  "would",
]);
const SUBAGENTS_WIDGET = new ManagedWidget("subagents", { placement: "belowEditor" });
const SUBAGENT_ACTIVITY_COMMAND = "subagents";
const SUBAGENT_ACTIVITY_SHORTCUT = "ctrl+alt+o";
const MAX_SUBAGENT_DETAIL_LINES = 6;
const MAX_SUBAGENT_DETAIL_CHARS = 1_200;
const MAX_SUBAGENT_ACTIVITY_LINES = 8;
const IMPLEMENTATION_PROMPT_PATTERNS: RegExp[] = [
  /\b(implement|refactor|fix|change|update|edit|modify|rewrite|extract|rename|migrate|wire|hook up)\b/i,
  /\b(add|remove|create|write)\b.{0,24}\b(test|tests|code|function|component|extension|tool|handler|widget|command)\b/i,
  /\bperform the refactor\b/i,
  /\bmake .* use\b/i,
];
const NON_IMPLEMENTATION_PROMPT_PATTERNS: RegExp[] = [
  /^\s*\//,
  /^\s*!/,
  /\b(explain|why|what is|how does|review|analyze|summarize|design|brainstorm|discuss)\b/i,
];
const MUTATING_BASH_PATTERNS: RegExp[] = [
  /^\s*(mkdir|mv|cp|rm|touch|chmod|chown|ln)\b/i,
  /^\s*git\s+(add|apply|checkout|restore|mv|rm|commit|merge|rebase|cherry-pick|push|pull|fetch)\b/i,
  /^\s*(npm|pnpm|yarn|bun)\s+(install|add|remove|unlink|update|link)\b/i,
  /^\s*(pip|pip3|conda)\s+(install|uninstall|update)\b/i,
  /^\s*uv\s+pip\s+(install|uninstall)\b/i,
  /^\s*(sed|awk|truncate|dd)\b/i,
  /^\s*perl\b.*-i\b/i,
  /^\s*tee\b/i,
  /[>|]\s*[^>|]+\.[^>|]+/, // redirect or pipe to file (coarse)
];
const PREFERRED_CONTEXT_MODE_TOOLS = [
  "ctx_search",
  "ctx_execute",
  "ctx_execute_file",
  "ctx_batch_execute",
  "ctx_index",
  "ctx_fetch_and_index",
] as const;
const DEFAULT_SCOUT_TOOLS = [
  ...PREFERRED_CONTEXT_MODE_TOOLS,
  "read",
  "grep",
  "find",
  "ls",
];
const SCOUT_SAFE_TOOLS = new Set(DEFAULT_SCOUT_TOOLS);
const SCOUT_BLOCKED_TOOLS = new Set([
  "edit",
  "write",
  "bash",
]);

const WORKER_SYSTEM_PROMPT = `You are a delegated worker subagent inside pi.

Your job:
- Execute one bounded implementation task.
- Treat the provided contract as authoritative.
- Prefer concrete code changes over discussion.
- Keep changes as small and local as possible.
- Respect allowed and blocked file boundaries.
- Do not broaden scope on your own.
- Do not delegate further.
- Do not ask the user questions directly.
- If the task becomes ambiguous, risky, cross-cutting, or requires touching forbidden files, stop and escalate instead of guessing.
- Use tools, tests, lint, and typechecks as the source of truth when available.
- Prefer ctx_* tools over bash/read for inspection, repository searches, docs lookup, tests, git/history, and large-output analysis.
- Use bash mainly for safe mutations/navigation/process control, and use read mainly when you need exact file text for an edit or a tiny targeted excerpt.
- If a tool policy blocks an inspection command, do not repeat the same bash/read attempt; switch to an allowed ctx_* workflow or escalate.
- For late-session work, prioritize narrow follow-up fixes, integration polish, and validation-driven refactors.
- Prefer reusable artifact-producing tools (ctx_batch_execute, ctx_index, ctx_fetch_and_index, large ctx_execute with intent) for shared research.
- When reusing an existing artifact, reference its source label in your Summary/Edits and mention why it was useful.

Return exactly this Markdown structure:

## Status
- completed | escalated | blocked

## Summary
- concise bullets (one line each) describing what you changed or why you stopped

## Files Changed
- one file per bullet
- If none: (none)

## Edits
- file:path:line or file:path:start-end - concise description (one line) of the changed location
- If you only know the file, say file:path - file-level change
- If none: (none)

## Validation
- [command] - pass | fail | not run - brief note
- If none: (none)

## Escalation
- concrete blocker, risk, or question
- If none: (none)

Report style:
- Be extremely concise.
- Use single-line bullets for Summary and Edits.
- Omit discussion or meta-commentary outside the sections.
- The supervisor sees your full output; favor brevity over repetition.`;

const SCOUT_SYSTEM_PROMPT = `You are a scouting subagent inside pi.

Your job:
- Perform read-only reconnaissance for the supervisor.
- Explore the codebase, search for relevant files, trace behavior, and summarize evidence.
- Do not edit files, write files, or run mutating shell commands.
- Prefer ctx_* tools over read-oriented primitives for searches, summaries, logs, diffs, test output, and other analysis work.
- Use read only for exact small excerpts the supervisor is likely to need verbatim.
- If a tool policy blocks an inspection approach, switch to an allowed ctx_* workflow instead of retrying the same call.
- Prefer concrete findings with file paths over speculation.
- Call out uncertainty clearly when evidence is incomplete.
- Recommend a practical next step for the supervisor.
- Prefer scout-safe reusable artifact workflows such as ctx_search, ctx_execute with intent, and any allowed indexing tools for shared research.
- When reusing an existing artifact, reference its source label in your Summary/Findings and mention why it was useful.

Return exactly this Markdown structure:

## Summary
- concise bullets (one line each) with the top findings

## Relevant Files
- one file per bullet
- If none: (none)

## Findings
- evidence with file paths and why it matters
- If none: (none)

## Recommended Next Step
- the best next action for the supervisor
- If none: (none)

Report style:
- Be extremely concise.
- Use single-line bullets for Summary and Findings.
- Omit discussion or meta-commentary outside the sections.
- The supervisor sees your full output; favor brevity over repetition.`;


function formatModel(ref?: ModelRef, thinkingLevel?: ThinkingLevel): string {
  if (!ref) return "none";
  return thinkingLevel && thinkingLevel !== "off"
    ? `${ref.provider}/${ref.id}:${thinkingLevel}`
    : `${ref.provider}/${ref.id}`;
}

function parseModelRef(
  ctx: ExtensionContext,
  raw: string,
): ModelRef | undefined {
  const resolved = resolveExactModelReference(
    raw,
    ctx.modelRegistry.getAvailable(),
  );
  return resolved.status === "matched" ? toRef(resolved.model) : undefined;
}

function resolveRequestedModel(
  ctx: ExtensionContext,
  raw: string,
  role: "worker" | "scout" | "reviewer",
): { ref: ModelRef; model: Model<Api> } | { error: string } {
  const resolved = resolveExactModelReference(
    raw,
    ctx.modelRegistry.getAvailable(),
  );

  if (resolved.status === "matched") {
    const ref = toRef(resolved.model);
    if (ref) {
      return { ref, model: resolved.model };
    }
  }

  const roleLabel = `${role[0].toUpperCase()}${role.slice(1)}`;
  if (resolved.status === "ambiguous") {
    return {
      error: `${roleLabel} model is ambiguous: ${raw.trim()}. Use provider/model.`,
    };
  }
  if (resolved.status === "not_found") {
    return {
      error: `${roleLabel} model not found: ${raw.trim()}. Use provider/model if needed.`,
    };
  }
  return {
    error: `Unable to parse ${role} model. Use model or provider/model.`,
  };
}

function readSavedState(
  ctx: ExtensionContext,
): SupervisorWorkerState | undefined {
  const entry = [...ctx.sessionManager.getEntries()]
    .reverse()
    .find(
      (item) => item.type === "custom" && item.customType === STATE_ENTRY,
    ) as { data?: SupervisorWorkerState } | undefined;

  const override = entry?.data?.override;
  const thinkingLevel = entry?.data?.thinkingLevel;
  const scoutOverride = entry?.data?.scoutOverride;
  const scoutThinkingLevel = entry?.data?.scoutThinkingLevel;
  const reviewerOverride = entry?.data?.reviewerOverride;
  const reviewerThinkingLevel = entry?.data?.reviewerThinkingLevel;
  const autoMode = entry?.data?.autoMode;
  const nextState: SupervisorWorkerState = {};

  if (override?.provider && override?.id) {
    nextState.override = override;
  }
  if (thinkingLevel && THINKING_LEVELS.includes(thinkingLevel)) {
    nextState.thinkingLevel = thinkingLevel;
  }
  if (scoutOverride?.provider && scoutOverride?.id) {
    nextState.scoutOverride = scoutOverride;
  }
  if (scoutThinkingLevel && THINKING_LEVELS.includes(scoutThinkingLevel)) {
    nextState.scoutThinkingLevel = scoutThinkingLevel;
  }
  if (reviewerOverride?.provider && reviewerOverride?.id) {
    nextState.reviewerOverride = reviewerOverride;
  }
  if (reviewerThinkingLevel && THINKING_LEVELS.includes(reviewerThinkingLevel)) {
    nextState.reviewerThinkingLevel = reviewerThinkingLevel;
  }
  if (autoMode === "conservative" || autoMode === "off") {
    nextState.autoMode = autoMode;
  }

  return nextState.override ||
    nextState.thinkingLevel ||
    nextState.scoutOverride ||
    nextState.scoutThinkingLevel ||
    nextState.reviewerOverride ||
    nextState.reviewerThinkingLevel ||
    nextState.autoMode
    ? nextState
    : undefined;
}

function readSavedReviewKeys(ctx: ExtensionContext): string[] {
  const entry = [...ctx.sessionManager.getEntries()]
    .reverse()
    .find(
      (item) => item.type === "custom" && item.customType === REVIEW_STATE_ENTRY,
    ) as { data?: { recentReviewKeys?: string[] } } | undefined;

  return Array.isArray(entry?.data?.recentReviewKeys)
    ? entry.data.recentReviewKeys.filter(
        (item): item is string => typeof item === "string" && item.trim().length > 0,
      )
    : [];
}

function getPreferredFallbackRef(ctx: ExtensionContext): ModelRef | undefined {
  const preferred = resolveExactModelReference(
    "github-copilot/gemini-3-flash-preview",
    ctx.modelRegistry.getAvailable(),
  );
  if (preferred.status === "matched") {
    return toRef(preferred.model);
  }
  return toRef(ctx.model);
}

function getDefaultWorkerRef(ctx: ExtensionContext): ModelRef | undefined {
  return getPreferredFallbackRef(ctx);
}

function getEffectiveWorkerRef(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
): ModelRef | undefined {
  return state.override ?? getDefaultWorkerRef(ctx);
}

function getEffectiveScoutRef(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
): ModelRef | undefined {
  return state.scoutOverride ?? getPreferredFallbackRef(ctx);
}

function getEffectiveScoutThinkingLevel(
  state: SupervisorWorkerState,
): ThinkingLevel {
  return state.scoutThinkingLevel ?? DEFAULT_SCOUT_THINKING_LEVEL;
}

function getEffectiveReviewerRef(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
): ModelRef | undefined {
  return state.reviewerOverride ?? getPreferredFallbackRef(ctx);
}

function getEffectiveReviewerThinkingLevel(
  state: SupervisorWorkerState,
): ThinkingLevel {
  return state.reviewerThinkingLevel ?? DEFAULT_REVIEWER_THINKING_LEVEL;
}

function getEffectiveThinkingLevel(
  state: SupervisorWorkerState,
): ThinkingLevel {
  return state.thinkingLevel ?? DEFAULT_WORKER_THINKING_LEVEL;
}

function getAutoMode(state: SupervisorWorkerState): "conservative" | "off" {
  return state.autoMode ?? DEFAULT_AUTO_MODE;
}

function resultWorkerLabelFallback(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: DelegateParams,
): string {
  const thinkingLevel =
    params.workerThinkingLevel ?? getEffectiveThinkingLevel(state);
  const requestedRef = params.workerModel
    ? parseModelRef(ctx, params.workerModel)
    : getEffectiveWorkerRef(ctx, state);
  return formatModel(requestedRef, thinkingLevel);
}

function resultScoutLabelFallback(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
): string {
  const thinkingLevel =
    params.scoutThinkingLevel ?? getEffectiveScoutThinkingLevel(state);
  const requestedRef = params.scoutModel
    ? parseModelRef(ctx, params.scoutModel)
    : getEffectiveScoutRef(ctx, state);
  return formatModel(requestedRef, thinkingLevel);
}

function updateStatus(ctx: ExtensionContext, state: SupervisorWorkerState) {
  const worker = getEffectiveWorkerRef(ctx, state);
  if (!worker) {
    ctx.ui.setStatus("worker", undefined);
    ctx.ui.setStatus("worker-auto", undefined);
    return;
  }

  const suffix = getEffectiveThinkingLevel(state);
  const text = suffix === "off" ? worker.id : `${worker.id}:${suffix}`;
  ctx.ui.setStatus("worker", ctx.ui.theme.fg("muted", `worker:${text}`));
  ctx.ui.setStatus(
    "worker-auto",
    ctx.ui.theme.fg("muted", `auto:${getAutoMode(state)}`),
  );
}


function singleLine(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function countLines(text: string): number {
  return text.length === 0 ? 1 : text.split("\n").length;
}

function formatLineRange(startLine?: number, endLine?: number): string {
  if (typeof startLine !== "number" && typeof endLine !== "number") {
    return "";
  }
  const start = startLine ?? endLine;
  const end = endLine ?? startLine;
  if (start === undefined || end === undefined) {
    return "";
  }
  return start === end ? `${start}` : `${start}-${end}`;
}

function normalizeRepoPath(root: string, value: string): string {
  const normalizedRoot = normalizeComparablePath(root);
  const trimmed = value.replace(/\\/g, "/").trim();
  if (!trimmed) return "";

  const normalizedValue = normalizeComparablePath(trimmed);
  if (normalizedValue === normalizedRoot) {
    return "";
  }
  if (normalizedValue.startsWith(`${normalizedRoot}/`)) {
    return normalizePath(normalizedValue.slice(normalizedRoot.length + 1));
  }

  const rootWithoutLeadingSlash = normalizedRoot.replace(/^\//, "");
  if (rootWithoutLeadingSlash && trimmed.startsWith(`${rootWithoutLeadingSlash}/`)) {
    return normalizePath(trimmed.slice(rootWithoutLeadingSlash.length + 1));
  }

  const hasGitRoot = existsSync(join(root, ".git"));
  if (/^(?:[A-Za-z]:\/|\/)/.test(trimmed)) {
    return hasGitRoot ? "" : trimmed.replace(/\\/g, "/").replace(/\/+$/, "");
  }

  return normalizePath(trimmed);
}

function isIncidentalHandoffPath(filePath: string): boolean {
  const normalized = normalizePath(filePath).toLowerCase();
  if (!normalized) return false;
  const name = basename(normalized);
  return [
    "grep_results.txt",
    "rg_results.txt",
    "ripgrep_results.txt",
    "search_results.txt",
  ].includes(name);
}

function normalizeEditLocation(
  location: HandoffEditLocation,
): HandoffEditLocation | undefined {
  const path = typeof location.path === "string" ? normalizePath(location.path) : "";
  if (!path || isIncidentalHandoffPath(path)) return undefined;
  const startLine = Number.isFinite(location.startLine) ? Number(location.startLine) : undefined;
  const endLine = Number.isFinite(location.endLine) ? Number(location.endLine) : undefined;
  const summary = typeof location.summary === "string" && location.summary.trim()
    ? singleLine(location.summary)
    : undefined;
  const sourceTool = location.sourceTool;
  const precision = location.precision ?? (startLine !== undefined || endLine !== undefined ? "range" : "file");
  return {
    path,
    startLine,
    endLine,
    summary,
    sourceTool,
    precision,
  };
}

function dedupeEditLocations(locations: HandoffEditLocation[]): HandoffEditLocation[] {
  const seen = new Set<string>();
  return locations
    .map((location) => normalizeEditLocation(location))
    .filter((location): location is HandoffEditLocation => Boolean(location))
    .filter((location) => {
      const key = [
        location.path,
        location.startLine ?? "",
        location.endLine ?? "",
        location.summary ?? "",
        location.sourceTool ?? "",
        location.precision ?? "",
      ].join("|");
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((left, right) => {
      if (left.path !== right.path) return left.path.localeCompare(right.path);
      const leftStart = left.startLine ?? Number.MAX_SAFE_INTEGER;
      const rightStart = right.startLine ?? Number.MAX_SAFE_INTEGER;
      if (leftStart !== rightStart) return leftStart - rightStart;
      const leftEnd = left.endLine ?? Number.MAX_SAFE_INTEGER;
      const rightEnd = right.endLine ?? Number.MAX_SAFE_INTEGER;
      if (leftEnd !== rightEnd) return leftEnd - rightEnd;
      return (left.summary ?? "").localeCompare(right.summary ?? "");
    });
}

function formatEditLocation(location: HandoffEditLocation): string {
  const normalized = normalizeEditLocation(location);
  if (!normalized) return "(unknown edit)";
  const range = formatLineRange(normalized.startLine, normalized.endLine);
  const target = range ? `${normalized.path}:${range}` : normalized.path;
  const summary = normalized.summary
    ? normalized.summary
    : normalized.precision === "file"
      ? "file-level change"
      : "inspect changed block";
  return `${target} - ${summary}`;
}

function formatEditLocationsInline(
  locations: HandoffEditLocation[],
  limit = 4,
): string {
  const normalized = dedupeEditLocations(locations);
  if (normalized.length === 0) return "(none)";
  const preview = normalized.slice(0, limit).map((location) => formatEditLocation(location));
  const remaining = normalized.length - preview.length;
  return remaining > 0 ? `${preview.join("; ")}; +${remaining} more` : preview.join("; ");
}

function summarizeStructuredHandoff(
  handoff: HandoffPointer,
): string {
  const artifactText = handoff.artifactSources.length > 0
    ? `artifacts=${handoff.artifactSources.join(", ")}`
    : "";
  const queryText = handoff.artifactQueries.length > 0
    ? `queries=${handoff.artifactQueries.join(", ")}`
    : "";
  return [handoff.summary, artifactText, queryText].filter(Boolean).join(" | ");
}

function buildInspectionTargets(
  editLocations: HandoffEditLocation[],
  filesChanged: string[],
): HandoffEditLocation[] {
  const normalizedEdits = dedupeEditLocations(editLocations);
  if (normalizedEdits.length > 0) {
    return normalizedEdits;
  }
  return dedupeEditLocations(
    filesChanged.map((path) => ({
      path,
      sourceTool: "file",
      precision: "file",
      summary: "changed file (precise range unavailable)",
    })),
  );
}

function buildInspectionBullets(
  editLocations: HandoffEditLocation[],
  filesChanged: string[],
  limit = 8,
): string[] {
  const targets = buildInspectionTargets(editLocations, filesChanged);
  if (targets.length === 0) return ["(none)"];
  const bullets = [
    "Prefer one ctx_batch_execute pass to inspect these changed locations before falling back to serial read calls.",
    ...targets.slice(0, limit).map((location) => formatEditLocation(location)),
  ];
  if (targets.length > 1) {
    const previewCommands = targets.slice(0, 4).map((target, index) => {
      const label = target.path.split("/").pop() || `target-${index + 1}`;
      const command = target.startLine && target.endLine
        ? `sed -n '${target.startLine},${target.endLine}p' ${target.path}`
        : `sed -n '1,160p' ${target.path}`;
      return `{label: ${JSON.stringify(label)}, command: ${JSON.stringify(command)}}`;
    });
    const batchCmd = `ctx_batch_execute(commands: [${previewCommands.join(", ")}${targets.length > 4 ? ", ..." : ""}], queries: ["changed block", "follow-up context"])`;
    bullets.push(`Ready-to-run pattern: ${batchCmd}`);
    bullets.push("Always batch multiple inspections when they fit in one turn.");
  }
  const remaining = targets.length - Math.min(targets.length, limit);
  if (remaining > 0) {
    bullets.splice(bullets.length - 1, 0, `+${remaining} additional changed location(s)`);
  }
  return bullets;
}

function buildInspectionAppendix(
  editLocations: HandoffEditLocation[],
  filesChanged: string[],
): string {
  const bullets = buildInspectionBullets(editLocations, filesChanged).filter(
    (item) => item !== "(none)",
  );
  if (bullets.length === 0) return "";
  return `\n\n## Supervisor Follow-up\n\n### Suggested Inspection\n${bullets.map((item) => `- ${item}`).join("\n")}`;
}

function formatTaskTitle(text: string): string {
  const normalized = singleLine(text);
  return normalized.length > 72 ? `${normalized.slice(0, 69)}...` : normalized;
}

function isLikelyImplementationPrompt(prompt: string): boolean {
  const trimmed = prompt.trim();
  if (!trimmed) return false;
  if (NON_IMPLEMENTATION_PROMPT_PATTERNS.some((pattern) => pattern.test(trimmed))) {
    return IMPLEMENTATION_PROMPT_PATTERNS.some((pattern) => pattern.test(trimmed));
  }
  return IMPLEMENTATION_PROMPT_PATTERNS.some((pattern) => pattern.test(trimmed));
}

function isMutatingBashCommand(command: unknown): boolean {
  return typeof command === "string" && MUTATING_BASH_PATTERNS.some((pattern) => pattern.test(command));
}

function mergePreferredContextTools(tools: string[] | undefined): string[] | undefined {
  if (!tools || tools.length === 0) return tools;
  return [...new Set([...PREFERRED_CONTEXT_MODE_TOOLS, ...tools])];
}

function sanitizeScoutTools(tools: string[] | undefined): string[] {
  const requested = mergePreferredContextTools(tools) ?? DEFAULT_SCOUT_TOOLS;
  const sanitized = requested.filter((tool) => SCOUT_SAFE_TOOLS.has(tool));
  return sanitized.length > 0 ? [...new Set(sanitized)] : DEFAULT_SCOUT_TOOLS;
}

type ExecResult = {
  stdout: string;
  stderr: string;
  code: number | null;
  timedOut: boolean;
};

type WorkingTreeSnapshot = {
  root: string;
  files: Map<string, string>;
};

async function execCapture(
  command: string,
  args: string[],
  cwd: string,
  timeout = 30_000,
  signal?: AbortSignal,
): Promise<ExecResult> {
  return await new Promise<ExecResult>((resolvePromise) => {
    const proc = spawn(command, args, {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let settled = false;
    let timedOut = false;
    let timer: ReturnType<typeof setTimeout> | undefined;

    const finish = (code: number | null) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      resolvePromise({ stdout, stderr, code, timedOut });
    };

    if (timeout > 0) {
      timer = setTimeout(() => {
        timedOut = true;
        proc.kill("SIGTERM");
        setTimeout(() => {
          try {
            proc.kill("SIGKILL");
          } catch {
            // ignore
          }
        }, 5000);
      }, timeout);
    }

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    proc.on("close", (code) => finish(code));
    proc.on("error", (error) => {
      stderr += `${error instanceof Error ? error.message : String(error)}\n`;
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
}

function normalizePath(value: string): string {
  return value
    .replace(/\\/g, "/")
    .replace(/^\.\//, "")
    .replace(/\/+$|^\//g, "")
    .trim();
}

function normalizeComparablePath(value: string): string {
  return resolve(value)
    .replace(/\\/g, "/")
    .replace(/\/+$/, "");
}

function resolvedPathsOverlap(a: string, b: string): boolean {
  return a === b || a.startsWith(`${b}/`) || b.startsWith(`${a}/`);
}

function isBlockedDotenvPath(filePath: string): boolean {
  const name = basename(filePath);
  return (
    name === ".env" || (name.startsWith(".env.") && name !== ".env.example")
  );
}

async function getGitRepoRoot(
  cwd: string,
  signal?: AbortSignal,
): Promise<string | undefined> {
  const result = await execCapture(
    "git",
    ["rev-parse", "--show-toplevel"],
    cwd,
    5000,
    signal,
  );
  if (result.code !== 0) return undefined;
  const root = result.stdout.trim();
  return root || undefined;
}

async function listGitFiles(
  root: string,
  signal?: AbortSignal,
): Promise<string[] | undefined> {
  const result = await execCapture(
    "git",
    ["ls-files", "-co", "--exclude-standard"],
    root,
    20_000,
    signal,
  );
  if (result.code !== 0) return undefined;
  return result.stdout
    .split("\n")
    .map((line) => normalizePath(line))
    .filter(Boolean);
}

async function listFilesRecursive(
  root: string,
  current = root,
): Promise<string[]> {
  const entries = await readdir(current, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const absolutePath = join(current, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listFilesRecursive(root, absolutePath)));
      continue;
    }
    if (!entry.isFile()) continue;
    const relativePath = normalizePath(relative(root, absolutePath));
    if (!relativePath) continue;
    files.push(relativePath);
  }
  return files.sort();
}

async function hashFile(filePath: string): Promise<string> {
  const content = await readFile(filePath);
  return createHash("sha1").update(content).digest("hex");
}

type GitDirtyEntry = {
  path: string;
  status: string;
  marker?: string;
};

async function getGitDirtyEntries(
  root: string,
  signal?: AbortSignal,
): Promise<GitDirtyEntry[] | undefined> {
  const result = await execCapture(
    "git",
    ["status", "--porcelain=v1", "-z", "-uall"],
    root,
    10_000,
    signal,
  );
  if (result.code !== 0) return undefined;

  const tokens = result.stdout.split("\0").filter(Boolean);
  const entries: GitDirtyEntry[] = [];
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token.length < 4) continue;
    const status = token.slice(0, 2);
    const firstPath = normalizePath(token.slice(3));
    if (!firstPath) continue;

    const renamedOrCopied = /[RC]/.test(status);
    if (renamedOrCopied) {
      const secondPath = normalizePath(tokens[index + 1] ?? "");
      if (secondPath) {
        entries.push({
          path: secondPath,
          status,
          marker: `rename-old:${status}:${firstPath}`,
        });
        index += 1;
      }
      entries.push({
        path: firstPath,
        status,
        marker: `rename-new:${status}:${secondPath || "(unknown)"}`,
      });
      continue;
    }

    entries.push({
      path: firstPath,
      status,
    });
  }

  return entries;
}

async function snapshotWorkingTree(
  cwd: string,
  signal?: AbortSignal,
): Promise<WorkingTreeSnapshot> {
  const repoRoot = await getGitRepoRoot(cwd, signal);
  const root = repoRoot ?? cwd;
  const dirtyEntries = repoRoot ? await getGitDirtyEntries(root, signal) : undefined;
  const files = new Map<string, string>();

  if (dirtyEntries) {
    for (const entry of dirtyEntries) {
      if (!entry.path) continue;
      const relativePath = entry.path;
      if (isBlockedDotenvPath(relativePath)) {
        files.set(relativePath, `secret-file:${basename(relativePath)}`);
        continue;
      }

      const absolutePath = resolve(root, relativePath);
      try {
        const deleted = entry.status.includes("D");
        if (deleted) {
          files.set(relativePath, entry.marker ?? `deleted:${entry.status}`);
          continue;
        }
        files.set(
          relativePath,
          `${entry.marker ?? entry.status}:${await hashFile(absolutePath)}`,
        );
      } catch {
        files.set(relativePath, entry.marker ?? `missing:${entry.status}`);
      }
    }
    return { root, files };
  }

  const relativeFiles = repoRoot
    ? await listGitFiles(repoRoot, signal)
    : await listFilesRecursive(root);

  for (const relativePath of relativeFiles ?? []) {
    const absolutePath = resolve(root, relativePath);
    try {
      if (isBlockedDotenvPath(relativePath)) {
        files.set(relativePath, `secret-file:${basename(relativePath)}`);
        continue;
      }
      files.set(relativePath, await hashFile(absolutePath));
    } catch {
      // ignore unreadable or concurrently deleted files
    }
  }

  return { root, files };
}

function diffSnapshots(
  before: WorkingTreeSnapshot,
  after: WorkingTreeSnapshot,
): string[] {
  const touched = new Set<string>();
  const allFiles = new Set([...before.files.keys(), ...after.files.keys()]);
  for (const file of allFiles) {
    if (before.files.get(file) !== after.files.get(file)) {
      touched.add(file);
    }
  }
  return [...touched].sort();
}

function pathMatchesRule(filePath: string, rule: string): boolean {
  const normalizedFile = normalizePath(filePath);
  const normalizedRule = normalizePath(rule);
  if (!normalizedRule) return false;
  return (
    normalizedFile === normalizedRule ||
    normalizedFile.startsWith(`${normalizedRule}/`)
  );
}

function findBoundaryViolations(
  filesChanged: string[],
  allowedFiles: string[] | undefined,
  blockedFiles: string[] | undefined,
): string[] {
  const violations = new Set<string>();
  for (const file of filesChanged) {
    if (blockedFiles?.some((rule) => pathMatchesRule(file, rule))) {
      violations.add(`${file} (blocked)`);
      continue;
    }
    if (
      allowedFiles &&
      allowedFiles.length > 0 &&
      !allowedFiles.some((rule) => pathMatchesRule(file, rule))
    ) {
      violations.add(`${file} (outside allowedFiles)`);
    }
  }
  return [...violations].sort();
}

async function runValidationCommands(
  cwd: string,
  commands: string[] | undefined,
  signal?: AbortSignal,
): Promise<ValidationResult[]> {
  const results: ValidationResult[] = [];
  for (const command of commands ?? []) {
    const run = await execCapture(
      "bash",
      ["-lc", command],
      cwd,
      30_000,
      signal,
    );
    const combinedOutput = `${run.stdout}\n${run.stderr}`.trim();
    results.push({
      command,
      outcome: run.code === 0 && !run.timedOut ? "pass" : "fail",
      exitCode: run.code,
      note: run.timedOut
        ? "timed out"
        : combinedOutput
          ? truncate(combinedOutput.replace(/\s+/g, " "), 240)
          : run.code === 0
            ? "ok"
            : "failed",
    });
  }
  return results;
}

async function mapWithConcurrencyLimit<TInput, TOutput>(
  items: TInput[],
  concurrency: number,
  fn: (item: TInput, index: number) => Promise<TOutput>,
): Promise<TOutput[]> {
  if (items.length === 0) return [];
  const limit = Math.max(1, Math.min(concurrency, items.length));
  const results = new Array<TOutput>(items.length);
  let nextIndex = 0;

  await Promise.all(
    new Array(limit).fill(undefined).map(async () => {
      while (true) {
        const currentIndex = nextIndex;
        nextIndex += 1;
        if (currentIndex >= items.length) {
          return;
        }
        results[currentIndex] = await fn(items[currentIndex], currentIndex);
      }
    }),
  );

  return results;
}

function formatParallelLabel(
  label: string | undefined,
  objective: string,
  index: number,
): string {
  const title = formatTaskTitle(label?.trim() || objective);
  return title || `task ${index + 1}`;
}

function validateParallelWorkerTasks(
  baseCwd: string,
  tasks: ParallelDelegateTask[],
): string[] {
  const issues: string[] = [];
  const normalized = tasks.map((task, index) => {
    const taskCwd = normalizeComparablePath(
      resolve(baseCwd, task.cwd?.trim() || "."),
    );
    return {
      label: formatParallelLabel(task.label, task.objective, index),
      allowedFiles: (task.allowedFiles ?? []).map((rule) =>
        normalizeComparablePath(resolve(taskCwd, rule))
      ),
    };
  });

  for (const task of normalized) {
    if (task.allowedFiles.length === 0) {
      issues.push(
        `${task.label}: allowedFiles is required for parallel worker delegations.`,
      );
    }
  }

  for (let i = 0; i < normalized.length; i += 1) {
    for (let j = i + 1; j < normalized.length; j += 1) {
      const overlaps = normalized[i].allowedFiles.some((leftRule) =>
        normalized[j].allowedFiles.some((rightRule) =>
          resolvedPathsOverlap(leftRule, rightRule)
        )
      );
      if (overlaps) {
        issues.push(
          `${normalized[i].label} overlaps ${normalized[j].label}; parallel worker tasks must have disjoint allowedFiles.`,
        );
      }
    }
  }

  return issues;
}

function summarizeParallelWorkerStatus(
  results: ParallelDelegateTaskResult[],
): DelegateStatus {
  if (results.some((result) => result.status === "blocked")) return "blocked";
  if (results.some((result) => result.status === "escalated")) return "escalated";
  if (results.some((result) => result.status === "unknown")) return "unknown";
  return "completed";
}

type ResolvedParallelWorkerTask = {
  label: string;
  allowedFiles: string[];
  blockedFiles: string[];
};

type ParallelWorkerOwnership = {
  resolvedTasks: ResolvedParallelWorkerTask[];
  filesByTaskIndex: string[][];
  unownedFiles: string[];
};

function resolveParallelWorkerTasks(
  baseCwd: string,
  tasks: ParallelDelegateTask[],
): ResolvedParallelWorkerTask[] {
  return tasks.map((task, index) => {
    const taskCwd = normalizeComparablePath(
      resolve(baseCwd, task.cwd?.trim() || "."),
    );
    return {
      label: formatParallelLabel(task.label, task.objective, index),
      allowedFiles: (task.allowedFiles ?? []).map((rule) =>
        normalizeComparablePath(resolve(taskCwd, rule))
      ),
      blockedFiles: (task.blockedFiles ?? []).map((rule) =>
        normalizeComparablePath(resolve(taskCwd, rule))
      ),
    };
  });
}

function attributeParallelWorkerFiles(
  root: string,
  resolvedTasks: ResolvedParallelWorkerTask[],
  changedFiles: string[],
): ParallelWorkerOwnership {
  const filesByTaskIndex = resolvedTasks.map(() => [] as string[]);
  const unownedFiles: string[] = [];

  for (const file of changedFiles) {
    const absoluteFile = normalizeComparablePath(resolve(root, file));
    const ownerIndex = resolvedTasks.findIndex((task) =>
      task.allowedFiles.some((rule) => resolvedPathsOverlap(absoluteFile, rule))
    );
    if (ownerIndex >= 0) {
      filesByTaskIndex[ownerIndex].push(file);
      continue;
    }
    unownedFiles.push(file);
  }

  return {
    resolvedTasks,
    filesByTaskIndex: filesByTaskIndex.map((files) => files.sort()),
    unownedFiles: [...unownedFiles].sort(),
  };
}

function findAbsoluteBoundaryViolations(
  root: string,
  filesChanged: string[],
  task: ResolvedParallelWorkerTask,
): string[] {
  const violations = new Set<string>();
  for (const file of filesChanged) {
    const absoluteFile = normalizeComparablePath(resolve(root, file));
    if (task.blockedFiles.some((rule) => resolvedPathsOverlap(absoluteFile, rule))) {
      violations.add(`${file} (blocked)`);
      continue;
    }
    if (
      task.allowedFiles.length > 0 &&
      !task.allowedFiles.some((rule) => resolvedPathsOverlap(absoluteFile, rule))
    ) {
      violations.add(`${file} (outside allowedFiles)`);
    }
  }
  return [...violations].sort();
}

function stripSupervisorAppendix(report: string): string {
  return report.replace(/\n\n## Supervisor Checks[\s\S]*$/, "");
}

function aggregateSubagentMetrics(
  metricsList: Array<SubagentMetrics | undefined>,
): SubagentMetrics | undefined {
  const metrics = metricsList.filter(
    (item): item is SubagentMetrics => Boolean(item),
  );
  if (metrics.length === 0) return undefined;

  let costAmount = 0;
  let sawCost = false;
  let anyEstimated = false;
  let allKnownRate = true;
  let unknownModel: string | undefined;

  let throughputOutputTokens = 0;
  let throughputDurationMs = 0;
  let sawThroughput = false;
  let minTtftMs: number | undefined;

  for (const metricsItem of metrics) {
    const cost = metricsItem.cost;
    if (cost) {
      sawCost = true;
      if (typeof cost.amount === "number") {
        costAmount += cost.amount;
      }
      anyEstimated ||= cost.estimated === true;
      allKnownRate &&= cost.knownRate !== false;
      if (!unknownModel && cost.unknownModel) {
        unknownModel = cost.unknownModel;
      }
    }

    const throughput = metricsItem.throughput;
    if (throughput) {
      sawThroughput = true;
      throughputOutputTokens += throughput.outputTokens ?? 0;
      throughputDurationMs += throughput.generationDurationMs ?? 0;
      if (typeof throughput.ttftMs === "number") {
        minTtftMs = minTtftMs === undefined
          ? throughput.ttftMs
          : Math.min(minTtftMs, throughput.ttftMs);
      }
    }
  }

  const aggregated: SubagentMetrics = {};
  if (sawCost) {
    aggregated.cost = {
      amount: costAmount,
      estimated: anyEstimated,
      knownRate: allKnownRate,
      unknownModel,
    };
  }
  if (sawThroughput) {
    aggregated.throughput = {
      ttftMs: minTtftMs,
      generationDurationMs: throughputDurationMs || undefined,
      outputTokens: throughputOutputTokens,
      generationTokensPerSecond:
        throughputOutputTokens > 0 && throughputDurationMs > 0
          ? throughputOutputTokens / (throughputDurationMs / 1_000)
          : undefined,
    };
  }
  return aggregated;
}

function finalizeParallelWorkerResults(
  baseCwd: string,
  root: string,
  tasks: ParallelDelegateTask[],
  results: ParallelDelegateTaskResult[],
  changedFiles: string[],
): { results: ParallelDelegateTaskResult[]; unownedFiles: string[] } {
  const resolvedTasks = resolveParallelWorkerTasks(baseCwd, tasks);
  const ownership = attributeParallelWorkerFiles(root, resolvedTasks, changedFiles);

  const finalizedResults: ParallelDelegateTaskResult[] = results.map((result, index) => {
    const taskOwnership = ownership.resolvedTasks[index];
    const attributedFiles = ownership.filesByTaskIndex[index] ?? [];
    const taskBoundaryViolations = findAbsoluteBoundaryViolations(
      root,
      attributedFiles,
      taskOwnership,
    );
    const boundaryViolations = [
      ...taskBoundaryViolations,
      ...ownership.unownedFiles.map((file) => `${file} (outside all allowedFiles)`),
    ];
    const baseStatus = parseStatus(stripSupervisorAppendix(result.report));
    const hasValidationFailures = result.validation.some(
      (item) => item.outcome === "fail",
    );
    return {
      ...result,
      label: taskOwnership.label,
      filesChanged: attributedFiles,
      boundaryViolations,
      status: (baseStatus === "blocked" || hasValidationFailures || boundaryViolations.length > 0
        ? "blocked"
        : baseStatus) as DelegateStatus,
      report: `${stripSupervisorAppendix(result.report)}${buildSupervisorAppendix(boundaryViolations, result.validation)}`,
    };
  });

  return {
    results: finalizedResults,
    unownedFiles: ownership.unownedFiles,
  };
}

function buildWorkerFailureResult(
  label: string,
  workerModel: string,
  error: unknown,
): ParallelDelegateTaskResult {
  const message = singleLine(
    error instanceof Error ? error.message : String(error),
  ) || "Worker delegation failed before the subagent completed.";
  const report = `## Status\n- blocked\n\n## Summary\n- ${message}\n\n## Files Changed\n- (none)\n\n## Edits\n- (none)\n\n## Validation\n- (none)\n\n## Escalation\n- ${message}`;
  return {
    label,
    report: buildCompactReport(report, [], [], { kind: "worker", status: "blocked" }),
    fullReport: report,
    workerModel,
    status: "blocked",
    filesChanged: [],
    editLocations: [],
    boundaryViolations: [],
    validation: [],
    errorMessage: message,
    artifactSources: [],
    artifactQueries: [],
  };
}

function buildScoutFailureResult(
  label: string,
  scoutModel: string,
  error: unknown,
): ParallelScoutTaskResult {
  const message = singleLine(
    error instanceof Error ? error.message : String(error),
  ) || "Scout delegation failed before the subagent completed.";
  const report = `## Status\n- blocked\n\n## Summary\n- ${message}\n\n## Relevant Files\n- (none)\n\n## Findings\n- (none)\n\n## Recommended Next Step\n- ${message}`;
  return {
    label,
    status: "blocked",
    report: buildCompactReport(report, [], [], { kind: "scout", status: "blocked" }),
    fullReport: report,
    scoutModel,
    errorMessage: message,
    artifactSources: [],
    artifactQueries: [],
  };
}

function buildParallelWorkerSummary(
  results: ParallelDelegateTaskResult[],
): string {
  const completedCount = results.filter((result) => result.status === "completed").length;
  const sections = results.map((result) => {
    const passedValidation = result.validation.filter((item) => item.outcome === "pass").length;
    const failedValidation = result.validation.filter((item) => item.outcome === "fail").length;
    const lines = [
      `### ${result.label}`,
      `- status: ${result.status}`,
      `- worker: ${result.workerModel}`,
      `- files changed: ${result.filesChanged.length > 0 ? result.filesChanged.join(", ") : "(none)"}`,
      `- edit locations: ${formatEditLocationsInline(result.editLocations, 3)}`,
      `- validation: ${result.validation.length > 0 ? `${passedValidation} pass, ${failedValidation} fail` : "(none)"}`,
    ];
    if (result.boundaryViolations.length > 0) {
      lines.push(`- boundary violations: ${result.boundaryViolations.join(", ")}`);
    }
    return `${lines.join("\n")}\n\n${truncate(result.report, MAX_PARALLEL_REPORT_CHARS)}`;
  });
  return `Parallel workers: ${completedCount}/${results.length} completed\n\n${sections.join("\n\n---\n\n")}`;
}

function buildParallelScoutSummary(results: ParallelScoutTaskResult[]): string {
  const completedCount = results.filter((result) => result.status === "completed").length;
  const sections = results.map((result) => {
    const lines = [
      `### ${result.label}`,
      `- status: ${result.status}`,
      `- scout: ${result.scoutModel}`,
    ];
    return `${lines.join("\n")}\n\n${truncate(result.report, MAX_PARALLEL_REPORT_CHARS)}`;
  });
  return `Parallel scouts: ${completedCount}/${results.length} completed\n\n${sections.join("\n\n---\n\n")}`;
}

function buildSupervisorAppendix(
  boundaryViolations: string[],
  validation: ValidationResult[],
): string {
  const sections: string[] = [];
  if (boundaryViolations.length > 0) {
    sections.push(
      `### Boundary enforcement\n${boundaryViolations.map((item) => `- ${item}`).join("\n")}`,
    );
  }
  if (validation.length > 0) {
    sections.push(
      `### Validation\n${validation
        .map((item) => {
          const exitText =
            item.exitCode === null ? "signal" : String(item.exitCode);
          return `- ${item.command} - ${item.outcome} (exit ${exitText}) - ${item.note}`;
        })
        .join("\n")}`,
    );
  }
  if (sections.length === 0) return "";
  return `\n\n## Supervisor Checks\n\n${sections.join("\n\n")}`;
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
  return truncate(
    serializeConversation(convertToLlm(messages)),
    MAX_CONTEXT_CHARS,
  );
}

function formatBullets(
  items: string[] | undefined,
  emptyText = "(none)",
): string {
  if (!items || items.length === 0) return emptyText;
  return items.map((item) => `- ${item}`).join("\n");
}

function buildWorkerPrompt(
  params: DelegateParams,
  conversationContext: string,
): string {
  const hasAllowedFiles = (params.allowedFiles?.length ?? 0) > 0;
  const sections = [
    `## Objective\n${params.objective.trim()}`,
    `## Scope\n${params.scope?.trim() || "Stay within the stated task only."}`,
  ];

  if (params.artifactSources && params.artifactSources.length > 0) {
    sections.push(`## Reusable project artifacts\n${formatBullets(params.artifactSources)}\n\n- These artifacts were generated in prior sessions or steps.\n- Use ctx_search with artifactQueries or other allowed context-mode tools to reuse them without re-discovering the same data.`);
  }

  if (params.artifactQueries && params.artifactQueries.length > 0) {
    sections.push(`## Recommended artifact queries\n${formatBullets(params.artifactQueries)}`);
  }

  if (params.artifactSummary) {
    sections.push(`## Artifact summary\n${params.artifactSummary.trim()}`);
  }

  sections.push(
    `## Allowed files\n${formatBullets(params.allowedFiles, "Any file needed within scope.")}`,
    `## Blocked files\n${formatBullets(params.blockedFiles)}`,
    `## Acceptance criteria\n${formatBullets(params.acceptanceCriteria)}`,
    `## Validation commands\n${formatBullets(params.validationCommands)}`,
    `## Escalation triggers\n${formatBullets(params.escalationTriggers)}`,
    `## Recent conversation context\n${conversationContext}`,
    `## Execution rules\n- Read nearby code when needed for context.\n- Only edit files that fit the scope.\n${hasAllowedFiles ? "- If you need to change files outside the allowed set, stop and escalate.\n" : ""}- Run the provided validation commands when possible after editing.\n- Prefer a minimal patch over a broad refactor.`,
  );

  return sections.join("\n\n");
}

function buildScoutPrompt(
  params: ScoutParams,
  conversationContext: string,
): string {
  const sections = [
    `## Objective\n${params.objective.trim()}`,
    `## Scope\n${params.scope?.trim() || "Read-only reconnaissance only. Stay focused on the stated question."}`,
  ];

  if (params.artifactSources && params.artifactSources.length > 0) {
    sections.push(`## Reusable project artifacts\n${formatBullets(params.artifactSources)}\n\n- These artifacts were generated in prior sessions or steps.\n- Use ctx_search with artifactQueries or other allowed context-mode tools to reuse them without re-discovering the same data.`);
  }

  if (params.artifactQueries && params.artifactQueries.length > 0) {
    sections.push(`## Recommended artifact queries\n${formatBullets(params.artifactQueries)}`);
  }

  if (params.artifactSummary) {
    sections.push(`## Artifact summary\n${params.artifactSummary.trim()}`);
  }

  sections.push(
    `## Questions to answer\n${formatBullets(params.questions)}`,
    `## Expected outputs\n${formatBullets(params.expectedOutputs)}`,
    `## Recent conversation context\n${conversationContext}`,
    `## Execution rules\n- Use only read-only exploration.\n- Prefer path-backed findings and short evidence.\n- If the relevant answer depends on code changes, stop at recommendations rather than implementing them.`,
  );

  return sections.join("\n\n");
}

function appendSubagentEvent(
  pi: ExtensionAPI,
  payload: Record<string, unknown>,
  shouldLog?: () => boolean,
) {
  if (shouldLog && !shouldLog()) {
    return;
  }
  try {
    pi.appendEntry(SUBAGENT_EVENT_ENTRY, payload);
  } catch {
    // Observability should not break delegation.
  }
}

function classifySubagentOutcome(
  run: { exitCode: number; stopReason?: string; errorMessage?: string },
  signal?: AbortSignal,
): "completed" | "failed" | "aborted" {
  const stopReason = run.stopReason?.toLowerCase() ?? "";
  if (
    signal?.aborted ||
    stopReason.includes("abort") ||
    stopReason.includes("cancel")
  ) {
    return "aborted";
  }
  if (run.exitCode === 0 && !run.errorMessage && stopReason !== "error") {
    return "completed";
  }
  return "failed";
}

function getLatestActiveToolName(
  activeToolCalls: Map<string, WorkerToolExecution>,
): string | undefined {
  const activeTools = [...activeToolCalls.values()];
  return activeTools.length > 0 ? activeTools[activeTools.length - 1]?.toolName : undefined;
}

function compactSubagentLine(text: string, maxChars = 120): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, Math.max(1, maxChars - 1))}…`;
}

function summarizeSubagentArgs(
  toolName: string,
  args: Record<string, unknown> | undefined,
): string | undefined {
  if (!args) return undefined;
  if (typeof args.command === "string") {
    return compactSubagentLine(args.command, toolName === "bash" ? 96 : 84);
  }
  if (typeof args.path === "string") {
    return compactSubagentLine(args.path, 84);
  }
  if (typeof args.url === "string") {
    return compactSubagentLine(args.url, 84);
  }
  if (typeof args.source === "string") {
    return compactSubagentLine(args.source, 84);
  }
  if (Array.isArray(args.commands)) {
    return `${args.commands.length} commands`;
  }
  if (Array.isArray(args.queries)) {
    return `${args.queries.length} queries`;
  }
  return undefined;
}

function extractSubagentResultText(result: unknown): string | undefined {
  if (!result || typeof result !== "object") return undefined;
  const record = result as Record<string, unknown>;
  if (typeof record.error === "string") {
    return record.error;
  }
  if (Array.isArray(record.content)) {
    for (const part of record.content) {
      if (
        part &&
        typeof part === "object" &&
        (part as Record<string, unknown>).type === "text" &&
        typeof (part as Record<string, unknown>).text === "string"
      ) {
        return (part as Record<string, unknown>).text as string;
      }
    }
  }
  return undefined;
}

function buildSubagentActivityLine(
  phase: "start" | "end",
  toolName: string,
  args: Record<string, unknown> | undefined,
  result?: unknown,
  isError?: boolean,
): string {
  if (phase === "start") {
    const detail = summarizeSubagentArgs(toolName, args);
    return compactSubagentLine(detail ? `→ ${toolName} ${detail}` : `→ ${toolName}`);
  }

  const detail = compactSubagentLine(extractSubagentResultText(result) ?? "", 96);
  if (isError) {
    return compactSubagentLine(detail ? `✗ ${toolName} ${detail}` : `✗ ${toolName}`);
  }
  return compactSubagentLine(detail ? `✓ ${toolName} ${detail}` : `✓ ${toolName}`);
}

async function runWorkerSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  auth: { apiKey?: string; headers?: Record<string, string> },
  tools: string[] | undefined,
  delegationId: string,
  startDetails: Record<string, unknown>,
  pi: ExtensionAPI,
  shouldLog?: () => boolean,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
  onProgress?: (progress: SubagentProgress) => void,
): Promise<Awaited<ReturnType<typeof runSubagentProcess>> & {
  toolExecutions: WorkerToolExecution[];
}> {
  let eventIndex = 0;
  let completedTurns = 0;
  const generatedAt = Date.now();
  const workerTools = mergePreferredContextTools(tools);
  const activeToolCalls = new Map<string, WorkerToolExecution>();
  const toolExecutions: WorkerToolExecution[] = [];
  appendSubagentEvent(pi, {
    type: "subagent_process_start",
    delegationId,
    role: "worker",
    model: modelArg,
    cwd,
    generatedAt,
    ...startDetails,
    requestedTools: startDetails.tools,
    tools: workerTools,
  }, shouldLog);

  try {
    const run = await runSubagentProcess({
      cwd,
      prompt,
      modelArg,
      apiKey: auth.apiKey,
      providerName: modelArg.split("/", 1)[0],
      authHeaders: auth.headers,
      systemPrompt: WORKER_SYSTEM_PROMPT,
      extraArgs: [
        ...(workerTools && workerTools.length > 0 ? ["--tools", workerTools.join(",")] : []),
      ],
      env: {
        [WORKER_ENV_FLAG]: "worker",
      },
      signal,
      onUpdate,
      onEvent: (event) => {
        eventIndex += 1;
        appendSubagentEvent(pi, {
          type: "subagent_raw_event",
          delegationId,
          role: "worker",
          model: modelArg,
          cwd,
          eventType: typeof event?.type === "string" ? event.type : undefined,
          eventIndex,
          event,
          generatedAt: Date.now(),
        }, shouldLog);

        const toolEvent = event && typeof event === "object"
          ? event as Record<string, unknown>
          : undefined;
        if (toolEvent?.type === "turn_end") {
          completedTurns += 1;
          onProgress?.({
            turns: completedTurns,
            currentTool: undefined,
          });
        }
        const toolCallId = typeof toolEvent?.toolCallId === "string"
          ? toolEvent.toolCallId
          : undefined;
        const toolName = typeof toolEvent?.toolName === "string"
          ? toolEvent.toolName
          : undefined;
        if (toolEvent?.type === "tool_execution_start" && toolCallId && toolName) {
          activeToolCalls.set(toolCallId, {
            toolCallId,
            toolName,
            args: toolEvent.args && typeof toolEvent.args === "object"
              ? toolEvent.args as Record<string, unknown>
              : undefined,
          });
          onProgress?.({
            turns: completedTurns,
            currentTool: toolName,
            lastActivityLine: buildSubagentActivityLine(
              "start",
              toolName,
              activeToolCalls.get(toolCallId)?.args,
            ),
          });
        }
        if (toolEvent?.type === "tool_execution_end" && toolName) {
          const prior = toolCallId ? activeToolCalls.get(toolCallId) : undefined;
          toolExecutions.push({
            toolCallId,
            toolName,
            args: prior?.args,
            result: toolEvent.result,
            isError: toolEvent.isError === true,
          });
          if (toolCallId) {
            activeToolCalls.delete(toolCallId);
          }
          onProgress?.({
            turns: completedTurns,
            currentTool: getLatestActiveToolName(activeToolCalls),
            lastActivityLine: buildSubagentActivityLine(
              "end",
              toolName,
              prior?.args,
              toolEvent.result,
              toolEvent.isError === true,
            ),
          });
        }
      },
    });

    const outcome = classifySubagentOutcome(run, signal);
    appendSubagentEvent(pi, {
      type: "subagent_process_end",
      delegationId,
      role: "worker",
      model: modelArg,
      cwd,
      outcome,
      exitCode: run.exitCode,
      stopReason: run.stopReason,
      errorMessage: run.errorMessage,
      stderr: run.stderr.trim() || undefined,
      metrics: buildSubagentMetrics(run),
      generatedAt: Date.now(),
    }, shouldLog);

    return {
      ...run,
      toolExecutions,
    };
  } catch (error) {
    const details = error && typeof error === "object"
      ? error as Record<string, unknown>
      : undefined;
    appendSubagentEvent(pi, {
      type: "subagent_process_end",
      delegationId,
      role: "worker",
      model: modelArg,
      cwd,
      outcome: classifySubagentOutcome({
        exitCode: typeof details?.exitCode === "number" ? details.exitCode : 1,
        stopReason: typeof details?.stopReason === "string" ? details.stopReason : undefined,
        errorMessage: error instanceof Error ? error.message : String(error),
      }, signal),
      errorMessage: error instanceof Error ? error.message : String(error),
      exitCode: typeof details?.exitCode === "number" ? details.exitCode : undefined,
      stopReason: typeof details?.stopReason === "string" ? details.stopReason : undefined,
      stderr: typeof details?.stderr === "string" ? details.stderr : undefined,
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
}

function extractDiffRanges(diff: string): Array<{ startLine: number; endLine: number }> {
  const ranges: Array<{ startLine: number; endLine: number }> = [];
  let currentStart: number | undefined;
  let currentEnd: number | undefined;
  let sawChange = false;

  const flush = () => {
    if (sawChange && currentStart !== undefined && currentEnd !== undefined) {
      ranges.push({ startLine: currentStart, endLine: currentEnd });
    }
    currentStart = undefined;
    currentEnd = undefined;
    sawChange = false;
  };

  for (const rawLine of diff.split("\n")) {
    if (rawLine.includes("...")) {
      flush();
      continue;
    }
    const match = rawLine.match(/^([ +\-])\s*(\d+)(?:\s|$)/);
    if (!match) continue;
    if (match[1] !== "+" && match[1] !== "-") continue;
    const lineNumber = Number(match[2]);
    if (!Number.isFinite(lineNumber)) continue;
    currentStart = currentStart === undefined ? lineNumber : Math.min(currentStart, lineNumber);
    currentEnd = currentEnd === undefined ? lineNumber : Math.max(currentEnd, lineNumber);
    sawChange = true;
  }

  flush();
  return ranges;
}

function normalizeArtifactLabel(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function extractArtifactSourcesFromText(text: string): string[] {
  const sources: string[] = [];
  const patterns = [
    /Use source:\s*"([^"]+)"/g,
    /Indexed\s+\d+\s+sections(?:\s*\([^\n]+\))?\s+from:\s*([^\n]+)/g,
    /^- \[(?:new|cache)\]\s+(.+?)\s+—/gm,
  ];
  for (const pattern of patterns) {
    for (const match of text.matchAll(pattern)) {
      const label = normalizeArtifactLabel(match[1]);
      if (label) sources.push(label);
    }
  }
  return [...new Set(sources)];
}

function buildBatchArtifactSource(commands: unknown): string | undefined {
  if (!Array.isArray(commands) || commands.length === 0) return undefined;
  const labels = commands
    .flatMap((command) => {
      if (!command || typeof command !== "object") return [] as string[];
      const label = normalizeArtifactLabel((command as { label?: unknown }).label);
      return label ? [label] : [];
    });
  if (labels.length === 0) return undefined;
  return `batch:${labels.join(",").slice(0, 80)}`;
}

function extractArtifactPointers(
  execution: WorkerToolExecution,
): { sources: string[]; queries: string[] } {
  const sources: string[] = [];
  const queries: string[] = [];
  const toolName = execution.toolName;
  const args = execution.args;
  const result = execution.result && typeof execution.result === "object"
    ? execution.result as Record<string, unknown>
    : undefined;
  const resultText = extractTextContent(result);

  if (Array.isArray(args?.queries)) {
    queries.push(...args.queries.filter((q): q is string => typeof q === "string" && q.trim().length > 0));
  }

  if (toolName === "ctx_search") {
    const source = normalizeArtifactLabel(args?.source);
    if (source) sources.push(source);
  }

  if (toolName === "ctx_batch_execute") {
    const source = buildBatchArtifactSource(args?.commands);
    if (source) sources.push(source);
  }

  if (toolName === "ctx_index") {
    const source = normalizeArtifactLabel(args?.source) ?? normalizeArtifactLabel(args?.path);
    if (source) sources.push(source);
  }

  if (toolName === "ctx_fetch_and_index") {
    const directSource = normalizeArtifactLabel(args?.source);
    if (directSource) {
      sources.push(directSource);
    }
    if (Array.isArray(args?.requests)) {
      for (const request of args.requests) {
        if (!request || typeof request !== "object") continue;
        const label = normalizeArtifactLabel((request as { source?: unknown }).source);
        if (label) sources.push(label);
      }
    }
  }

  if ((toolName === "ctx_execute" || toolName === "ctx_execute_file") && args?.intent) {
    sources.push(...extractArtifactSourcesFromText(resultText));
  }

  if (toolName === "ctx_index" || toolName === "ctx_fetch_and_index") {
    sources.push(...extractArtifactSourcesFromText(resultText));
  }

  return {
    sources: [...new Set(sources)],
    queries: [...new Set(queries.map((query) => query.trim()).filter(Boolean))],
  };
}

async function readFileLineCount(
  root: string,
  filePath: string,
): Promise<number | undefined> {
  try {
    const content = await readFile(resolve(root, filePath), "utf8");
    return countLines(content);
  } catch {
    return undefined;
  }
}

async function deriveEditLocations(
  root: string,
  toolExecutions: WorkerToolExecution[],
  filesChanged: string[],
): Promise<{ editLocations: HandoffEditLocation[]; artifactSources: string[]; artifactQueries: string[] }> {
  const locations: HandoffEditLocation[] = [];
  const artifactSources: string[] = [];
  const artifactQueries: string[] = [];

  for (const execution of toolExecutions) {
    if (execution.isError) continue;
    const toolName = execution.toolName;
    const artifactPointers = extractArtifactPointers(execution);
    artifactSources.push(...artifactPointers.sources);
    artifactQueries.push(...artifactPointers.queries);

    const path = typeof execution.args?.path === "string"
      ? normalizeRepoPath(root, execution.args.path)
      : "";
    if (!path) continue;

    if (toolName === "edit") {
      const result = execution.result && typeof execution.result === "object"
        ? execution.result as Record<string, unknown>
        : undefined;
      const details = result?.details && typeof result.details === "object"
        ? result.details as Record<string, unknown>
        : undefined;
      const diff = typeof details?.diff === "string" ? details.diff : "";
      const ranges = diff ? extractDiffRanges(diff) : [];
      if (ranges.length > 0) {
        locations.push(
          ...ranges.map((range) => ({
            path,
            startLine: range.startLine,
            endLine: range.endLine,
            summary: "inspect changed block",
            sourceTool: "edit" as const,
            precision: "range" as const,
          })),
        );
        continue;
      }
    }

    if (toolName === "write") {
      const content = typeof execution.args?.content === "string"
        ? execution.args.content
        : undefined;
      const lineCount = content ? countLines(content) : await readFileLineCount(root, path);
      locations.push({
        path,
        startLine: lineCount ? 1 : undefined,
        endLine: lineCount,
        summary: "inspect rewritten file",
        sourceTool: "write",
        precision: lineCount ? "range" : "file",
      });
      continue;
    }
  }

  const coveredFiles = new Set(locations.map((location) => location.path));
  for (const file of filesChanged
    .map((item) => normalizeRepoPath(root, item))
    .filter((item) => item && !isIncidentalHandoffPath(item))) {
    if (coveredFiles.has(file)) continue;
    const lineCount = await readFileLineCount(root, file);
    locations.push({
      path: file,
      startLine: lineCount ? 1 : undefined,
      endLine: lineCount,
      summary: lineCount
        ? "changed file (precise range unavailable)"
        : "changed file (unreadable or deleted after worker run)",
      sourceTool: "file",
      precision: lineCount ? "range" : "file",
    });
  }

  return {
    editLocations: dedupeEditLocations(locations),
    artifactSources: [...new Set(artifactSources)].sort(),
    artifactQueries: [...new Set(artifactQueries)].sort(),
  };
}

async function runScoutSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  auth: { apiKey?: string; headers?: Record<string, string> },
  tools: string[] | undefined,
  delegationId: string,
  startDetails: Record<string, unknown>,
  pi: ExtensionAPI,
  shouldLog?: () => boolean,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
  onProgress?: (progress: SubagentProgress) => void,
): Promise<Awaited<ReturnType<typeof runSubagentProcess>> & {
  toolExecutions: WorkerToolExecution[];
}> {
  const scoutTools = sanitizeScoutTools(tools);
  let eventIndex = 0;
  let completedTurns = 0;
  const generatedAt = Date.now();
  const activeToolCalls = new Map<string, WorkerToolExecution>();
  const toolExecutions: WorkerToolExecution[] = [];
  appendSubagentEvent(pi, {
    type: "subagent_process_start",
    delegationId,
    role: "scout",
    model: modelArg,
    cwd,
    generatedAt,
    ...startDetails,
    requestedTools: startDetails.tools,
    tools: scoutTools,
  }, shouldLog);

  try {
    const run = await runSubagentProcess({
      cwd,
      prompt,
      modelArg,
      apiKey: auth.apiKey,
      providerName: modelArg.split("/", 1)[0],
      authHeaders: auth.headers,
      systemPrompt: SCOUT_SYSTEM_PROMPT,
      extraArgs: ["--tools", scoutTools.join(",")],
      env: {
        [WORKER_ENV_FLAG]: "scout",
      },
      signal,
      onUpdate,
      onEvent: (event) => {
        eventIndex += 1;
        appendSubagentEvent(pi, {
          type: "subagent_raw_event",
          delegationId,
          role: "scout",
          model: modelArg,
          cwd,
          eventType: typeof event?.type === "string" ? event.type : undefined,
          eventIndex,
          event,
          generatedAt: Date.now(),
        }, shouldLog);

        const toolEvent = event && typeof event === "object"
          ? event as Record<string, unknown>
          : undefined;
        if (toolEvent?.type === "turn_end") {
          completedTurns += 1;
          onProgress?.({
            turns: completedTurns,
            currentTool: undefined,
          });
        }
        const toolCallId = typeof toolEvent?.toolCallId === "string"
          ? toolEvent.toolCallId
          : undefined;
        const toolName = typeof toolEvent?.toolName === "string"
          ? toolEvent.toolName
          : undefined;
        if (toolEvent?.type === "tool_execution_start" && toolCallId && toolName) {
          activeToolCalls.set(toolCallId, {
            toolCallId,
            toolName,
            args: toolEvent.args && typeof toolEvent.args === "object"
              ? toolEvent.args as Record<string, unknown>
              : undefined,
          });
          onProgress?.({
            turns: completedTurns,
            currentTool: toolName,
            lastActivityLine: buildSubagentActivityLine(
              "start",
              toolName,
              activeToolCalls.get(toolCallId)?.args,
            ),
          });
        }
        if (toolEvent?.type === "tool_execution_end" && toolName) {
          const prior = toolCallId ? activeToolCalls.get(toolCallId) : undefined;
          toolExecutions.push({
            toolCallId,
            toolName,
            args: prior?.args,
            result: toolEvent.result,
            isError: toolEvent.isError === true,
          });
          if (toolCallId) {
            activeToolCalls.delete(toolCallId);
          }
          onProgress?.({
            turns: completedTurns,
            currentTool: getLatestActiveToolName(activeToolCalls),
            lastActivityLine: buildSubagentActivityLine(
              "end",
              toolName,
              prior?.args,
              toolEvent.result,
              toolEvent.isError === true,
            ),
          });
        }
      },
    });

    const outcome = classifySubagentOutcome(run, signal);
    appendSubagentEvent(pi, {
      type: "subagent_process_end",
      delegationId,
      role: "scout",
      model: modelArg,
      cwd,
      outcome,
      exitCode: run.exitCode,
      stopReason: run.stopReason,
      errorMessage: run.errorMessage,
      stderr: run.stderr.trim() || undefined,
      metrics: buildSubagentMetrics(run),
      generatedAt: Date.now(),
    }, shouldLog);

    return {
      ...run,
      toolExecutions,
    };
  } catch (error) {
    const details = error && typeof error === "object"
      ? error as Record<string, unknown>
      : undefined;
    appendSubagentEvent(pi, {
      type: "subagent_process_end",
      delegationId,
      role: "scout",
      model: modelArg,
      cwd,
      outcome: classifySubagentOutcome({
        exitCode: typeof details?.exitCode === "number" ? details.exitCode : 1,
        stopReason: typeof details?.stopReason === "string" ? details.stopReason : undefined,
        errorMessage: error instanceof Error ? error.message : String(error),
      }, signal),
      errorMessage: error instanceof Error ? error.message : String(error),
      exitCode: typeof details?.exitCode === "number" ? details.exitCode : undefined,
      stopReason: typeof details?.stopReason === "string" ? details.stopReason : undefined,
      stderr: typeof details?.stderr === "string" ? details.stderr : undefined,
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
}

function parseSectionItems(report: string, heading: string): string[] {
  const regex = new RegExp(`## ${heading}\\s*\\n([\\s\\S]*?)(?=\\n## |$)`, "i");
  const match = report.match(regex);
  if (!match) return [];
  return match[1]
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- "))
    .map((line) => line.replace(/^-\s+/, "").trim())
    .filter((line) => line && line.toLowerCase() !== "(none)");
}

function parseStatus(report: string): DelegateStatus {
  const [first] = parseSectionItems(report, "Status");
  const normalized = (first ?? "").toLowerCase();
  if (normalized.includes("completed")) return "completed";
  if (normalized.includes("escalated")) return "escalated";
  if (normalized.includes("blocked")) return "blocked";
  return "unknown";
}

function parseReviewVerdict(report: string): string {
  return parseSectionItems(report, "Verdict")[0] ?? "review complete";
}

function parseSummaryLikeItems(report: string): string[] {
  return [
    ...parseSectionItems(report, "Summary"),
    ...parseSectionItems(report, "Findings"),
  ];
}

function extractTextContent(content: unknown): string {
  if (typeof content === "string") {
    return content.trim();
  }

  if (Array.isArray(content)) {
    return content
      .map((item) => extractTextContent(item))
      .filter(Boolean)
      .join("\n")
      .trim();
  }

  if (content && typeof content === "object") {
    if ("text" in content && typeof (content as { text?: unknown }).text === "string") {
      return (content as { text: string }).text.trim();
    }
    if ("role" in content && "content" in content) {
      return textFromMessage(content as AgentMessage).trim();
    }
    if ("content" in content) {
      return extractTextContent((content as { content?: unknown }).content);
    }
  }

  return "";
}

function summarizeHandoff(
  toolName: string,
  report: string,
  details: Record<string, unknown>,
): string {
  if (toolName === "review_changes") {
    const verdict = parseReviewVerdict(report);
    const findings = parseSectionItems(report, "Findings").slice(0, 1);
    return truncate(
      [verdict, ...findings].map((item) => singleLine(item)).join(" | "),
      240,
    );
  }

  const explicitSummary = parseSummaryLikeItems(report).slice(0, 2);
  if (explicitSummary.length > 0) {
    return truncate(
      explicitSummary.map((item) => singleLine(item)).join(" | "),
      240,
    );
  }

  const editLocations = collectHandoffEditLocations(details);
  if (editLocations.length > 0) {
    return truncate(
      `Edited ${formatEditLocationsInline(editLocations, 1)}`,
      240,
    );
  }

  const status = typeof details.status === "string" ? details.status : "completed";
  return truncate(singleLine(`${toolName} ${status}`), 240);
}

function inferHandoffTitle(
  toolName: string,
  input: Record<string, unknown>,
  details: Record<string, unknown>,
): string {
  if (typeof input.objective === "string" && input.objective.trim()) {
    return formatTaskTitle(input.objective);
  }
  if (typeof input.context === "string" && input.context.trim()) {
    return formatTaskTitle(input.context);
  }
  if (typeof input.focus === "string" && input.focus.trim()) {
    return formatTaskTitle(`Review: ${input.focus}`);
  }
  const completedCount =
    typeof details.completedCount === "number" ? details.completedCount : undefined;
  const totalCount =
    typeof details.totalCount === "number" ? details.totalCount : undefined;
  if (completedCount !== undefined && totalCount !== undefined) {
    return `${toolName} ${completedCount}/${totalCount}`;
  }
  return toolName;
}

function inferHandoffStatus(
  toolName: string,
  report: string,
  details: Record<string, unknown>,
): string {
  if (typeof details.status === "string" && details.status.trim()) {
    return details.status;
  }
  if (toolName === "review_changes") {
    return "completed";
  }
  return parseStatus(report);
}

function parseDetailEditLocations(value: unknown): HandoffEditLocation[] {
  if (!Array.isArray(value)) return [];
  return dedupeEditLocations(
    value.flatMap((item) => {
      if (!item || typeof item !== "object") return [] as HandoffEditLocation[];
      const location = item as Record<string, unknown>;
      if (typeof location.path !== "string") return [] as HandoffEditLocation[];
      return [{
        path: location.path,
        startLine: typeof location.startLine === "number" ? location.startLine : undefined,
        endLine: typeof location.endLine === "number" ? location.endLine : undefined,
        summary: typeof location.summary === "string" ? location.summary : undefined,
        sourceTool: location.sourceTool === "edit" || location.sourceTool === "write" || location.sourceTool === "file"
          ? location.sourceTool
          : undefined,
        precision: location.precision === "range" || location.precision === "file"
          ? location.precision
          : undefined,
      }];
    }),
  );
}

function collectHandoffEditLocations(details: Record<string, unknown>): HandoffEditLocation[] {
  const directLocations = parseDetailEditLocations(details.editLocations);
  const nestedLocations = Array.isArray(details.results)
    ? details.results.flatMap((result) => {
      if (!result || typeof result !== "object") return [] as HandoffEditLocation[];
      return parseDetailEditLocations((result as { editLocations?: unknown }).editLocations);
    })
    : [];
  return dedupeEditLocations([...directLocations, ...nestedLocations]);
}

function collectHandoffFiles(details: Record<string, unknown>): string[] {
  const directFiles = Array.isArray(details.filesChanged)
    ? details.filesChanged.filter((item): item is string => typeof item === "string")
    : [];
  const nestedFiles = Array.isArray(details.results)
    ? details.results.flatMap((result) => {
      if (!result || typeof result !== "object") return [] as string[];
      const filesChanged = (result as { filesChanged?: unknown }).filesChanged;
      return Array.isArray(filesChanged)
        ? filesChanged.filter((item): item is string => typeof item === "string")
        : [];
    })
    : [];
  const normalizedFiles = [...new Set([...directFiles, ...nestedFiles]
    .map((item) => normalizePath(item))
    .filter((item) => item && !isIncidentalHandoffPath(item)))].sort();
  if (normalizedFiles.length > 0) {
    return normalizedFiles;
  }
  return [...new Set(collectHandoffEditLocations(details).map((location) => location.path))].sort();
}

function buildHandoffSource(
  toolName: string,
  sessionKey: string,
  generatedAt: number,
  title: string,
): string {
  const hash = createHash("sha1")
    .update([toolName, sessionKey, String(generatedAt), title].join("\n"))
    .digest("hex")
    .slice(0, 12);
  return `${HANDOFF_SOURCE_PREFIX}:${toolName}:${hash}`;
}

function collectHandoffArtifacts(details: Record<string, unknown>): {
  sources: string[];
  queries: string[];
  summary?: string;
} {
  const directSources = Array.isArray(details.artifactSources)
    ? details.artifactSources.filter((item): item is string => typeof item === "string")
    : [];
  const directQueries = Array.isArray(details.artifactQueries)
    ? details.artifactQueries.filter((item): item is string => typeof item === "string")
    : [];
  const directSummary = typeof details.artifactSummary === "string" && details.artifactSummary.trim()
    ? details.artifactSummary.trim()
    : undefined;

  const nestedSources = Array.isArray(details.results)
    ? details.results.flatMap((result) => {
      if (!result || typeof result !== "object") return [] as string[];
      const sources = (result as { artifactSources?: unknown }).artifactSources;
      return Array.isArray(sources)
        ? sources.filter((item): item is string => typeof item === "string")
        : [];
    })
    : [];

  const nestedQueries = Array.isArray(details.results)
    ? details.results.flatMap((result) => {
      if (!result || typeof result !== "object") return [] as string[];
      const queries = (result as { artifactQueries?: unknown }).artifactQueries;
      return Array.isArray(queries)
        ? queries.filter((item): item is string => typeof item === "string")
        : [];
    })
    : [];

  const nestedSummaries = Array.isArray(details.results)
    ? details.results.flatMap((result) => {
      if (!result || typeof result !== "object") return [] as string[];
      const summary = (result as { artifactSummary?: unknown }).artifactSummary;
      return typeof summary === "string" && summary.trim() ? [summary.trim()] : [];
    })
    : [];

  return {
    sources: [...new Set([...directSources, ...nestedSources].map((item) => item.trim()).filter(Boolean))].sort(),
    queries: [...new Set([...directQueries, ...nestedQueries].map((item) => item.trim()).filter(Boolean))].sort(),
    summary: directSummary ?? (nestedSummaries.length > 0 ? nestedSummaries.join(" | ") : undefined),
  };
}

function buildHandoffMarkdown(input: {
  source: string;
  toolName: string;
  title: string;
  status: string;
  sessionKey: string;
  generatedAt: number;
  summary: string;
  filesChanged: string[];
  editLocations: HandoffEditLocation[];
  artifactSources: string[];
  artifactQueries: string[];
  artifactSummary?: string;
  modelLabel?: string;
  promptInput: Record<string, unknown>;
  details: Record<string, unknown>;
  report: string;
}): string {
  const lines = [
    `# Subagent handoff`,
    "",
    `- Source: ${input.source}`,
    `- Tool: ${input.toolName}`,
    `- Title: ${input.title}`,
    `- Status: ${input.status}`,
    `- Generated at: ${new Date(input.generatedAt).toISOString()}`,
    `- Session: ${input.sessionKey}`,
    ...(input.modelLabel ? [`- Model: ${input.modelLabel}`] : []),
    ...(input.artifactSources.length > 0
      ? [`- Artifact sources: ${input.artifactSources.join(", ")}`]
      : []),
    ...(input.artifactQueries.length > 0
      ? [`- Artifact queries: ${input.artifactQueries.join(", ")}`]
      : []),
    "",
    `## Summary`,
    input.summary || "(none)",
  ];

  if (input.artifactSummary) {
    lines.push("", "## Artifact Summary", input.artifactSummary);
  }

  if (typeof input.promptInput.objective === "string" && input.promptInput.objective.trim()) {
    lines.push("", "## Objective", input.promptInput.objective.trim());
  }
  if (typeof input.promptInput.scope === "string" && input.promptInput.scope.trim()) {
    lines.push("", "## Scope", input.promptInput.scope.trim());
  }
  if (Array.isArray(input.promptInput.acceptanceCriteria)) {
    const acceptanceCriteria = input.promptInput.acceptanceCriteria
      .filter((item): item is string => typeof item === "string" && item.trim().length > 0)
      .map((item) => `- ${item.trim()}`);
    if (acceptanceCriteria.length > 0) {
      lines.push("", "## Acceptance Criteria", ...acceptanceCriteria);
    }
  }
  if (typeof input.promptInput.context === "string" && input.promptInput.context.trim()) {
    lines.push("", "## Review Context", input.promptInput.context.trim());
  }
  if (typeof input.promptInput.focus === "string" && input.promptInput.focus.trim()) {
    lines.push("", "## Review Focus", input.promptInput.focus.trim());
  }
  if (input.editLocations.length > 0 && !input.report.trim()) {
    lines.push(
      "",
      "## Edit Locations",
      ...input.editLocations.map((location) => `- ${formatEditLocation(location)}`),
    );
    lines.push(
      "",
      "## Suggested Inspection",
      ...buildInspectionBullets(input.editLocations, input.filesChanged).map((item) => `- ${item}`),
    );
  }
  if (Array.isArray(input.details.validation)) {
    const validationLines = input.details.validation
      .filter((item): item is ValidationResult => Boolean(item) && typeof item === "object")
      .map((item) => {
        const exitText = item.exitCode === null ? "signal" : String(item.exitCode);
        return `- ${item.command} - ${item.outcome} (exit ${exitText}) - ${item.note}`;
      });
    if (validationLines.length > 0) {
      lines.push("", "## Validation", ...validationLines);
    }
  }
  if (input.report.trim()) {
    lines.push("", "## Full Report", input.report.trim());
  }

  return lines.join("\n");
}

type SharedContentStore = {
  index(options: {
    content?: string;
    path?: string;
    source?: string;
    attribution?: { sessionId?: string; eventId?: string };
  }): { label: string; totalChunks: number; codeChunks: number };
  searchWithFallback(
    query: string,
    limit?: number,
    source?: string,
    contentType?: "code" | "prose",
    sourceMatchMode?: "like" | "exact",
  ): Array<{ title: string; content: string; highlighted?: string; source?: string }>;
  close(): void;
};

const extensionRequire = createRequire(import.meta.url);

function resolveContextModeBuildRoot(): string {
  const configDir = process.env.PI_CONFIG_DIR?.trim() || join(homedir(), ".pi");
  const candidates = [
    (() => {
      try {
        return extensionRequire.resolve("context-mode/cli");
      } catch {
        return undefined;
      }
    })(),
    join(configDir, "agent", "npm", "node_modules", "context-mode"),
  ].filter((value): value is string => Boolean(value));

  for (const candidate of candidates) {
    const probeRoots = [candidate, resolve(candidate, "..")];
    for (const probeRoot of probeRoots) {
      if (existsSync(join(probeRoot, "store.js"))) {
        return probeRoot;
      }
      const buildRoot = join(probeRoot, "build");
      if (existsSync(join(buildRoot, "store.js"))) {
        return buildRoot;
      }
    }
  }

  throw new Error("Unable to resolve the installed context-mode build path.");
}

let contextModeModulesPromise:
  | Promise<{
      ContentStore: new (dbPath?: string) => SharedContentStore;
      resolveContentStorageDir: (getDefaultDir: () => string) => {
        path: string;
      };
      ensureWritableStorageDir: (dir: { path: string }) => string;
      resolveDefaultSessionDir: (opts: {
        configDir: string;
        configDirEnv?: string;
        legacySessionDirEnv?: string;
        env?: NodeJS.ProcessEnv;
      }) => string;
      resolveContentStorePath: (opts: {
        projectDir: string;
        contentDir: string;
      }) => string;
      resolvePiWorkspaceDir: (opts: {
        env: Record<string, string | undefined>;
        pwd: string | undefined;
        cwd: string;
        home?: string;
      }) => string;
    }>
  | undefined;
let cachedHandoffStore:
  | {
      dbPath: string;
      store: SharedContentStore;
    }
  | undefined;

async function loadContextModeModules() {
  if (!contextModeModulesPromise) {
    contextModeModulesPromise = (async () => {
      try {
        const root = resolveContextModeBuildRoot();
        const [{ ContentStore }, sessionDbModule, piAdapterModule] = await Promise.all([
          import(pathToFileURL(join(root, "store.js")).href),
          import(pathToFileURL(join(root, "session", "db.js")).href),
          import(pathToFileURL(join(root, "adapters", "pi", "extension.js")).href),
        ]);

        return {
          ContentStore,
          resolveContentStorageDir: sessionDbModule.resolveContentStorageDir,
          ensureWritableStorageDir: sessionDbModule.ensureWritableStorageDir,
          resolveDefaultSessionDir: sessionDbModule.resolveDefaultSessionDir,
          resolveContentStorePath: sessionDbModule.resolveContentStorePath,
          resolvePiWorkspaceDir: piAdapterModule.resolvePiWorkspaceDir,
        };
      } catch (error) {
        contextModeModulesPromise = undefined;
        throw error;
      }
    })();
  }

  return await contextModeModulesPromise;
}

async function getOrCreateHandoffStore(ctx: ExtensionContext) {
  const modules = await loadContextModeModules();
  const projectDir = modules.resolvePiWorkspaceDir({
    env: process.env,
    pwd: ctx.cwd,
    cwd: ctx.cwd,
    home: homedir(),
  });
  const defaultSessionDir = modules.resolveDefaultSessionDir({
    configDir: process.env.PI_CONFIG_DIR?.trim() || join(homedir(), ".pi"),
    configDirEnv: "PI_CONFIG_DIR",
    env: process.env,
  });
  const contentDir = modules.ensureWritableStorageDir(
    modules.resolveContentStorageDir(() => defaultSessionDir),
  );
  await mkdir(contentDir, { recursive: true });
  const dbPath = modules.resolveContentStorePath({ projectDir, contentDir });
  if (!cachedHandoffStore || cachedHandoffStore.dbPath !== dbPath) {
    cachedHandoffStore?.store.close();
    cachedHandoffStore = {
      dbPath,
      store: new modules.ContentStore(dbPath),
    };
  }
  return cachedHandoffStore.store;
}

async function indexHandoff(
  ctx: ExtensionContext,
  pointer: HandoffPointer,
  markdown: string,
): Promise<boolean> {
  try {
    const store = await getOrCreateHandoffStore(ctx);
    store.index({ content: markdown, source: pointer.source });
    return true;
  } catch {
    return false;
  }
}

function readRecentHandoffPointers(ctx: ExtensionContext): HandoffPointer[] {
  const pointers: HandoffPointer[] = [];
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type !== "custom" || entry.customType !== HANDOFF_ENTRY) continue;
    const data = (entry as { data?: Partial<HandoffPointer> }).data;
    if (!data?.source) continue;
    pointers.push({
      source: data.source,
      toolName: data.toolName ?? "unknown",
      title: data.title ?? data.toolName ?? "handoff",
      status: data.status ?? "unknown",
      generatedAt: typeof data.generatedAt === "number" ? data.generatedAt : 0,
      summary: data.summary ?? "",
      filesChanged: Array.isArray(data.filesChanged)
        ? data.filesChanged.filter((item): item is string => typeof item === "string")
        : [],
      editLocations: Array.isArray(data.editLocations)
        ? parseDetailEditLocations(data.editLocations)
        : [],
      artifactSources: Array.isArray(data.artifactSources)
        ? data.artifactSources.filter((item): item is string => typeof item === "string")
        : [],
      artifactQueries: Array.isArray(data.artifactQueries)
        ? data.artifactQueries.filter((item): item is string => typeof item === "string")
        : [],
      artifactSummary: data.artifactSummary,
      indexed: data.indexed,
    });
  }
  return pointers
    .reverse()
    .filter((item, index, all) =>
      index === all.findIndex((candidate) => candidate.source === item.source)
    );
}

function inferDelegationArtifacts(
  ctx: ExtensionContext,
  prompt: string,
): {
  artifactSources?: string[];
  artifactQueries?: string[];
  artifactSummary?: string;
} {
  const normalizedPrompt = singleLine(prompt);
  if (!normalizedPrompt) return {};

  const candidates = readRecentHandoffPointers(ctx)
    .filter((handoff) => handoff.toolName !== "review_changes")
    .filter((handoff) => handoff.artifactSources.length > 0 || handoff.artifactQueries.length > 0)
    .map((handoff) => ({
      handoff,
      score: scoreHandoffRelevance(normalizedPrompt, handoff),
    }))
    .filter((item) => item.score > 0)
    .sort((left, right) => right.score - left.score)
    .slice(0, 3)
    .map((item) => item.handoff);

  if (candidates.length === 0) return {};

  const artifactSources = [...new Set(candidates.flatMap((handoff) => handoff.artifactSources))].slice(0, 6);
  const artifactQueries = [...new Set(candidates.flatMap((handoff) => handoff.artifactQueries))].slice(0, 6);
  const artifactSummary = truncate(
    candidates
      .slice(0, 2)
      .map((handoff) => `${handoff.title}: ${summarizeStructuredHandoff(handoff)}`)
      .join(" | "),
    320,
  );

  return {
    artifactSources: artifactSources.length > 0 ? artifactSources : undefined,
    artifactQueries: artifactQueries.length > 0 ? artifactQueries : undefined,
    artifactSummary: artifactSummary || undefined,
  };
}

function withInferredArtifacts<T extends DelegateParams | ScoutParams>(
  ctx: ExtensionContext,
  params: T,
  promptText: string,
): T {
  if (
    (params.artifactSources?.length ?? 0) > 0 ||
    (params.artifactQueries?.length ?? 0) > 0 ||
    (params.artifactSummary?.trim().length ?? 0) > 0
  ) {
    return params;
  }

  const inferred = inferDelegationArtifacts(ctx, promptText);
  if (!inferred.artifactSources && !inferred.artifactQueries && !inferred.artifactSummary) {
    return params;
  }

  return {
    ...params,
    artifactSources: inferred.artifactSources,
    artifactQueries: inferred.artifactQueries,
    artifactSummary: inferred.artifactSummary,
  };
}

async function buildRecentHandoffPrompt(
  ctx: ExtensionContext,
  prompt: string,
): Promise<string> {
  const rawSessionHandoffs = readRecentHandoffPointers(ctx).filter(
    (handoff) => handoff.toolName !== "review_changes",
  );
  const scoredSessionHandoffs = prompt.trim()
    ? rawSessionHandoffs
        .map((handoff) => ({ handoff, score: scoreHandoffRelevance(prompt, handoff) }))
        .filter((item) => item.score > 0)
        .sort((left, right) => right.score - left.score)
        .map((item) => item.handoff)
    : rawSessionHandoffs;
  const sessionHandoffs = [
    ...rawSessionHandoffs.slice(0, 1),
    ...scoredSessionHandoffs,
  ]
    .filter(
      (handoff, index, all) =>
        index === all.findIndex((candidate) => candidate.source === handoff.source),
    )
    .slice(0, MAX_RECENT_HANDOFFS);
  const store = await getOrCreateHandoffStore(ctx).catch(() => undefined);
  const handoffs = [...sessionHandoffs];

  if (store && handoffs.length < MAX_RECENT_HANDOFFS && prompt.trim()) {
    try {
      const knownSources = new Set(handoffs.map((handoff) => handoff.source));
      const extraMatches = store.searchWithFallback(
        truncate(singleLine(prompt), 240),
        MAX_RECENT_HANDOFFS * 3,
        `${HANDOFF_SOURCE_PREFIX}:`,
        undefined,
        "like",
      );

      for (const match of extraMatches) {
        const source = typeof match.source === "string" ? match.source : "";
        if (!source || knownSources.has(source)) continue;
        const [, toolName = "indexed handoff"] = source.split(":");
        if (toolName === "review_changes") continue;
        knownSources.add(source);
        handoffs.push({
          source,
          toolName,
          title: match.title || "Relevant prior handoff",
          status: "indexed",
          generatedAt: 0,
          summary: singleLine(match.highlighted || match.content || "") ||
            "Relevant indexed handoff from another session in this project.",
          filesChanged: [],
          editLocations: [],
          artifactSources: [],
          artifactQueries: [],
          indexed: true,
        });
        if (handoffs.length >= MAX_RECENT_HANDOFFS) break;
      }
    } catch {
      // Fall back to current-session handoffs only.
    }
  }

  if (handoffs.length === 0) return "";

  const freshSessionSources = new Set(sessionHandoffs.slice(0, 2).map((handoff) => handoff.source));
  const sections: string[] = [];
  for (const handoff of handoffs) {
    const isFreshCurrentHandoff = handoff.generatedAt > 0 && freshSessionSources.has(handoff.source);
    let detail = handoff.summary;
    if (store && !isFreshCurrentHandoff) {
      try {
        const matches = store.searchWithFallback(
          "summary findings validation artifact sources artifact queries artifact summary reusable project artifacts",
          3,
          handoff.source,
          undefined,
          "exact",
        );
        if (matches.length > 0) {
          detail = truncate(
            matches
              .map((match) => {
                const snippet = singleLine(match.highlighted || match.content || "");
                return snippet ? `${match.title}: ${snippet}` : match.title;
              })
              .join(" | "),
            320,
          );
        }
      } catch {
        // Fall back to the session-persisted summary.
      }
    }

    const lines = [
      `### ${handoff.toolName} — ${handoff.title}`,
      `- status: ${handoff.status}`,
      `- source: ${handoff.source}`,
    ];
    if (handoff.artifactSources.length > 0) {
      lines.push(`- artifacts: ${handoff.artifactSources.join(", ")}`);
    }
    if (handoff.artifactQueries.length > 0) {
      lines.push(`- artifact queries: ${handoff.artifactQueries.join(", ")}`);
    }
    if (isFreshCurrentHandoff) {
      lines.push("- summary: already visible in recent tool history; reuse the structured handoff source if needed.");
    } else {
      lines.push(`- summary: ${detail || "(none)"}`);
    }
    sections.push(lines.join("\n"));
  }

  const anyIndexed = handoffs.some((handoff) => handoff.indexed);

  return truncate(
    [
      "## Recent Delegated Handoffs",
      "",
      anyIndexed
        ? "- Relevant delegate/review results for this prompt have been indexed into the shared context-mode store for this project."
        : "- Relevant delegate/review results for this prompt are available below as session-local summaries.",
      "- Treat successful bounded worker handoffs with passing validation and no boundary violations as trusted by default.",
      anyIndexed
        ? "- Reuse these handoffs before re-discovering the same context; when you need more detail, query the indexed source labels listed below."
        : "- Reuse these handoffs before re-discovering the same context; rely on the summaries below when store-backed retrieval is unavailable.",
      "",
      ...sections,
    ].join("\n"),
    MAX_HANDOFF_PROMPT_CHARS,
  );
}

function workingTreeSignature(snapshot: WorkingTreeSnapshot): string {
  const hash = createHash("sha1");
  hash.update(`${snapshot.root}\n`);
  for (const [file, digest] of [...snapshot.files.entries()].sort(([left], [right]) =>
    left.localeCompare(right)
  )) {
    hash.update(`${file}:${digest}\n`);
  }
  return hash.digest("hex");
}

function userExplicitlyAskedForReview(prompt: string): boolean {
  return (
    /\b(review|audit|code review)\b/i.test(prompt) ||
    /\b(final pass|look over|sanity check|second opinion)\b/i.test(prompt) ||
    /\b(check|inspect)\b.{0,24}\b(changes|diff|code|implementation|patch|work)\b/i.test(prompt)
  );
}

function buildReviewDedupeKey(
  signature: string,
  input: Record<string, unknown>,
): string {
  const context =
    typeof input.context === "string" ? singleLine(input.context).toLowerCase() : "";
  const focus =
    typeof input.focus === "string" ? singleLine(input.focus).toLowerCase() : "";
  const stage = typeof input.stage === "string" ? input.stage.toLowerCase() : "final";
  return `${signature}::${context}::${focus}::${stage}`;
}

function tokenizeHandoffText(text: string): string[] {
  return singleLine(text)
    .toLowerCase()
    .split(/[^a-z0-9_./:-]+/)
    .filter(
      (token) =>
        token.length >= 4 && !HANDOFF_RELEVANCE_STOP_WORDS.has(token),
    );
}

function scoreHandoffRelevance(prompt: string, handoff: HandoffPointer): number {
  const promptTokens = new Set(tokenizeHandoffText(prompt));
  if (promptTokens.size === 0) return 0;
  const handoffText = [
    handoff.toolName,
    handoff.title,
    handoff.status,
    handoff.summary,
    handoff.filesChanged.join(" "),
    handoff.editLocations.map((location) => formatEditLocation(location)).join(" "),
    handoff.artifactSources.join(" "),
    handoff.artifactQueries.join(" "),
    handoff.artifactSummary ?? "",
  ].join(" ");
  return tokenizeHandoffText(handoffText).filter((token) => promptTokens.has(token)).length;
}

async function resolveReviewSignature(
  cwd: string,
  signal?: AbortSignal,
): Promise<string | undefined> {
  try {
    return workingTreeSignature(await snapshotWorkingTree(cwd, signal));
  } catch {
    return undefined;
  }
}

async function resolveWorkerSelection(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: DelegateParams,
): Promise<{ ref: ModelRef; model: Model<Api>; thinkingLevel: ThinkingLevel }> {
  const thinkingLevel =
    params.workerThinkingLevel ?? getEffectiveThinkingLevel(state);
  if (params.workerModel) {
    const requested = resolveRequestedModel(ctx, params.workerModel, "worker");
    if ("error" in requested) {
      throw new Error(requested.error);
    }
    return { ...requested, thinkingLevel };
  }

  const ref = getEffectiveWorkerRef(ctx, state);
  if (!ref) {
    throw new Error(
      "No worker model could be resolved. Select a model first or configure /worker-model.",
    );
  }

  const model = findModel(ctx, ref);
  if (!model) {
    throw new Error(
      `Worker model not found: ${formatModel(ref, thinkingLevel)}. Use provider/model if needed.`,
    );
  }

  return { ref, model, thinkingLevel };
}

async function resolveScoutSelection(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
): Promise<{ ref: ModelRef; model: Model<Api>; thinkingLevel: ThinkingLevel }> {
  const thinkingLevel =
    params.scoutThinkingLevel ?? getEffectiveScoutThinkingLevel(state);
  if (params.scoutModel) {
    const requested = resolveRequestedModel(ctx, params.scoutModel, "scout");
    if ("error" in requested) {
      throw new Error(requested.error);
    }
    return { ...requested, thinkingLevel };
  }

  const ref = getEffectiveScoutRef(ctx, state);
  if (!ref) {
    throw new Error(
      "No scout model could be resolved. Select a model first or configure /scout-model.",
    );
  }

  const model = findModel(ctx, ref);
  if (!model) {
    throw new Error(
      `Scout model not found: ${formatModel(ref, thinkingLevel)}. Use provider/model if needed.`,
    );
  }

  return { ref, model, thinkingLevel };
}

function buildCompactReport(
  report: string,
  filesChanged: string[],
  editLocations: HandoffEditLocation[],
  options?: {
    kind?: "worker" | "scout";
    status?: DelegateStatus | "completed" | "blocked";
    validation?: ValidationResult[];
    boundaryViolations?: string[];
    artifactSources?: string[];
    artifactQueries?: string[];
  },
): string {
  const statusLine = options?.status || parseSectionItems(report, "Status")[0] || "completed";
  const summaryItems = parseSummaryLikeItems(report).slice(0, 3);
  const fallbackSummary = report.trim() ? truncate(singleLine(report.trim()), 220) : "(none)";
  const findingsItems = parseSectionItems(report, "Findings").slice(0, 2);
  const relevantFiles = parseSectionItems(report, "Relevant Files").slice(0, 3);
  const escalationItems = parseSectionItems(report, "Escalation");
  const nextStepItems = parseSectionItems(report, "Recommended Next Step").slice(0, 2);
  const validationSummary = options?.validation && options.validation.length > 0
    ? `${options.validation.filter((item) => item.outcome === "pass").length} pass, ${options.validation.filter((item) => item.outcome === "fail").length} fail, ${options.validation.filter((item) => item.outcome !== "pass" && item.outcome !== "fail").length} not run`
    : "";
  const boundaryLines = options?.boundaryViolations?.slice(0, 2).map((item) => singleLine(item)) ?? [];
  const workerFiles = filesChanged.slice(0, 5).map((item) => `- ${item}`);
  if (filesChanged.length > 5) {
    workerFiles.push(`- +${filesChanged.length - 5} more`);
  }
  const normalizedEdits = dedupeEditLocations(editLocations);
  const editLines = normalizedEdits.slice(0, 3).map((item) => `- ${formatEditLocation(item)}`);
  if (normalizedEdits.length > 3) {
    editLines.push(`- +${normalizedEdits.length - 3} more`);
  }
  const artifactLines = [
    ...(options?.artifactSources?.length ? [`- sources: ${options.artifactSources.join(", ")}`] : []),
    ...(options?.artifactQueries?.length ? [`- queries: ${options.artifactQueries.join(", ")}`] : []),
  ];
  const kind = options?.kind ?? (relevantFiles.length > 0 || findingsItems.length > 0 || nextStepItems.length > 0 ? "scout" : "worker");

  const lines = [
    "## Status",
    `- ${statusLine}`,
    "",
    "## Summary",
    ...(summaryItems.length > 0 ? summaryItems.map((item) => `- ${singleLine(item)}`) : [`- ${fallbackSummary}`]),
  ];

  if (kind === "scout") {
    lines.push(
      "",
      "## Relevant Files",
      ...(relevantFiles.length > 0 ? relevantFiles.map((item) => `- ${singleLine(item)}`) : ["- (none)"]),
      "",
      "## Findings",
      ...(findingsItems.length > 0 ? findingsItems.map((item) => `- ${singleLine(item)}`) : [`- ${fallbackSummary}`]),
    );
    if (artifactLines.length > 0) {
      lines.push("", "## Artifacts", ...artifactLines);
    }
    lines.push(
      "",
      "## Recommended Next Step",
      ...(nextStepItems.length > 0 ? nextStepItems.map((item) => `- ${singleLine(item)}`) : [`- ${fallbackSummary}`]),
    );
    return lines.join("\n");
  }

  lines.push(
    "",
    "## Files Changed",
    ...(workerFiles.length > 0 ? workerFiles : ["- (none)"]),
    "",
    "## Edits",
    ...(editLines.length > 0 ? editLines : ["- (none)"]),
  );

  const failedValidationLines = (options?.validation ?? [])
    .filter((item) => item.outcome === "fail")
    .slice(0, 2)
    .map((item) => {
      const exitText = item.exitCode === null ? "signal" : String(item.exitCode);
      return `- ${item.command} - ${item.outcome} (exit ${exitText}) - ${item.note}`;
    });
  lines.push(
    "",
    "## Validation",
    ...(failedValidationLines.length > 0
      ? failedValidationLines
      : [validationSummary ? `- ${validationSummary}` : "- (none)"]),
  );

  if (artifactLines.length > 0) {
    lines.push("", "## Artifacts", ...artifactLines);
  }

  const combinedEscalation = [
    ...boundaryLines.map((item) => `boundary: ${item}`),
    ...escalationItems.map((item) => singleLine(item)),
  ].slice(0, 3);
  lines.push("", "## Escalation", ...(combinedEscalation.length > 0 ? combinedEscalation.map((item) => `- ${item}`) : ["- (none)"]));

  return lines.join("\n");
}

async function generateDelegation(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: DelegateParams,
  delegationId: string,
  pi: ExtensionAPI,
  shouldLog?: () => boolean,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
  onProgress?: (progress: SubagentProgress) => void,
): Promise<DelegateResult> {
  const cwd = params.cwd?.trim() || ctx.cwd;
  if (!ctx.model) {
    appendSubagentEvent(pi, {
      type: "subagent_start",
      delegationId,
      role: "worker",
      cwd,
      requestedModel: params.workerModel,
      objective: params.objective,
      scope: params.scope,
      allowedFiles: params.allowedFiles,
      blockedFiles: params.blockedFiles,
      acceptanceCriteria: params.acceptanceCriteria,
      validationCommands: params.validationCommands,
      escalationTriggers: params.escalationTriggers,
      tools: params.tools,
      generatedAt: Date.now(),
    }, shouldLog);
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "worker",
      model: params.workerModel,
      cwd,
      outcome: "failed",
      phase: "preflight",
      errorMessage: "No active supervisor model selected.",
      generatedAt: Date.now(),
    }, shouldLog);
    throw new Error("No active supervisor model selected.");
  }

  appendSubagentEvent(pi, {
    type: "subagent_start",
    delegationId,
    role: "worker",
    cwd,
    requestedModel: params.workerModel,
    objective: params.objective,
    scope: params.scope,
    allowedFiles: params.allowedFiles,
    blockedFiles: params.blockedFiles,
    acceptanceCriteria: params.acceptanceCriteria,
    validationCommands: params.validationCommands,
    escalationTriggers: params.escalationTriggers,
    tools: params.tools,
    generatedAt: Date.now(),
  }, shouldLog);

  let auth: { apiKey?: string; headers?: Record<string, string> };
  let beforeSnapshot: WorkingTreeSnapshot;
  let workerModelArg: string;
  let prompt: string;
  try {
    const worker = await resolveWorkerSelection(ctx, state, params);
    const authResult = await ctx.modelRegistry.getApiKeyAndHeaders(worker.model);
    if (!authResult.ok) {
      throw new Error(`Unable to resolve auth for worker model: ${authResult.error}`);
    }
    auth = { apiKey: authResult.apiKey, headers: authResult.headers };

    beforeSnapshot = await snapshotWorkingTree(cwd, signal);
    workerModelArg = formatModel(worker.ref, worker.thinkingLevel);
    const conversationContext = buildConversationContext(
      ctx.sessionManager.getBranch(),
    );
    prompt = buildWorkerPrompt(params, conversationContext);
  } catch (error) {
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "worker",
      model: params.workerModel,
      cwd,
      outcome: classifySubagentOutcome({
        exitCode: 1,
        errorMessage: error instanceof Error ? error.message : String(error),
      }, signal),
      phase: "preflight",
      errorMessage: error instanceof Error ? error.message : String(error),
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
  let run: Awaited<ReturnType<typeof runWorkerSubagent>> | undefined;
  try {
    run = await runWorkerSubagent(
      cwd,
      prompt,
      workerModelArg,
      auth,
      params.tools,
      delegationId,
      {
        objective: params.objective,
        scope: params.scope,
        allowedFiles: params.allowedFiles,
        blockedFiles: params.blockedFiles,
        acceptanceCriteria: params.acceptanceCriteria,
        validationCommands: params.validationCommands,
        escalationTriggers: params.escalationTriggers,
        tools: params.tools,
      },
      pi,
      shouldLog,
      signal,
      onUpdate,
      onProgress,
    );
    const final = extractFinalAssistantText(
      [
        ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
        ...run.messages,
        ...(run.turnEndMessage ? [run.turnEndMessage] : []),
        ...(run.agentEndMessage ? [run.agentEndMessage] : []),
      ],
      run.streamedText,
      true,
    );

    if (!final.text) {
      const stderr = run.stderr.trim();
      throw new Error(
        `Worker subagent returned no text (exitCode: ${run.exitCode}; stopReason: ${run.stopReason ?? "none"}${stderr ? `; stderr: ${stderr}` : ""}).`,
      );
    }

    const afterSnapshot = await snapshotWorkingTree(cwd, signal);
    const actualFilesChanged = diffSnapshots(beforeSnapshot, afterSnapshot);
    const { editLocations, artifactSources, artifactQueries } = await deriveEditLocations(
      afterSnapshot.root,
      run.toolExecutions,
      actualFilesChanged,
    );
    const effectiveArtifactSources = [
      ...(params.artifactSources ?? []),
      ...artifactSources,
    ];
    const effectiveArtifactQueries = [
      ...(params.artifactQueries ?? []),
      ...artifactQueries,
    ];
    const boundaryViolations = findBoundaryViolations(
      actualFilesChanged,
      params.allowedFiles,
      params.blockedFiles,
    );
    const validation = await runValidationCommands(
      cwd,
      params.validationCommands,
      signal,
    );
    const hasValidationFailures = validation.some(
      (item) => item.outcome === "fail",
    );
    let status = parseStatus(final.text);
    if (boundaryViolations.length > 0 || hasValidationFailures) {
      status = "blocked";
    }

    const baseOutcome = classifySubagentOutcome(run, signal);
    const blockedReasons = [
      ...(boundaryViolations.length > 0 ? ["boundary"] : []),
      ...(hasValidationFailures ? ["validation"] : []),
    ];
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "worker",
      model: workerModelArg,
      cwd,
      outcome: baseOutcome,
      status,
      blockedReasons: blockedReasons.length > 0 ? blockedReasons : undefined,
      exitCode: run.exitCode,
      stopReason: run.stopReason,
      errorMessage: final.errorMessage,
      stderr: run.stderr.trim() || undefined,
      metrics: buildSubagentMetrics(run),
      generatedAt: Date.now(),
    }, shouldLog);

    return {
      report: buildCompactReport(final.text, actualFilesChanged, editLocations, {
        kind: "worker",
        status,
        validation,
        boundaryViolations,
        artifactSources: [...new Set(effectiveArtifactSources.map((item) => item.trim()).filter(Boolean))].sort(),
        artifactQueries: [...new Set(effectiveArtifactQueries.map((item) => item.trim()).filter(Boolean))].sort(),
      }),
      fullReport: `${final.text}${buildSupervisorAppendix(boundaryViolations, validation)}${buildInspectionAppendix(editLocations, actualFilesChanged)}`,
      workerModel: workerModelArg,
      status,
      filesChanged: actualFilesChanged,
      editLocations,
      artifactSources: [...new Set(effectiveArtifactSources.map((item) => item.trim()).filter(Boolean))].sort(),
      artifactQueries: [...new Set(effectiveArtifactQueries.map((item) => item.trim()).filter(Boolean))].sort(),
      artifactSummary: params.artifactSummary,
      boundaryViolations,
      validation,
      subagentMetrics: buildSubagentMetrics(run),
      stopReason: run.stopReason,
      errorMessage: final.errorMessage,
    };
  } catch (error) {
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "worker",
      model: workerModelArg,
      cwd,
      outcome: classifySubagentOutcome({
        exitCode: run?.exitCode ?? 1,
        stopReason: run?.stopReason,
        errorMessage: error instanceof Error ? error.message : String(error),
      }, signal),
      phase: run ? "postprocess" : "subprocess",
      exitCode: run?.exitCode,
      stopReason: run?.stopReason,
      errorMessage: error instanceof Error ? error.message : String(error),
      stderr: run?.stderr.trim() || undefined,
      metrics: run ? buildSubagentMetrics(run) : undefined,
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
}

async function generateScouting(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
  delegationId: string,
  pi: ExtensionAPI,
  shouldLog?: () => boolean,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
  onProgress?: (progress: SubagentProgress) => void,
): Promise<ScoutResult> {
  const cwd = params.cwd?.trim() || ctx.cwd;
  if (!ctx.model) {
    appendSubagentEvent(pi, {
      type: "subagent_start",
      delegationId,
      role: "scout",
      cwd,
      requestedModel: params.scoutModel,
      objective: params.objective,
      scope: params.scope,
      questions: params.questions,
      expectedOutputs: params.expectedOutputs,
      tools: params.tools,
      generatedAt: Date.now(),
    }, shouldLog);
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "scout",
      model: params.scoutModel,
      cwd,
      outcome: "failed",
      status: "blocked",
      phase: "preflight",
      errorMessage: "No active supervisor model selected.",
      generatedAt: Date.now(),
    }, shouldLog);
    throw new Error("No active supervisor model selected.");
  }

  appendSubagentEvent(pi, {
    type: "subagent_start",
    delegationId,
    role: "scout",
    cwd,
    requestedModel: params.scoutModel,
    objective: params.objective,
    scope: params.scope,
    questions: params.questions,
    expectedOutputs: params.expectedOutputs,
    tools: params.tools,
    generatedAt: Date.now(),
  }, shouldLog);

  let auth: { apiKey?: string; headers?: Record<string, string> };
  let scoutModelArg: string;
  let prompt: string;
  try {
    const scout = await resolveScoutSelection(ctx, state, params);
    const authResult = await ctx.modelRegistry.getApiKeyAndHeaders(scout.model);
    if (!authResult.ok) {
      throw new Error(`Unable to resolve auth for scout model: ${authResult.error}`);
    }
    auth = { apiKey: authResult.apiKey, headers: authResult.headers };

    scoutModelArg = formatModel(scout.ref, scout.thinkingLevel);
    const conversationContext = buildConversationContext(ctx.sessionManager.getBranch());
    prompt = buildScoutPrompt(params, conversationContext);
  } catch (error) {
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "scout",
      model: params.scoutModel,
      cwd,
      outcome: classifySubagentOutcome({
        exitCode: 1,
        errorMessage: error instanceof Error ? error.message : String(error),
      }, signal),
      status: "blocked",
      phase: "preflight",
      errorMessage: error instanceof Error ? error.message : String(error),
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
  let run: Awaited<ReturnType<typeof runScoutSubagent>> | undefined;
  try {
    run = await runScoutSubagent(
      cwd,
      prompt,
      scoutModelArg,
      auth,
      params.tools,
      delegationId,
      {
        objective: params.objective,
        scope: params.scope,
        questions: params.questions,
        expectedOutputs: params.expectedOutputs,
        tools: params.tools,
      },
      pi,
      shouldLog,
      signal,
      onUpdate,
      onProgress,
    );
    const final = extractFinalAssistantText(
      [
        ...(run.lastAssistantPartial ? [run.lastAssistantPartial] : []),
        ...run.messages,
        ...(run.turnEndMessage ? [run.turnEndMessage] : []),
        ...(run.agentEndMessage ? [run.agentEndMessage] : []),
      ],
      run.streamedText,
      true,
    );

    if (!final.text) {
      const stderr = run.stderr.trim();
      throw new Error(
        `Scout subagent returned no text (exitCode: ${run.exitCode}; stopReason: ${run.stopReason ?? "none"}${stderr ? `; stderr: ${stderr}` : ""}).`,
      );
    }

    const { artifactSources, artifactQueries } = await deriveEditLocations(
      cwd,
      run.toolExecutions,
      [],
    );
    const stopReason = run.stopReason?.toLowerCase() ?? "";
    const scoutStatus: DelegateStatus =
      !signal?.aborted &&
      run.exitCode === 0 &&
      !final.errorMessage &&
      !stopReason.includes("limit") &&
      !stopReason.includes("max") &&
      !stopReason.includes("abort") &&
      !stopReason.includes("cancel") &&
      !stopReason.includes("interrupt")
        ? "completed"
        : "blocked";
    const effectiveArtifactSources = [
      ...(params.artifactSources ?? []),
      ...artifactSources,
    ];
    const effectiveArtifactQueries = [
      ...(params.artifactQueries ?? []),
      ...artifactQueries,
    ];

    const scoutOutcome = classifySubagentOutcome(run, signal);
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "scout",
      model: scoutModelArg,
      cwd,
      outcome: scoutOutcome,
      status: scoutStatus,
      exitCode: run.exitCode,
      stopReason: run.stopReason,
      errorMessage: final.errorMessage,
      stderr: run.stderr.trim() || undefined,
      metrics: buildSubagentMetrics(run),
      generatedAt: Date.now(),
    }, shouldLog);

    return {
      report: buildCompactReport(final.text, [], [], {
        kind: "scout",
        status: scoutStatus,
        artifactSources: [...new Set(effectiveArtifactSources.map((item) => item.trim()).filter(Boolean))].sort(),
        artifactQueries: [...new Set(effectiveArtifactQueries.map((item) => item.trim()).filter(Boolean))].sort(),
      }),
      fullReport: `## Status\n- ${scoutStatus}\n\n${final.text}`,
      status: scoutStatus,
      scoutModel: scoutModelArg,
      artifactSources: [...new Set(effectiveArtifactSources.map((item) => item.trim()).filter(Boolean))].sort(),
      artifactQueries: [...new Set(effectiveArtifactQueries.map((item) => item.trim()).filter(Boolean))].sort(),
      artifactSummary: params.artifactSummary,
      subagentMetrics: buildSubagentMetrics(run),
      stopReason: run.stopReason,
      errorMessage: final.errorMessage,
    };
  } catch (error) {
    appendSubagentEvent(pi, {
      type: "subagent_end",
      delegationId,
      role: "scout",
      model: scoutModelArg,
      cwd,
      outcome: "failed",
      status: "blocked",
      phase: run ? "postprocess" : "subprocess",
      exitCode: run?.exitCode,
      stopReason: run?.stopReason,
      errorMessage: error instanceof Error ? error.message : String(error),
      stderr: run?.stderr.trim() || undefined,
      metrics: run ? buildSubagentMetrics(run) : undefined,
      generatedAt: Date.now(),
    }, shouldLog);
    throw error;
  }
}

const DelegateWorkerParams = Type.Object({
  objective: Type.String({
    description: "The concrete implementation task for the worker subagent.",
  }),
  scope: Type.Optional(
    Type.String({
      description:
        "Explicit boundaries for the task, including what to change and what to avoid.",
    }),
  ),
  allowedFiles: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Files the worker may edit. Keep this narrow for local tasks.",
    }),
  ),
  blockedFiles: Type.Optional(
    Type.Array(Type.String(), {
      description: "Files the worker must not edit.",
    }),
  ),
  acceptanceCriteria: Type.Optional(
    Type.Array(Type.String(), {
      description: "Objective checks the task must satisfy before completion.",
    }),
  ),
  validationCommands: Type.Optional(
    Type.Array(Type.String(), {
      description: "Focused commands for the worker to run after editing.",
    }),
  ),
  escalationTriggers: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Situations where the worker must stop and escalate instead of guessing.",
    }),
  ),
  workerModel: Type.Optional(
    Type.String({
      description:
        "Worker model id or provider/id. Defaults to the configured worker model, or github-copilot/gemini-3-flash-preview.",
    }),
  ),
  workerThinkingLevel: Type.Optional(
    StringEnum(THINKING_LEVELS, {
      description: "Thinking level for the worker subagent. Default: minimal.",
    }),
  ),
  cwd: Type.Optional(
    Type.String({ description: "Working directory for the worker process." }),
  ),
  tools: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional explicit tool allowlist for the worker process.",
    }),
  ),
  artifactSources: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional labels of reusable artifacts from context-mode (for example, 'batch:git diff,tests' or 'react-docs') to include in the subagent's working context.",
    }),
  ),
  artifactQueries: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional queries to help the subagent retrieve relevant data from the shared context-mode store.",
    }),
  ),
  artifactSummary: Type.Optional(
    Type.String({
      description: "Optional high-level summary of relevant prior research to prime the subagent.",
    }),
  ),
});

const DelegateScoutParams = Type.Object({
  objective: Type.String({
    description: "The concrete scouting objective for the read-only scout subagent.",
  }),
  scope: Type.Optional(
    Type.String({
      description: "Explicit scouting boundaries, such as directories, modules, or behaviors to inspect.",
    }),
  ),
  questions: Type.Optional(
    Type.Array(Type.String(), {
      description: "Specific questions the scout should answer from the codebase.",
    }),
  ),
  expectedOutputs: Type.Optional(
    Type.Array(Type.String(), {
      description: "Expected scouting outputs, such as relevant files, call paths, or implementation precedents.",
    }),
  ),
  scoutModel: Type.Optional(
    Type.String({
      description:
        "Scout model id or provider/id. Defaults to the configured fast worker model, or github-copilot/gemini-3-flash-preview.",
    }),
  ),
  scoutThinkingLevel: Type.Optional(
    StringEnum(THINKING_LEVELS, {
      description: "Thinking level for the scout subagent. Default: minimal.",
    }),
  ),
  cwd: Type.Optional(Type.String({ description: "Working directory for the scout process." })),
  tools: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional scout-safe tool allowlist for the scout process. Unsafe tools are ignored.",
    }),
  ),
  artifactSources: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional labels of reusable artifacts from context-mode (for example, 'batch:git diff,tests' or 'react-docs') to include in the subagent's working context.",
    }),
  ),
  artifactQueries: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional queries to help the subagent retrieve relevant data from the shared context-mode store.",
    }),
  ),
  artifactSummary: Type.Optional(
    Type.String({
      description: "Optional high-level summary of relevant prior research to prime the subagent.",
    }),
  ),
});

const ParallelDelegateWorkerTaskParams = Type.Object({
  label: Type.Optional(
    Type.String({
      description: "Optional short label for aggregated progress and results.",
    }),
  ),
  objective: Type.String({
    description: "The concrete implementation task for the worker subagent.",
  }),
  scope: Type.Optional(
    Type.String({
      description:
        "Explicit boundaries for the task, including what to change and what to avoid.",
    }),
  ),
  allowedFiles: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Files the worker may edit. Required for parallel worker delegations and must be disjoint across tasks.",
    }),
  ),
  blockedFiles: Type.Optional(
    Type.Array(Type.String(), {
      description: "Files the worker must not edit.",
    }),
  ),
  acceptanceCriteria: Type.Optional(
    Type.Array(Type.String(), {
      description: "Objective checks the task must satisfy before completion.",
    }),
  ),
  validationCommands: Type.Optional(
    Type.Array(Type.String(), {
      description: "Focused commands for the worker to run after editing.",
    }),
  ),
  escalationTriggers: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Situations where the worker must stop and escalate instead of guessing.",
    }),
  ),
  workerModel: Type.Optional(
    Type.String({
      description:
        "Worker model id or provider/id. Defaults to the configured worker model, or github-copilot/gemini-3-flash-preview.",
    }),
  ),
  workerThinkingLevel: Type.Optional(
    StringEnum(THINKING_LEVELS, {
      description: "Thinking level for the worker subagent. Default: minimal.",
    }),
  ),
  cwd: Type.Optional(
    Type.String({ description: "Working directory for the worker process." }),
  ),
  tools: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional explicit tool allowlist for the worker process.",
    }),
  ),
  artifactSources: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional labels of reusable artifacts from context-mode (for example, 'batch:git diff,tests' or 'react-docs') to include in the subagent's working context.",
    }),
  ),
  artifactQueries: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional queries to help the subagent retrieve relevant data from the shared context-mode store.",
    }),
  ),
  artifactSummary: Type.Optional(
    Type.String({
      description: "Optional high-level summary of relevant prior research to prime the subagent.",
    }),
  ),
});

const ParallelDelegateWorkersParams = Type.Object({
  tasks: Type.Array(ParallelDelegateWorkerTaskParams, {
    description:
      "Parallel worker tasks. Keep them independent, require allowedFiles on every task, and avoid overlapping file scopes.",
  }),
  maxConcurrency: Type.Optional(
    Type.Integer({
      description: `Maximum workers to run at once. Default: ${DEFAULT_PARALLEL_SUBAGENT_CONCURRENCY}, maximum: ${MAX_PARALLEL_SUBAGENT_CONCURRENCY}.`,
      minimum: 1,
      maximum: MAX_PARALLEL_SUBAGENT_CONCURRENCY,
    }),
  ),
});

const ParallelDelegateScoutTaskParams = Type.Object({
  label: Type.Optional(
    Type.String({
      description: "Optional short label for aggregated progress and results.",
    }),
  ),
  objective: Type.String({
    description: "The concrete scouting objective for the read-only scout subagent.",
  }),
  scope: Type.Optional(
    Type.String({
      description: "Explicit scouting boundaries, such as directories, modules, or behaviors to inspect.",
    }),
  ),
  questions: Type.Optional(
    Type.Array(Type.String(), {
      description: "Specific questions the scout should answer from the codebase.",
    }),
  ),
  expectedOutputs: Type.Optional(
    Type.Array(Type.String(), {
      description: "Expected scouting outputs, such as relevant files, call paths, or implementation precedents.",
    }),
  ),
  scoutModel: Type.Optional(
    Type.String({
      description:
        "Scout model id or provider/id. Defaults to the configured fast worker model, or github-copilot/gemini-3-flash-preview.",
    }),
  ),
  scoutThinkingLevel: Type.Optional(
    StringEnum(THINKING_LEVELS, {
      description: "Thinking level for the scout subagent. Default: minimal.",
    }),
  ),
  cwd: Type.Optional(Type.String({ description: "Working directory for the scout process." })),
  tools: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional scout-safe tool allowlist for the scout process. Unsafe tools are ignored.",
    }),
  ),
  artifactSources: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional labels of reusable artifacts from context-mode (for example, 'batch:git diff,tests' or 'react-docs') to include in the subagent's working context.",
    }),
  ),
  artifactQueries: Type.Optional(
    Type.Array(Type.String(), {
      description: "Optional queries to help the subagent retrieve relevant data from the shared context-mode store.",
    }),
  ),
  artifactSummary: Type.Optional(
    Type.String({
      description: "Optional high-level summary of relevant prior research to prime the subagent.",
    }),
  ),
});

const ParallelDelegateScoutsParams = Type.Object({
  tasks: Type.Array(ParallelDelegateScoutTaskParams, {
    description: "Parallel read-only scouting tasks to run concurrently.",
  }),
  maxConcurrency: Type.Optional(
    Type.Integer({
      description: `Maximum scouts to run at once. Default: ${DEFAULT_PARALLEL_SUBAGENT_CONCURRENCY}, maximum: ${MAX_PARALLEL_SUBAGENT_CONCURRENCY}.`,
      minimum: 1,
      maximum: MAX_PARALLEL_SUBAGENT_CONCURRENCY,
    }),
  ),
});

export default function supervisorWorkerExtension(pi: ExtensionAPI) {
  const role = process.env[WORKER_ENV_FLAG];
  if (role === "worker") {
    return;
  }

  if (role === "scout") {
    pi.on("tool_call", async (event) => {
      if (SCOUT_BLOCKED_TOOLS.has(event.toolName)) {
        return {
          block: true,
          reason: `Tool '${event.toolName}' is blocked in scout mode. Use read-only tools instead.`,
        };
      }

      if (event.toolName === "ctx_execute") {
        const input = event.input as { language?: string; code?: string };
        const isShell =
          input.language === "shell" ||
          input.language === "bash" ||
          input.language === "sh";
        if (!isShell) {
          return {
            block: true,
            reason: "Scout mode allows ctx_execute only with shell inspection commands.",
          };
        }
        if (input.code && isMutatingBashCommand(input.code)) {
          return {
            block: true,
            reason: "Mutating shell command detected in ctx_execute. Scout mode is read-only.",
          };
        }
      }

      if (event.toolName === "ctx_batch_execute") {
        const input = event.input as {
          commands?: Array<{ command?: string }>;
        };
        if (input.commands?.some((command) => isMutatingBashCommand(command?.command))) {
          return {
            block: true,
            reason: "Mutating shell command detected in ctx_batch_execute. Scout mode is read-only.",
          };
        }
      }
    });
    return;
  }

  let state: SupervisorWorkerState = {};
  let sessionEpoch = 0;
  let turnDelegationState: TurnDelegationState | undefined;
  let recentReviewKeys: string[] = [];
  const pendingReviewKeys = new Map<string, string>();
  const activeDelegations = new Map<string, ActiveDelegation>();

  function persistState() {
    pi.appendEntry(STATE_ENTRY, state);
  }

  function middleDot(text: string): string {
    return text ? `· ${text}` : "";
  }

  function formatDelegationStatus(item: Pick<ActiveDelegation, "phase" | "turns" | "currentTool">): string {
    return [
      item.phase,
      item.turns !== undefined && item.turns > 0 ? `${item.turns} turns` : "",
      item.currentTool ?? "",
    ].filter(Boolean).join(" · ");
  }

  function buildSingleDelegationProgressText(
    item: ActiveDelegation,
    detailText?: string,
  ): string {
    const header = formatDelegationStatus(item) || item.phase;
    const detail = detailText?.trim();
    return detail ? `${header}\n${detail}` : header;
  }

  const subagentPanelRefreshers = new Set<() => void>();
  let subagentPanelOpen = false;

  function refreshSubagentPanels() {
    for (const refresh of subagentPanelRefreshers) {
      refresh();
    }
  }

  function sanitizeDelegationDetail(detailText: string | undefined): string | undefined {
    const trimmed = detailText?.trim();
    if (!trimmed) return undefined;
    return trimmed.length > MAX_SUBAGENT_DETAIL_CHARS
      ? trimmed.slice(trimmed.length - MAX_SUBAGENT_DETAIL_CHARS)
      : trimmed;
  }

  function recordDelegationDetail(
    delegationKey: string,
    detailText: string | undefined,
  ): ActiveDelegation | undefined {
    const active = activeDelegations.get(delegationKey);
    if (!active) return undefined;
    const next = sanitizeDelegationDetail(detailText);
    if (active.detailText === next) {
      return active;
    }
    active.detailText = next;
    refreshSubagentPanels();
    return active;
  }

  function recordDelegationActivity(
    delegationKey: string,
    activityLine: string | undefined,
  ): ActiveDelegation | undefined {
    const active = activeDelegations.get(delegationKey);
    if (!active) return undefined;
    const next = activityLine?.trim();
    if (!next) return active;
    const recent = [...(active.recentActivity ?? [])];
    recent.push(next);
    active.recentActivity = recent.slice(-MAX_SUBAGENT_ACTIVITY_LINES);
    refreshSubagentPanels();
    return active;
  }

  function buildDetailPreviewLines(item: ActiveDelegation, width: number): string[] {
    const text = item.detailText?.trim();
    if (!text) return [];
    const sourceLines = text
      .split(/\r?\n/g)
      .map((line) => line.trim())
      .filter(Boolean)
      .slice(-MAX_SUBAGENT_DETAIL_LINES);
    return sourceLines
      .flatMap((line) => wrapTextWithAnsi(line, Math.max(12, width)))
      .slice(-MAX_SUBAGENT_DETAIL_LINES);
  }

  function buildRecentActivityLines(item: ActiveDelegation, width: number): string[] {
    return (item.recentActivity ?? [])
      .slice(-MAX_SUBAGENT_ACTIVITY_LINES)
      .flatMap((line) => wrapTextWithAnsi(line, Math.max(12, width)));
  }

  function padPanelLine(text: string, width: number): string {
    return text + " ".repeat(Math.max(0, width - visibleWidth(text)));
  }

  function renderSubagentActivityPanel(width: number, theme: ExtensionContext["ui"]["theme"], items: ActiveDelegation[]): string[] {
    const innerWidth = Math.max(24, width - 2);
    const row = (content = "") => {
      const fitted = truncateToWidth(content, innerWidth, "");
      return `${theme.fg("border", "│")}${padPanelLine(fitted, innerWidth)}${theme.fg("border", "│")}`;
    };
    const lines = [
      theme.fg("border", `╭${"─".repeat(innerWidth)}╮`),
      row(` ${theme.fg("accent", theme.bold("Subagent Activity"))}`),
      row(` ${theme.fg("dim", `${items.length} active • ${SUBAGENT_ACTIVITY_SHORTCUT} or Esc closes`)}`),
      row(),
    ];

    if (items.length === 0) {
      lines.push(row(` ${theme.fg("dim", "No active subagents.")}`));
      lines.push(row(` ${theme.fg("dim", "The widget below the editor will light up when new delegations start.")}`));
    } else {
      items.forEach((item, index) => {
        const status = formatDelegationStatus(item) || item.phase;
        lines.push(row(` ${theme.fg("accent", theme.bold(`${item.role.toUpperCase()} · ${item.workerModel}`))}`));
        for (const wrapped of wrapTextWithAnsi(item.title, Math.max(12, innerWidth - 2))) {
          lines.push(row(` ${theme.fg("text", wrapped)}`));
        }
        lines.push(row(` ${theme.fg("muted", status)}`));
        const activityLines = buildRecentActivityLines(item, innerWidth - 4);
        if (activityLines.length > 0) {
          lines.push(row(` ${theme.fg("dim", "Recent activity:")}`));
          for (const activityLine of activityLines) {
            lines.push(row(` ${theme.fg("dim", `  ${activityLine}`)}`));
          }
        }
        const detailLines = buildDetailPreviewLines(item, innerWidth - 4);
        if (detailLines.length > 0) {
          lines.push(row(` ${theme.fg("dim", "Latest output:")}`));
          for (const detailLine of detailLines) {
            lines.push(row(` ${theme.fg("dim", `  ${detailLine}`)}`));
          }
        }
        if (index < items.length - 1) {
          lines.push(row());
        }
      });
    }

    lines.push(row());
    lines.push(row(` ${theme.fg("dim", `Tip: run /${SUBAGENT_ACTIVITY_COMMAND} or press ${SUBAGENT_ACTIVITY_SHORTCUT}`)}`));
    lines.push(theme.fg("border", `╰${"─".repeat(innerWidth)}╯`));
    return lines;
  }

  async function showSubagentActivityPanel(ctx: ExtensionContext) {
    if (!ctx.hasUI || ctx.mode !== "tui") {
      ctx.ui.notify("Subagent activity panel is only available in TUI mode.", "warning");
      return;
    }
    if (subagentPanelOpen) {
      ctx.ui.notify("Subagent activity panel is already open.", "info");
      return;
    }

    subagentPanelOpen = true;
    try {
      await ctx.ui.custom<void>(
        (tui, theme, _keybindings, done) => {
          const refresh = () => tui.requestRender();
          subagentPanelRefreshers.add(refresh);
          return {
            render: (panelWidth: number) => renderSubagentActivityPanel(panelWidth, theme, [...activeDelegations.values()]),
            handleInput: (data: string) => {
              if (matchesKey(data, "escape") || matchesKey(data, SUBAGENT_ACTIVITY_SHORTCUT)) {
                done(undefined);
              }
            },
            invalidate: () => {},
            dispose: () => {
              subagentPanelRefreshers.delete(refresh);
            },
          };
        },
        {
          overlay: true,
          overlayOptions: {
            anchor: "right-center",
            width: "44%",
            minWidth: 48,
            maxHeight: "80%",
            margin: 1,
            visible: (termWidth) => termWidth >= 80,
          },
        },
      );
    } finally {
      subagentPanelOpen = false;
    }
  }

  function updateDelegationWidget(ctx: ExtensionContext) {
    const items = [...activeDelegations.values()];
    if (items.length === 0) {
      SUBAGENTS_WIDGET.clear(ctx);
      refreshSubagentPanels();
      return;
    }

    SUBAGENTS_WIDGET.set(ctx, [
      `Subagents (${items.length}) — ${SUBAGENT_ACTIVITY_SHORTCUT} for activity`,
      ...items.map((item) => {
        const parts = [
          `• ${item.role} ${item.workerModel} [${item.phase}]`,
          middleDot(item.turns !== undefined && item.turns > 0 ? `${item.turns} turns` : ""),
          middleDot(item.currentTool ?? ""),
        ].filter(Boolean);
        return `${parts.join(" ")} — ${item.title}`;
      }),
    ]);
    refreshSubagentPanels();
  }

  function patchActiveDelegation(
    ctx: ExtensionContext,
    delegationKey: string,
    patch: Partial<Pick<ActiveDelegation, "phase" | "workerModel" | "turns" | "currentTool">>,
  ): ActiveDelegation | undefined {
    const active = activeDelegations.get(delegationKey);
    if (!active) return undefined;

    let changed = false;
    for (const [key, value] of Object.entries(patch)) {
      if (active[key as keyof typeof active] === value) {
        continue;
      }
      (active as Record<string, unknown>)[key] = value;
      changed = true;
    }

    if (changed) {
      updateDelegationWidget(ctx);
    }
    return active;
  }

  function emitSingleDelegationUpdate(
    onUpdate: ((update: any) => void) | undefined,
    item: ActiveDelegation | undefined,
    detailText?: string,
  ) {
    if (!onUpdate || !item) return;
    onUpdate({
      content: [{ type: "text", text: buildSingleDelegationProgressText(item, detailText) }],
      details: {
        role: item.role,
        title: item.title,
        phase: item.phase,
        model: item.workerModel,
        turns: item.turns,
        currentTool: item.currentTool,
      },
    });
  }

  function refreshStatus(ctx: ExtensionContext) {
    updateStatus(ctx, state);
    updateDelegationWidget(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionEpoch += 1;
    turnDelegationState = undefined;
    recentReviewKeys = readSavedReviewKeys(ctx);
    pendingReviewKeys.clear();
    activeDelegations.clear();
    subagentPanelRefreshers.clear();
    subagentPanelOpen = false;
    state = readSavedState(ctx) ?? {};
    refreshStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    sessionEpoch += 1;
    turnDelegationState = undefined;
    pendingReviewKeys.clear();
    activeDelegations.clear();
    subagentPanelRefreshers.clear();
    subagentPanelOpen = false;
    SUBAGENTS_WIDGET.clear(ctx);
    ctx.ui.setStatus("worker", undefined);
    ctx.ui.setStatus("worker-auto", undefined);
  });

  pi.on("model_select", async (_event, ctx) => {
    refreshStatus(ctx);
  });

  pi.registerCommand(SUBAGENT_ACTIVITY_COMMAND, {
    description: "Show live subagent activity in a floating panel",
    handler: async (_args, ctx) => {
      await showSubagentActivityPanel(ctx);
    },
  });

  pi.registerShortcut(SUBAGENT_ACTIVITY_SHORTCUT, {
    description: "Show live subagent activity",
    handler: async (ctx) => {
      await showSubagentActivityPanel(ctx);
    },
  });

  pi.on("before_agent_start", async (event, ctx) => {
    const workerRef = getEffectiveWorkerRef(ctx, state);
    if (!ctx.model || sameModel(toRef(ctx.model), workerRef)) {
      turnDelegationState = undefined;
      return;
    }

    const autoMode = getAutoMode(state);
    const shouldEnforcePlanSplit =
      autoMode === "conservative" && isLikelyImplementationPrompt(event.prompt);
    turnDelegationState = {
      prompt: event.prompt,
      enforcePlanSplit: shouldEnforcePlanSplit,
      completedWorkerDelegations: 0,
      completedScoutDelegations: 0,
      completedReviewDelegations: 0,
      nudgedDirectMutation: false,
      nudgedReviewDeferral: false,
      usedExplicitReviewBypass: false,
      postHandoffReads: 0,
      postHandoffEdits: 0,
      nudgedExpensivePostHandoff: false,
    };

    const strictSection = shouldEnforcePlanSplit
      ? `
- Strict plan-implement split is active for this turn.
- Before making any direct file mutation with \`edit\`, \`write\`, or mutating \`bash\`, first break the work into a bounded implementation step and run \`delegate_worker\`.
- After at least one worker task completes, you may do small supervisor-side integration edits if still needed.
- After a successful worker handoff, prefer one \`ctx_batch_execute\` follow-up across the returned edit locations instead of serial \`read\` calls when you need to inspect multiple changed spots.
- The runtime will warn when you bypass worker-first implementation in this turn.`
      : "";

    const policy =
      autoMode === "conservative"
        ? `

## Delegation Policy

- Conservative auto mode is enabled.
- Use a scout-plan-implement split by default: cheap scout subagents explore and gather evidence, the current model plans/scopes/reviews/escalates, and worker subagents implement bounded steps.
- Proactively use \`delegate_scout\` for read-only reconnaissance such as locating relevant files, tracing behavior, finding precedents, or scoping likely edit sites.
- For coding requests, proactively use \`delegate_worker\` without asking first when the next step is a bounded implementation task that is local, well-specified, and objectively checkable.
- For reusable research that another agent may need later, prefer artifact-producing tools such as \`ctx_batch_execute\`, \`ctx_index\`, \`ctx_fetch_and_index\`, or large \`ctx_execute\` calls with an \`intent\`.
- When setting subagent tool allowlists, include the relevant \`ctx_*\` tools by default; subagents should prefer \`ctx_*\` over \`bash\`/\`read\` for inspection and analysis.
- When a reusable artifact matters to a delegated task, pass its source labels via \`artifactSources\` and suggested lookups via \`artifactQueries\`.
- Good scout candidates: file discovery, behavior tracing, implementation precedent searches, config inventory, and test surface mapping.
- Good auto-delegation candidates for workers: small code edits, focused tests, local refactors, narrow bug fixes, and file-scoped implementation work.
- Later in a session, still consider \`delegate_worker\` for narrow follow-up fixes (e.g. fixing a lint error, wiring a missing handler), integration polish (e.g. updating a theme, refining a UI widget), validation-driven refactors, and file-scoped cleanup after earlier worker handoffs.
- Delegate only bounded work with explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model unless the user explicitly asks otherwise.
- Delegate one independently checkable task at a time by default.
- When multiple read-only scouting tasks are independent, prefer \`delegate_scouts\`.
- When multiple implementation tasks are independent and have disjoint \`allowedFiles\`, prefer \`delegate_workers\`.
- If a delegated task comes back escalated or blocked, handle the decision on the current model instead of retrying blindly.
- Treat successful bounded worker handoffs with passing validation and no boundary violations as trusted building blocks by default.
- After a successful worker handoff with multiple edit locations, prefer one \`ctx_batch_execute\` inspection pass over serial \`read\` calls; use \`read\` only for one exact excerpt or a direct edit target.
- Chain additional bounded worker tasks when needed; do not reflexively run \`review_changes\` after each successful sub-step.
- Prefer a single review pass once you believe the overall user request is implemented, unless the user explicitly asked for an interim review, a worker escalated/blocked, validation failed, or you are checking risky supervisor-owned integration.${strictSection}`
        : `

## Delegation Policy

- Automatic delegation is disabled.
- Do not proactively use \`delegate_scout\` or \`delegate_worker\`.
- Use \`delegate_scout\` only when you explicitly decide a read-only reconnaissance task should be delegated.
- Use \`delegate_worker\` only when the user explicitly asks for delegation or when you explicitly decide a bounded local implementation task should be delegated.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model.
- If you delegate, provide explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers.
- When delegations succeed with clean validation, trust them enough to continue chaining bounded tasks; avoid repeated intermediate \`review_changes\` calls and prefer one final review near completion.`;

    const recentHandoffs = await buildRecentHandoffPrompt(ctx, event.prompt);

    return {
      systemPrompt: `${event.systemPrompt}${policy}${recentHandoffs ? `\n\n${recentHandoffs}` : ""}`,
    };
  });

  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName === "review_changes") {
      if (!event.isError && event.toolCallId) {
        const reviewKey = pendingReviewKeys.get(event.toolCallId);
        if (reviewKey) {
          recentReviewKeys = [
            reviewKey,
            ...recentReviewKeys.filter((item) => item !== reviewKey),
          ].slice(0, MAX_PERSISTED_REVIEW_KEYS);
          pi.appendEntry(REVIEW_STATE_ENTRY, { recentReviewKeys });
        }
      }
      if (event.toolCallId) {
        pendingReviewKeys.delete(event.toolCallId);
      }
    }

    if (!event.isError && turnDelegationState) {
      if (event.toolName === "delegate_worker") {
        const details = (event.details ?? {}) as { status?: string };
        if (details.status === "completed") {
          turnDelegationState.completedWorkerDelegations += 1;
        }
      } else if (event.toolName === "delegate_workers") {
        const details = (event.details ?? {}) as {
          results?: Array<{ status?: string }>;
        };
        turnDelegationState.completedWorkerDelegations +=
          details.results?.filter((result) => result.status === "completed").length ?? 0;
      } else if (event.toolName === "delegate_scout") {
        turnDelegationState.completedScoutDelegations += 1;
      } else if (event.toolName === "delegate_scouts") {
        const details = (event.details ?? {}) as {
          results?: Array<{ status?: string }>;
        };
        turnDelegationState.completedScoutDelegations +=
          details.results?.filter((result) => result.status === "completed").length ?? 0;
      } else if (event.toolName === "review_changes") {
        turnDelegationState.completedReviewDelegations += 1;
      }
    }

    if (event.isError) return;
    if (![
      "delegate_worker",
      "delegate_workers",
      "delegate_scout",
      "delegate_scouts",
      "review_changes",
    ].includes(event.toolName)) {
      return;
    }

    const details =
      event.details && typeof event.details === "object"
        ? (event.details as Record<string, unknown>)
        : {};
    const input =
      event.input && typeof event.input === "object"
        ? (event.input as Record<string, unknown>)
        : {};
    const report = extractTextContent(
      event.content as Array<{ type?: string; text?: string }> | undefined,
    );
    if (!report) return;

    const generatedAt =
      typeof details.generatedAt === "number" ? details.generatedAt : Date.now();
    const sessionKey =
      typeof details.sessionKey === "string"
        ? details.sessionKey
        : ctx.sessionManager.getSessionFile() ?? "ephemeral";
    const title = inferHandoffTitle(event.toolName, input, details);
    const actualReport = typeof details.fullReport === "string" ? details.fullReport : report;
    const status = inferHandoffStatus(event.toolName, actualReport, details);
    const filesChanged = collectHandoffFiles(details);
    const editLocations = collectHandoffEditLocations(details);
    const artifacts = collectHandoffArtifacts(details);
    const summary = summarizeHandoff(event.toolName, actualReport, details);
    const pointer: HandoffPointer = {
      source: buildHandoffSource(event.toolName, sessionKey, generatedAt, title),
      toolName: event.toolName,
      title,
      status,
      generatedAt,
      summary,
      filesChanged,
      editLocations,
      artifactSources: artifacts.sources,
      artifactQueries: artifacts.queries,
      artifactSummary: artifacts.summary,
    };
    const modelLabel = [details.workerModel, details.scoutModel, details.reviewer]
      .find((value): value is string => typeof value === "string" && value.trim().length > 0);
    const markdown = buildHandoffMarkdown({
      source: pointer.source,
      toolName: event.toolName,
      title,
      status,
      sessionKey,
      generatedAt,
      summary,
      filesChanged,
      editLocations,
      artifactSources: pointer.artifactSources,
      artifactQueries: pointer.artifactQueries,
      artifactSummary: pointer.artifactSummary,
      modelLabel,
      promptInput: input,
      details,
      report: actualReport,
    });
    const handoffIndexed = await indexHandoff(ctx, pointer, markdown);
    pointer.indexed = handoffIndexed;
    pi.appendEntry(HANDOFF_ENTRY, pointer);

    return {
      details: {
        ...details,
        handoffSource: pointer.source,
        handoffIndexed,
        handoffSummary: pointer.summary,
        handoffEditLocations: pointer.editLocations,
      },
    };
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "review_changes") {
      const reviewInput =
        event.input && typeof event.input === "object"
          ? (event.input as Record<string, unknown>)
          : {};
      const signature = await resolveReviewSignature(ctx.cwd, ctx.signal);
      const explicitReviewRequest = Boolean(
        turnDelegationState && userExplicitlyAskedForReview(turnDelegationState.prompt),
      );
      const reviewKey = signature
        ? buildReviewDedupeKey(signature, reviewInput)
        : undefined;
      const duplicatePending = Boolean(
        reviewKey && [...pendingReviewKeys.values()].includes(reviewKey),
      );
      const duplicateReviewed = Boolean(
        reviewKey && recentReviewKeys.includes(reviewKey),
      );
      const allowExplicitBypass = Boolean(
        reviewKey &&
          explicitReviewRequest &&
          turnDelegationState &&
          !turnDelegationState.usedExplicitReviewBypass &&
          !duplicatePending,
      );
      if (reviewKey && (duplicatePending || (duplicateReviewed && !allowExplicitBypass))) {
        return {
          block: true,
          reason:
            "review_changes is already pending or already ran for this exact working tree and review focus. Make additional changes, change the requested review focus, or answer the user instead of repeating the same review.",
        };
      }
      if (allowExplicitBypass && turnDelegationState) {
        turnDelegationState.usedExplicitReviewBypass = true;
      }
      if (reviewKey && event.toolCallId) {
        pendingReviewKeys.set(event.toolCallId, reviewKey);
      }
      if (
        turnDelegationState?.completedWorkerDelegations &&
        !turnDelegationState.nudgedReviewDeferral &&
        !explicitReviewRequest
      ) {
        turnDelegationState.nudgedReviewDeferral = true;
        if (ctx.hasUI) {
          ctx.ui.notify(
            "Recent worker handoffs are trusted by default; prefer one final review near completion instead of reviewing every successful sub-step.",
            "warning",
          );
        }
      }
    }

    if (turnDelegationState && turnDelegationState.completedWorkerDelegations > 0) {
      if (event.toolName === "read") {
        turnDelegationState.postHandoffReads += 1;
      } else if (
        event.toolName === "edit" ||
        event.toolName === "write" ||
        (event.toolName === "bash" && isMutatingBashCommand((event.input as { command?: unknown } | undefined)?.command))
      ) {
        turnDelegationState.postHandoffEdits += 1;
      }

      if (
        !turnDelegationState.nudgedExpensivePostHandoff &&
        (turnDelegationState.postHandoffReads >= 3 || turnDelegationState.postHandoffEdits >= 2)
      ) {
        turnDelegationState.nudgedExpensivePostHandoff = true;
        if (ctx.hasUI) {
          ctx.ui.notify(
            "This follow-up work still looks bounded; consider another delegate_worker to maintain scout-plan-implement separation.",
            "warning",
          );
        }
      }
    }

    if (!turnDelegationState?.enforcePlanSplit) return;
    if (turnDelegationState.completedWorkerDelegations > 0) return;
    if (turnDelegationState.nudgedDirectMutation) return;
    if (event.toolName === "delegate_worker" || event.toolName === "delegate_workers") return;

    const isDirectMutation =
      event.toolName === "edit" ||
      event.toolName === "write" ||
      (event.toolName === "bash" && isMutatingBashCommand((event.input as { command?: unknown } | undefined)?.command));

    if (!isDirectMutation) return;

    turnDelegationState.nudgedDirectMutation = true;
    if (ctx.hasUI) {
      ctx.ui.notify(
        "Worker-first plan split is active for this turn; consider delegate_worker before direct supervisor edits, especially for narrow follow-up fixes or file-scoped integration polish.",
        "warning",
      );
    }
  });

  pi.on("agent_end", async () => {
    turnDelegationState = undefined;
  });

  pi.registerTool({
    name: "delegate_scout",
    label: "Delegate Scout",
    description:
      "Spawn a read-only scout subagent on a cheaper model to explore the codebase, trace behavior, and report relevant files and findings back to the supervisor.",
    promptSnippet:
      "Delegate read-only reconnaissance to a cheaper scout subagent with explicit questions and expected outputs.",
    promptGuidelines: [
      "Use delegate_scout for read-only reconnaissance such as locating relevant files, tracing behavior, finding precedents, or narrowing the edit surface.",
      "Use delegate_scout before implementation when a cheap scout can gather evidence that improves planning or task scoping.",
      "Do not use delegate_scout for file mutations or tasks that should directly become implementation work.",
    ],
    parameters: DelegateScoutParams,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const delegationKey = `${sessionEpoch}:${toolCallId}`;
      const activeSessionEpoch = sessionEpoch;
      const isCurrentSession = () => activeSessionEpoch === sessionEpoch;
      activeDelegations.set(delegationKey, {
        id: delegationKey,
        title: formatTaskTitle(params.objective),
        workerModel:
          params.scoutModel?.trim() ||
          getEffectiveScoutRef(ctx, state)?.id ||
          "unresolved",
        phase: "starting",
        role: "scout",
      });
      updateDelegationWidget(ctx);
      emitSingleDelegationUpdate(onUpdate, activeDelegations.get(delegationKey));
      try {
        const effectiveParams = withInferredArtifacts(
          ctx,
          params,
          [params.objective, params.scope, ...(params.questions ?? [])].filter(Boolean).join("\n"),
        );
        const result = await generateScouting(
          ctx,
          state,
          effectiveParams,
          delegationKey,
          pi,
          isCurrentSession,
          signal,
          (text) => {
            if (!isCurrentSession()) {
              return;
            }
            const active = patchActiveDelegation(ctx, delegationKey, {
              phase: "running",
              workerModel: formatModel(
                params.scoutModel
                  ? parseModelRef(ctx, params.scoutModel)
                  : getEffectiveScoutRef(ctx, state),
                params.scoutThinkingLevel ?? getEffectiveScoutThinkingLevel(state),
              ),
            });
            recordDelegationDetail(delegationKey, text);
            emitSingleDelegationUpdate(onUpdate, active, text);
          },
          (progress) => {
            if (!isCurrentSession()) {
              return;
            }
            const active = patchActiveDelegation(ctx, delegationKey, {
              phase: "running",
              workerModel: formatModel(
                params.scoutModel
                  ? parseModelRef(ctx, params.scoutModel)
                  : getEffectiveScoutRef(ctx, state),
                params.scoutThinkingLevel ?? getEffectiveScoutThinkingLevel(state),
              ),
              turns: progress.turns,
              currentTool: progress.currentTool,
            });
            recordDelegationActivity(delegationKey, progress.lastActivityLine);
            emitSingleDelegationUpdate(onUpdate, active);
          },
        );
        if (isCurrentSession()) {
          patchActiveDelegation(ctx, delegationKey, {
            phase: "completed",
            workerModel: result.scoutModel,
            currentTool: undefined,
          });
        }
        const generatedAt = Date.now();
        const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
        pi.events.emit("subagent:metrics", {
          generatedAt,
          sessionKey,
          subagentMetrics: result.subagentMetrics,
          source: "tool",
        });
        return {
          content: [{ type: "text", text: result.report }],
          details: {
            generatedAt,
            sessionKey,
            scoutModel: result.scoutModel,
            status: result.status,
            artifactSources: result.artifactSources,
            artifactQueries: result.artifactQueries,
            artifactSummary: result.artifactSummary,
            subagentMetrics: result.subagentMetrics,
            stopReason: result.stopReason,
            errorMessage: result.errorMessage,
            fullReport: result.fullReport,
          },
        };
      } finally {
        if (isCurrentSession()) {
          activeDelegations.delete(delegationKey);
          updateDelegationWidget(ctx);
        }
      }
    },
  });

  pi.registerTool({
    name: "delegate_scouts",
    label: "Delegate Scouts",
    description:
      "Spawn several read-only scout subagents in parallel to explore different questions and report findings back to the supervisor.",
    promptSnippet:
      "Delegate multiple read-only reconnaissance tasks to parallel scout subagents with explicit questions and expected outputs.",
    promptGuidelines: [
      "Use delegate_scouts when several reconnaissance tasks are independent and can be explored in parallel.",
      "Use delegate_scouts for read-only work only; prefer delegate_scout for a single scouting task.",
      "Keep each scout task focused and concrete so the supervisor can merge the findings cleanly.",
    ],
    parameters: ParallelDelegateScoutsParams,
    async execute(
      toolCallId: string,
      params: { tasks: ParallelScoutTask[]; maxConcurrency?: number },
      signal: AbortSignal | undefined,
      onUpdate: ((update: any) => void) | undefined,
      ctx: ExtensionContext,
    ) {
      if (params.tasks.length === 0) {
        return {
          content: [{ type: "text", text: "No scout tasks were provided." }],
          details: { completedCount: 0, totalCount: 0, results: [] },
        };
      }
      if (params.tasks.length > MAX_PARALLEL_SUBAGENT_TASKS) {
        return {
          content: [{
            type: "text",
            text: `Too many parallel scout tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_SUBAGENT_TASKS}.`,
          }],
          details: { completedCount: 0, totalCount: params.tasks.length, results: [] },
        };
      }

      const concurrency = Math.max(
        1,
        Math.min(
          params.maxConcurrency ?? DEFAULT_PARALLEL_SUBAGENT_CONCURRENCY,
          MAX_PARALLEL_SUBAGENT_CONCURRENCY,
          params.tasks.length,
        ),
      );
      const activeSessionEpoch = sessionEpoch;
      const isCurrentSession = () => activeSessionEpoch === sessionEpoch;
      const partialResults = new Array<ParallelScoutTaskResult | undefined>(
        params.tasks.length,
      );

      const emitProgress = () => {
        const done = partialResults.filter(Boolean).length;
        const running = params.tasks.length - done;
        const activeItems = [...activeDelegations.values()]
          .filter((item) => item.id.startsWith(`${sessionEpoch}:${toolCallId}:`))
          .sort((left, right) => left.title.localeCompare(right.title));
        const lines = [
          `Parallel scouts: ${done}/${params.tasks.length} finished, ${running} running...`,
          ...activeItems.map((item) => `- ${item.title} · ${formatDelegationStatus(item)}`),
        ];
        if (running > 0 && activeItems.length === 0) {
          lines.push("- awaiting first subagent update...");
        }
        onUpdate?.({
          content: [{
            type: "text",
            text: lines.join("\n"),
          }],
          details: {
            completedCount: done,
            totalCount: params.tasks.length,
            activeDelegations: activeItems.map((item) => ({
              title: item.title,
              role: item.role,
              phase: item.phase,
              model: item.workerModel,
              turns: item.turns,
              currentTool: item.currentTool,
            })),
            results: partialResults.filter(
              (result): result is ParallelScoutTaskResult => Boolean(result),
            ),
          },
        });
      };

      emitProgress();

      const results = await mapWithConcurrencyLimit<
        ParallelScoutTask,
        ParallelScoutTaskResult
      >(
        params.tasks,
        concurrency,
        async (task, index) => {
          const label = formatParallelLabel(task.label, task.objective, index);
          const delegationKey = `${sessionEpoch}:${toolCallId}:${index}`;
          activeDelegations.set(delegationKey, {
            id: delegationKey,
            title: label,
            workerModel:
              task.scoutModel?.trim() ||
              getEffectiveScoutRef(ctx, state)?.id ||
              "unresolved",
            phase: "starting",
            role: "scout",
          });
          updateDelegationWidget(ctx);
          emitProgress();

          try {
            const effectiveTask = withInferredArtifacts(
              ctx,
              task,
              [task.objective, task.scope, ...(task.questions ?? [])].filter(Boolean).join("\n"),
            );
            const result = await generateScouting(
              ctx,
              state,
              effectiveTask,
              delegationKey,
              pi,
              isCurrentSession,
              signal,
              (text) => {
                if (!isCurrentSession()) return;
                patchActiveDelegation(ctx, delegationKey, {
                  phase: "running",
                  workerModel: resultScoutLabelFallback(ctx, state, task),
                });
                recordDelegationDetail(delegationKey, text);
                emitProgress();
              },
              (progress) => {
                if (!isCurrentSession()) return;
                patchActiveDelegation(ctx, delegationKey, {
                  phase: "running",
                  workerModel: resultScoutLabelFallback(ctx, state, task),
                  turns: progress.turns,
                  currentTool: progress.currentTool,
                });
                recordDelegationActivity(delegationKey, progress.lastActivityLine);
                emitProgress();
              },
            );
            const finalResult: ParallelScoutTaskResult = {
              ...result,
              label,
              status: "completed",
            };
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              patchActiveDelegation(ctx, delegationKey, {
                phase: finalResult.status,
                workerModel: finalResult.scoutModel,
                currentTool: undefined,
              });
            }
            emitProgress();
            return finalResult;
          } catch (error) {
            const finalResult = buildScoutFailureResult(
              label,
              resultScoutLabelFallback(ctx, state, task),
              error,
            );
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              patchActiveDelegation(ctx, delegationKey, {
                phase: finalResult.status,
                workerModel: finalResult.scoutModel,
                currentTool: undefined,
              });
            }
            emitProgress();
            return finalResult;
          } finally {
            if (isCurrentSession()) {
              activeDelegations.delete(delegationKey);
              updateDelegationWidget(ctx);
            }
          }
        },
      );

      const aggregateMetrics = aggregateSubagentMetrics(
        results.map((result) => result.subagentMetrics),
      );
      const generatedAt = Date.now();
      const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
      for (const result of results) {
        pi.events.emit("subagent:metrics", {
          generatedAt,
          sessionKey,
          subagentMetrics: result.subagentMetrics,
          source: "tool",
        });
      }
      pi.events.emit("subagent:metrics", {
        generatedAt,
        sessionKey,
        subagentMetrics: aggregateMetrics,
        source: "tool",
      });
      return {
        content: [{ type: "text", text: buildParallelScoutSummary(results) }],
        details: {
          generatedAt,
          sessionKey,
          subagentMetrics: aggregateMetrics,
          completedCount: results.filter((result) => result.status === "completed").length,
          totalCount: results.length,
          results,
        },
      };
    },
  });

  pi.registerTool({
    name: "delegate_workers",
    label: "Delegate Workers",
    description:
      "Spawn several bounded worker subagents in parallel to implement independent local tasks while the current model keeps planning and review decisions.",
    promptSnippet:
      "Delegate multiple bounded implementation tasks to parallel worker subagents when their file scopes are disjoint.",
    promptGuidelines: [
      "Use delegate_workers when several implementation tasks are independent and each task has explicit, disjoint allowedFiles.",
      "Require allowedFiles on every parallel worker task and avoid overlapping file or directory scopes.",
      "Prefer delegate_worker for a single implementation task or when task boundaries are ambiguous.",
    ],
    parameters: ParallelDelegateWorkersParams,
    async execute(
      toolCallId: string,
      params: { tasks: ParallelDelegateTask[]; maxConcurrency?: number },
      signal: AbortSignal | undefined,
      onUpdate: ((update: any) => void) | undefined,
      ctx: ExtensionContext,
    ) {
      if (params.tasks.length === 0) {
        return {
          content: [{ type: "text", text: "No worker tasks were provided." }],
          details: { status: "unknown", completedCount: 0, totalCount: 0, results: [] },
        };
      }
      if (params.tasks.length > MAX_PARALLEL_SUBAGENT_TASKS) {
        return {
          content: [{
            type: "text",
            text: `Too many parallel worker tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_SUBAGENT_TASKS}.`,
          }],
          details: { status: "blocked", completedCount: 0, totalCount: params.tasks.length, results: [] },
        };
      }

      const validationIssues = validateParallelWorkerTasks(ctx.cwd, params.tasks);
      if (validationIssues.length > 0) {
        return {
          content: [{
            type: "text",
            text: `Parallel worker delegation blocked:\n- ${validationIssues.join("\n- ")}`,
          }],
          details: { status: "blocked", completedCount: 0, totalCount: params.tasks.length, results: [] },
        };
      }

      const concurrency = Math.max(
        1,
        Math.min(
          params.maxConcurrency ?? DEFAULT_PARALLEL_SUBAGENT_CONCURRENCY,
          MAX_PARALLEL_SUBAGENT_CONCURRENCY,
          params.tasks.length,
        ),
      );
      const batchBeforeSnapshot = await snapshotWorkingTree(ctx.cwd, signal);
      const activeSessionEpoch = sessionEpoch;
      const isCurrentSession = () => activeSessionEpoch === sessionEpoch;
      const partialResults = new Array<ParallelDelegateTaskResult | undefined>(
        params.tasks.length,
      );

      const emitProgress = () => {
        const done = partialResults.filter(Boolean).length;
        const running = params.tasks.length - done;
        const finishedResults = partialResults.filter(
          (result): result is ParallelDelegateTaskResult => Boolean(result),
        );
        const activeItems = [...activeDelegations.values()]
          .filter((item) => item.id.startsWith(`${sessionEpoch}:${toolCallId}:`))
          .sort((left, right) => left.title.localeCompare(right.title));
        const lines = [
          `Parallel workers: ${done}/${params.tasks.length} finished, ${running} running...`,
          ...activeItems.map((item) => `- ${item.title} · ${formatDelegationStatus(item)}`),
        ];
        if (running > 0 && activeItems.length === 0) {
          lines.push("- awaiting first subagent update...");
        }
        onUpdate?.({
          content: [{
            type: "text",
            text: lines.join("\n"),
          }],
          details: {
            status: finishedResults.length > 0
              ? summarizeParallelWorkerStatus(finishedResults)
              : "unknown",
            completedCount: partialResults.filter(
              (result) => result?.status === "completed",
            ).length,
            totalCount: params.tasks.length,
            activeDelegations: activeItems.map((item) => ({
              title: item.title,
              role: item.role,
              phase: item.phase,
              model: item.workerModel,
              turns: item.turns,
              currentTool: item.currentTool,
            })),
            results: finishedResults,
          },
        });
      };

      emitProgress();

      const results = await mapWithConcurrencyLimit<
        ParallelDelegateTask,
        ParallelDelegateTaskResult
      >(
        params.tasks,
        concurrency,
        async (task, index) => {
          const label = formatParallelLabel(task.label, task.objective, index);
          const delegationKey = `${sessionEpoch}:${toolCallId}:${index}`;
          activeDelegations.set(delegationKey, {
            id: delegationKey,
            title: label,
            workerModel:
              task.workerModel?.trim() ||
              getEffectiveWorkerRef(ctx, state)?.id ||
              "unresolved",
            phase: "starting",
            role: "worker",
          });
          updateDelegationWidget(ctx);
          emitProgress();

          try {
            const effectiveTask = withInferredArtifacts(
              ctx,
              task,
              [task.objective, task.scope, ...(task.acceptanceCriteria ?? [])].filter(Boolean).join("\n"),
            );
            const result = await generateDelegation(
              ctx,
              state,
              effectiveTask,
              delegationKey,
              pi,
              isCurrentSession,
              signal,
              (text) => {
                if (!isCurrentSession()) return;
                patchActiveDelegation(ctx, delegationKey, {
                  phase: "running",
                  workerModel: resultWorkerLabelFallback(ctx, state, task),
                });
                recordDelegationDetail(delegationKey, text);
                emitProgress();
              },
              (progress) => {
                if (!isCurrentSession()) return;
                patchActiveDelegation(ctx, delegationKey, {
                  phase: "running",
                  workerModel: resultWorkerLabelFallback(ctx, state, task),
                  turns: progress.turns,
                  currentTool: progress.currentTool,
                });
                recordDelegationActivity(delegationKey, progress.lastActivityLine);
                emitProgress();
              },
            );
            const finalResult: ParallelDelegateTaskResult = {
              ...result,
              label,
            };
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              patchActiveDelegation(ctx, delegationKey, {
                phase: finalResult.status,
                workerModel: finalResult.workerModel,
                currentTool: undefined,
              });
            }
            emitProgress();
            return finalResult;
          } catch (error) {
            const finalResult = buildWorkerFailureResult(
              label,
              resultWorkerLabelFallback(ctx, state, task),
              error,
            );
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              patchActiveDelegation(ctx, delegationKey, {
                phase: finalResult.status,
                workerModel: finalResult.workerModel,
                currentTool: undefined,
              });
            }
            emitProgress();
            return finalResult;
          } finally {
            if (isCurrentSession()) {
              activeDelegations.delete(delegationKey);
              updateDelegationWidget(ctx);
            }
          }
        },
      );

      const batchAfterSnapshot = await snapshotWorkingTree(
        batchBeforeSnapshot.root,
        signal,
      );
      const finalized = finalizeParallelWorkerResults(
        ctx.cwd,
        batchBeforeSnapshot.root,
        params.tasks,
        results,
        diffSnapshots(batchBeforeSnapshot, batchAfterSnapshot),
      );
      const aggregateMetrics = aggregateSubagentMetrics(
        finalized.results.map((result) => result.subagentMetrics),
      );
      const generatedAt = Date.now();
      const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
      for (const result of finalized.results) {
        pi.events.emit("subagent:metrics", {
          generatedAt,
          sessionKey,
          subagentMetrics: result.subagentMetrics,
          source: "tool",
        });
      }
      pi.events.emit("subagent:metrics", {
        generatedAt,
        sessionKey,
        subagentMetrics: aggregateMetrics,
        source: "tool",
      });
      return {
        content: [{ type: "text", text: buildParallelWorkerSummary(finalized.results) }],
        details: {
          generatedAt,
          sessionKey,
          subagentMetrics: aggregateMetrics,
          status: summarizeParallelWorkerStatus(finalized.results),
          completedCount: finalized.results.filter((result) => result.status === "completed").length,
          totalCount: finalized.results.length,
          unownedFiles: finalized.unownedFiles,
          results: finalized.results,
        },
      };
    },
  });

  pi.registerTool({
    name: "delegate_worker",
    label: "Delegate Worker",
    description:
      "Spawn a bounded worker subagent on a cheaper model to implement a local task while the current model keeps planning, review, and escalation decisions.",
    promptSnippet:
      "Delegate a local, well-scoped implementation task to a cheaper worker subagent with explicit scope, acceptance criteria, validation, and escalation rules.",
    promptGuidelines: [
      "Use delegate_worker when the current model should stay responsible for planning, review, and escalation while a cheaper model handles a narrow implementation task.",
      "Use delegate_worker with explicit scope, allowed files, acceptance criteria, validation commands, and escalation triggers; keep the task small and independently checkable.",
      "Do not use delegate_worker for ambiguous architecture, security-sensitive decisions, or broad cross-cutting refactors unless the user explicitly wants that trade-off.",
    ],
    parameters: DelegateWorkerParams,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const delegationKey = `${sessionEpoch}:${toolCallId}`;
      const activeSessionEpoch = sessionEpoch;
      const isCurrentSession = () => activeSessionEpoch === sessionEpoch;
      activeDelegations.set(delegationKey, {
        id: delegationKey,
        title: formatTaskTitle(params.objective),
        workerModel:
          params.workerModel?.trim() ||
          getEffectiveWorkerRef(ctx, state)?.id ||
          "unresolved",
        phase: "starting",
        role: "worker",
      });
      updateDelegationWidget(ctx);
      emitSingleDelegationUpdate(onUpdate, activeDelegations.get(delegationKey));
      try {
        const effectiveParams = withInferredArtifacts(
          ctx,
          params,
          [params.objective, params.scope, ...(params.acceptanceCriteria ?? [])].filter(Boolean).join("\n"),
        );
        const result = await generateDelegation(
          ctx,
          state,
          effectiveParams,
          delegationKey,
          pi,
          isCurrentSession,
          signal,
          (text) => {
            if (!isCurrentSession()) {
              return;
            }
            const active = patchActiveDelegation(ctx, delegationKey, {
              phase: "running",
              workerModel: resultWorkerLabelFallback(
                ctx,
                state,
                params,
              ),
            });
            recordDelegationDetail(delegationKey, text);
            emitSingleDelegationUpdate(onUpdate, active, text);
          },
          (progress) => {
            if (!isCurrentSession()) {
              return;
            }
            const active = patchActiveDelegation(ctx, delegationKey, {
              phase: "running",
              workerModel: resultWorkerLabelFallback(
                ctx,
                state,
                params,
              ),
              turns: progress.turns,
              currentTool: progress.currentTool,
            });
            recordDelegationActivity(delegationKey, progress.lastActivityLine);
            emitSingleDelegationUpdate(onUpdate, active);
          },
        );
        if (isCurrentSession()) {
          patchActiveDelegation(ctx, delegationKey, {
            phase: result.status,
            workerModel: result.workerModel,
            currentTool: undefined,
          });
        }
        const generatedAt = Date.now();
        const sessionKey = ctx.sessionManager.getSessionFile() ?? "ephemeral";
        pi.events.emit("subagent:metrics", {
          generatedAt,
          sessionKey,
          subagentMetrics: result.subagentMetrics,
          source: "tool",
        });
        return {
          content: [{ type: "text", text: result.report }],
          details: {
            generatedAt,
            sessionKey,
            workerModel: result.workerModel,
            status: result.status,
            filesChanged: result.filesChanged,
            editLocations: result.editLocations,
            artifactSources: result.artifactSources,
            artifactQueries: result.artifactQueries,
            artifactSummary: result.artifactSummary,
            boundaryViolations: result.boundaryViolations,
            validation: result.validation,
            subagentMetrics: result.subagentMetrics,
            stopReason: result.stopReason,
            errorMessage: result.errorMessage,
            fullReport: result.fullReport,
          },
        };
      } finally {
        if (isCurrentSession()) {
          activeDelegations.delete(delegationKey);
          updateDelegationWidget(ctx);
        }
      }
    },
  });

  pi.registerCommand("worker-model", {
    description:
      "Show or set the default worker model for delegate_worker. Usage: /worker-model [default|model|provider/model] [thinking-level]",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (!trimmed) {
        const workerRef = getEffectiveWorkerRef(ctx, state);
        ctx.ui.notify(
          `Worker: ${formatModel(workerRef, getEffectiveThinkingLevel(state))}${state.override ? " (override)" : " (default)"}`,
          "info",
        );
        return;
      }

      const parts = trimmed.split(/\s+/).filter(Boolean);
      const modelArg = parts[0];
      const thinkingArg = parts[1] as ThinkingLevel | undefined;
      if (thinkingArg && !THINKING_LEVELS.includes(thinkingArg)) {
        ctx.ui.notify(`Unknown thinking level: ${thinkingArg}`, "error");
        return;
      }

      if (modelArg === "default") {
        const { override, thinkingLevel, ...rest } = state;
        state = {
          ...rest,
          thinkingLevel: thinkingArg ?? DEFAULT_WORKER_THINKING_LEVEL,
        };
        persistState();
        refreshStatus(ctx);
        ctx.ui.notify(
          `Worker reset to ${formatModel(getEffectiveWorkerRef(ctx, state), getEffectiveThinkingLevel(state))}`,
          "info",
        );
        return;
      }

      const requested = resolveRequestedModel(ctx, modelArg, "worker");
      if ("error" in requested) {
        ctx.ui.notify(requested.error, "error");
        return;
      }

      state = {
        ...state,
        override: requested.ref,
        thinkingLevel: thinkingArg ?? getEffectiveThinkingLevel(state),
      };
      persistState();
      refreshStatus(ctx);
      ctx.ui.notify(
        `Worker set to ${formatModel(requested.ref, getEffectiveThinkingLevel(state))}`,
        "info",
      );
    },
  });

  pi.registerCommand("scout-model", {
    description:
      "Show or set the default scout model for delegate_scout. Usage: /scout-model [default|model|provider/model] [thinking-level]",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (!trimmed) {
        const scoutRef = getEffectiveScoutRef(ctx, state);
        ctx.ui.notify(
          `Scout: ${formatModel(scoutRef, getEffectiveScoutThinkingLevel(state))}${state.scoutOverride ? " (override)" : " (default)"}`,
          "info",
        );
        return;
      }

      const parts = trimmed.split(/\s+/).filter(Boolean);
      const modelArg = parts[0];
      const thinkingArg = parts[1] as ThinkingLevel | undefined;
      if (thinkingArg && !THINKING_LEVELS.includes(thinkingArg)) {
        ctx.ui.notify(`Unknown thinking level: ${thinkingArg}`, "error");
        return;
      }

      if (modelArg === "default") {
        const { scoutOverride, scoutThinkingLevel, ...rest } = state;
        state = {
          ...rest,
          scoutThinkingLevel: thinkingArg ?? DEFAULT_SCOUT_THINKING_LEVEL,
        };
        persistState();
        refreshStatus(ctx);
        ctx.ui.notify(
          `Scout reset to ${formatModel(getEffectiveScoutRef(ctx, state), getEffectiveScoutThinkingLevel(state))}`,
          "info",
        );
        return;
      }

      const requested = resolveRequestedModel(ctx, modelArg, "scout");
      if ("error" in requested) {
        ctx.ui.notify(requested.error, "error");
        return;
      }

      state = {
        ...state,
        scoutOverride: requested.ref,
        scoutThinkingLevel: thinkingArg ?? getEffectiveScoutThinkingLevel(state),
      };
      persistState();
      refreshStatus(ctx);
      ctx.ui.notify(
        `Scout set to ${formatModel(requested.ref, getEffectiveScoutThinkingLevel(state))}`,
        "info",
      );
    },
  });

  pi.registerCommand("reviewer-model", {
    description:
      "Show or set the default interim reviewer model for review_changes. Usage: /reviewer-model [default|model|provider/model] [thinking-level]",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (!trimmed) {
        const reviewerRef = getEffectiveReviewerRef(ctx, state);
        ctx.ui.notify(
          `Reviewer: ${formatModel(reviewerRef, getEffectiveReviewerThinkingLevel(state))}${state.reviewerOverride ? " (override)" : " (default)"}`,
          "info",
        );
        return;
      }

      const parts = trimmed.split(/\s+/).filter(Boolean);
      const modelArg = parts[0];
      const thinkingArg = parts[1] as ThinkingLevel | undefined;
      if (thinkingArg && !THINKING_LEVELS.includes(thinkingArg)) {
        ctx.ui.notify(`Unknown thinking level: ${thinkingArg}`, "error");
        return;
      }

      if (modelArg === "default") {
        const { reviewerOverride, reviewerThinkingLevel, ...rest } = state;
        state = {
          ...rest,
          reviewerThinkingLevel: thinkingArg ?? DEFAULT_REVIEWER_THINKING_LEVEL,
        };
        persistState();
        refreshStatus(ctx);
        ctx.ui.notify(
          `Reviewer reset to ${formatModel(getEffectiveReviewerRef(ctx, state), getEffectiveReviewerThinkingLevel(state))}`,
          "info",
        );
        return;
      }

      const requested = resolveRequestedModel(ctx, modelArg, "reviewer");
      if ("error" in requested) {
        ctx.ui.notify(requested.error, "error");
        return;
      }

      state = {
        ...state,
        reviewerOverride: requested.ref,
        reviewerThinkingLevel: thinkingArg ?? getEffectiveReviewerThinkingLevel(state),
      };
      persistState();
      refreshStatus(ctx);
      ctx.ui.notify(
        `Reviewer set to ${formatModel(requested.ref, getEffectiveReviewerThinkingLevel(state))}`,
        "info",
      );
    },
  });

  pi.registerCommand("worker-auto", {
    description:
      "Show or set automatic delegation mode. Usage: /worker-auto [conservative|off]",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (!trimmed) {
        ctx.ui.notify(`Auto delegation: ${getAutoMode(state)}`, "info");
        return;
      }

      if (trimmed !== "conservative" && trimmed !== "off") {
        ctx.ui.notify("Usage: /worker-auto [conservative|off]", "error");
        return;
      }

      state = {
        ...state,
        autoMode: trimmed,
      };
      persistState();
      refreshStatus(ctx);
      ctx.ui.notify(`Auto delegation set to ${trimmed}`, "info");
    },
  });
}
