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
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { basename, join, relative, resolve } from "node:path";
import { createHash } from "node:crypto";
import {
  entryToMessage,
  getSessionMessages,
  textFromMessage,
  truncate,
} from "./lib/session-messages.ts";
import {
  findModel,
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
  autoMode?: "conservative" | "off";
}

interface ActiveDelegation {
  id: string;
  title: string;
  workerModel: string;
  phase: string;
  role: "worker" | "scout";
}

interface TurnDelegationState {
  prompt: string;
  enforcePlanSplit: boolean;
  completedWorkerDelegations: number;
  completedScoutDelegations: number;
  nudgedDirectMutation: boolean;
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
};

type DelegateStatus = "completed" | "escalated" | "blocked" | "unknown";

type ValidationOutcome = "pass" | "fail";

type ValidationResult = {
  command: string;
  outcome: ValidationOutcome;
  exitCode: number | null;
  note: string;
};

type DelegateResult = {
  report: string;
  workerModel: string;
  status: DelegateStatus;
  filesChanged: string[];
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
  scoutModel: string;
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
const DEFAULT_WORKER_PROVIDER = "github-copilot";
const DEFAULT_WORKER_MODEL_ID = "gemini-3-flash-preview";
const DEFAULT_WORKER_THINKING_LEVEL: ThinkingLevel = "minimal";
const DEFAULT_AUTO_MODE = "conservative" as const;
const MAX_CONTEXT_CHARS = 10_000;
const MAX_MESSAGES = 10;
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
const SUBAGENTS_WIDGET = new ManagedWidget("subagents", { placement: "belowEditor" });
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
const DEFAULT_SCOUT_TOOLS = [
  "read",
  "grep",
  "find",
  "ls",
  "ctx_search",
  "ctx_execute",
];
const SCOUT_SAFE_TOOLS = new Set(DEFAULT_SCOUT_TOOLS);
const SCOUT_BLOCKED_TOOLS = new Set([
  "edit",
  "write",
  "bash",
  "ctx_execute_file",
  "ctx_batch_execute",
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

Return exactly this Markdown structure:

## Status
- completed | escalated | blocked

## Summary
- concise bullets describing what you changed or why you stopped

## Files Changed
- one file per bullet
- If none: (none)

## Validation
- [command] - pass | fail | not run - brief note
- If none: (none)

## Escalation
- concrete blocker, risk, or question
- If none: (none)`;

const SCOUT_SYSTEM_PROMPT = `You are a scouting subagent inside pi.

Your job:
- Perform read-only reconnaissance for the supervisor.
- Explore the codebase, search for relevant files, trace behavior, and summarize evidence.
- Do not edit files, write files, or run mutating shell commands.
- Prefer concrete findings with file paths over speculation.
- Call out uncertainty clearly when evidence is incomplete.
- Recommend a practical next step for the supervisor.

Return exactly this Markdown structure:

## Summary
- concise bullets with the top findings

## Relevant Files
- one file per bullet
- If none: (none)

## Findings
- evidence with file paths and why it matters
- If none: (none)

## Recommended Next Step
- the best next action for the supervisor
- If none: (none)`;


function formatModel(ref?: ModelRef, thinkingLevel?: ThinkingLevel): string {
  if (!ref) return "none";
  return thinkingLevel && thinkingLevel !== "off"
    ? `${ref.provider}/${ref.id}:${thinkingLevel}`
    : `${ref.provider}/${ref.id}`;
}

function parseModelRef(
  raw: string,
  fallbackProvider?: string,
): ModelRef | undefined {
  const trimmed = raw.trim();
  if (!trimmed) return undefined;
  if (trimmed.includes("/")) {
    const [provider, ...rest] = trimmed.split("/");
    const id = rest.join("/").trim();
    if (!provider || !id) return undefined;
    return { provider: provider.trim(), id };
  }
  if (!fallbackProvider) return undefined;
  return { provider: fallbackProvider, id: trimmed };
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
  const autoMode = entry?.data?.autoMode;
  const nextState: SupervisorWorkerState = {};

  if (override?.provider && override?.id) {
    nextState.override = override;
  }
  if (thinkingLevel && THINKING_LEVELS.includes(thinkingLevel)) {
    nextState.thinkingLevel = thinkingLevel;
  }
  if (autoMode === "conservative" || autoMode === "off") {
    nextState.autoMode = autoMode;
  }

  return nextState.override || nextState.thinkingLevel || nextState.autoMode
    ? nextState
    : undefined;
}

function getDefaultWorkerRef(ctx: ExtensionContext): ModelRef | undefined {
  if (!ctx.model) return undefined;
  return {
    provider: DEFAULT_WORKER_PROVIDER,
    id: DEFAULT_WORKER_MODEL_ID,
  };
}

function getEffectiveWorkerRef(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
): ModelRef | undefined {
  return state.override ?? getDefaultWorkerRef(ctx);
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
    ? parseModelRef(params.workerModel, ctx.model?.provider)
    : getEffectiveWorkerRef(ctx, state);
  return formatModel(requestedRef, thinkingLevel);
}

function resultScoutLabelFallback(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
): string {
  const thinkingLevel =
    params.scoutThinkingLevel ?? getEffectiveThinkingLevel(state);
  const requestedRef = params.scoutModel
    ? parseModelRef(params.scoutModel, ctx.model?.provider)
    : getEffectiveWorkerRef(ctx, state);
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

function sanitizeScoutTools(tools: string[] | undefined): string[] {
  const requested = tools && tools.length > 0 ? tools : DEFAULT_SCOUT_TOOLS;
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

async function snapshotWorkingTree(
  cwd: string,
  signal?: AbortSignal,
): Promise<WorkingTreeSnapshot> {
  const repoRoot = await getGitRepoRoot(cwd, signal);
  const root = repoRoot ?? cwd;
  const relativeFiles = repoRoot
    ? await listGitFiles(repoRoot, signal)
    : await listFilesRecursive(root);
  const files = new Map<string, string>();

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

  const finalizedResults = results.map((result, index) => {
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
      status: baseStatus === "blocked" || hasValidationFailures || boundaryViolations.length > 0
        ? "blocked"
        : baseStatus,
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
  return {
    label,
    report: `## Status\n- blocked\n\n## Summary\n- ${message}\n\n## Files Changed\n- (none)\n\n## Validation\n- (none)\n\n## Escalation\n- ${message}`,
    workerModel,
    status: "blocked",
    filesChanged: [],
    boundaryViolations: [],
    validation: [],
    errorMessage: message,
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
  return {
    label,
    status: "blocked",
    report: `## Summary\n- ${message}\n\n## Relevant Files\n- (none)\n\n## Findings\n- (none)\n\n## Recommended Next Step\n- ${message}`,
    scoutModel,
    errorMessage: message,
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
    `## Allowed files\n${formatBullets(params.allowedFiles, "Any file needed within scope.")}`,
    `## Blocked files\n${formatBullets(params.blockedFiles)}`,
    `## Acceptance criteria\n${formatBullets(params.acceptanceCriteria)}`,
    `## Validation commands\n${formatBullets(params.validationCommands)}`,
    `## Escalation triggers\n${formatBullets(params.escalationTriggers)}`,
    `## Recent conversation context\n${conversationContext}`,
    `## Execution rules\n- Read nearby code when needed for context.\n- Only edit files that fit the scope.\n${hasAllowedFiles ? "- If you need to change files outside the allowed set, stop and escalate.\n" : ""}- Run the provided validation commands when possible after editing.\n- Prefer a minimal patch over a broad refactor.`,
  ].filter(Boolean);

  return sections.join("\n\n");
}

function buildScoutPrompt(
  params: ScoutParams,
  conversationContext: string,
): string {
  const sections = [
    `## Objective\n${params.objective.trim()}`,
    `## Scope\n${params.scope?.trim() || "Read-only reconnaissance only. Stay focused on the stated question."}`,
    `## Questions to answer\n${formatBullets(params.questions)}`,
    `## Expected outputs\n${formatBullets(params.expectedOutputs)}`,
    `## Recent conversation context\n${conversationContext}`,
    `## Execution rules\n- Use only read-only exploration.\n- Prefer path-backed findings and short evidence.\n- If the relevant answer depends on code changes, stop at recommendations rather than implementing them.`,
  ].filter(Boolean);

  return sections.join("\n\n");
}

async function runWorkerSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  auth: { apiKey?: string; headers?: Record<string, string> },
  tools: string[] | undefined,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
) {
  return await runSubagentProcess({
    cwd,
    prompt,
    modelArg,
    apiKey: auth.apiKey,
    providerName: modelArg.split("/", 1)[0],
    authHeaders: auth.headers,
    systemPrompt: WORKER_SYSTEM_PROMPT,
    extraArgs: [
      ...(tools && tools.length > 0 ? ["--tools", tools.join(",")] : []),
    ],
    env: {
      [WORKER_ENV_FLAG]: "worker",
    },
    signal,
    onUpdate,
  });
}

async function runScoutSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  auth: { apiKey?: string; headers?: Record<string, string> },
  tools: string[] | undefined,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
) {
  const scoutTools = sanitizeScoutTools(tools);
  return await runSubagentProcess({
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
  });
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

async function resolveWorkerSelection(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: DelegateParams,
): Promise<{ ref: ModelRef; model: Model<Api>; thinkingLevel: ThinkingLevel }> {
  const thinkingLevel =
    params.workerThinkingLevel ?? getEffectiveThinkingLevel(state);
  const requestedRef = params.workerModel
    ? parseModelRef(params.workerModel, ctx.model?.provider)
    : getEffectiveWorkerRef(ctx, state);
  if (!requestedRef) {
    throw new Error(
      "No worker model could be resolved. Select a model first or configure /worker-model.",
    );
  }

  const model = findModel(ctx, requestedRef);
  if (!model) {
    throw new Error(
      `Worker model not found: ${formatModel(requestedRef, thinkingLevel)}. Use provider/id form if needed.`,
    );
  }

  return { ref: requestedRef, model, thinkingLevel };
}

async function resolveScoutSelection(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
): Promise<{ ref: ModelRef; model: Model<Api>; thinkingLevel: ThinkingLevel }> {
  const thinkingLevel =
    params.scoutThinkingLevel ?? getEffectiveThinkingLevel(state);
  const requestedRef = params.scoutModel
    ? parseModelRef(params.scoutModel, ctx.model?.provider)
    : getEffectiveWorkerRef(ctx, state);
  if (!requestedRef) {
    throw new Error(
      "No scout model could be resolved. Select a model first or configure /worker-model.",
    );
  }

  const model = findModel(ctx, requestedRef);
  if (!model) {
    throw new Error(
      `Scout model not found: ${formatModel(requestedRef, thinkingLevel)}. Use provider/id form if needed.`,
    );
  }

  return { ref: requestedRef, model, thinkingLevel };
}

async function generateDelegation(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: DelegateParams,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
): Promise<DelegateResult> {
  if (!ctx.model) {
    throw new Error("No active supervisor model selected.");
  }

  const worker = await resolveWorkerSelection(ctx, state, params);
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(worker.model);
  if (!auth.ok) {
    throw new Error(`Unable to resolve auth for worker model: ${auth.error}`);
  }

  const cwd = params.cwd?.trim() || ctx.cwd;
  const beforeSnapshot = await snapshotWorkingTree(cwd, signal);
  const workerModelArg = formatModel(worker.ref, worker.thinkingLevel);
  const conversationContext = buildConversationContext(
    ctx.sessionManager.getBranch(),
  );
  const prompt = buildWorkerPrompt(params, conversationContext);
  const run = await runWorkerSubagent(
    cwd,
    prompt,
    workerModelArg,
    auth,
    params.tools,
    signal,
    onUpdate,
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

  return {
    report: `${final.text}${buildSupervisorAppendix(boundaryViolations, validation)}`,
    workerModel: workerModelArg,
    status,
    filesChanged: actualFilesChanged,
    boundaryViolations,
    validation,
    subagentMetrics: buildSubagentMetrics(run),
    stopReason: run.stopReason,
    errorMessage: final.errorMessage,
  };
}

async function generateScouting(
  ctx: ExtensionContext,
  state: SupervisorWorkerState,
  params: ScoutParams,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
): Promise<ScoutResult> {
  if (!ctx.model) {
    throw new Error("No active supervisor model selected.");
  }

  const scout = await resolveScoutSelection(ctx, state, params);
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(scout.model);
  if (!auth.ok) {
    throw new Error(`Unable to resolve auth for scout model: ${auth.error}`);
  }

  const cwd = params.cwd?.trim() || ctx.cwd;
  const scoutModelArg = formatModel(scout.ref, scout.thinkingLevel);
  const conversationContext = buildConversationContext(ctx.sessionManager.getBranch());
  const prompt = buildScoutPrompt(params, conversationContext);
  const run = await runScoutSubagent(cwd, prompt, scoutModelArg, auth, params.tools, signal, onUpdate);
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

  return {
    report: final.text,
    scoutModel: scoutModelArg,
    subagentMetrics: buildSubagentMetrics(run),
    stopReason: run.stopReason,
    errorMessage: final.errorMessage,
  };
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
    });
    return;
  }

  let state: SupervisorWorkerState = {};
  let sessionEpoch = 0;
  let turnDelegationState: TurnDelegationState | undefined;
  const activeDelegations = new Map<string, ActiveDelegation>();

  function persistState() {
    pi.appendEntry(STATE_ENTRY, state);
  }

  function updateDelegationWidget(ctx: ExtensionContext) {
    const items = [...activeDelegations.values()];
    if (items.length === 0) {
      SUBAGENTS_WIDGET.clear(ctx);
      return;
    }

    SUBAGENTS_WIDGET.set(ctx, [
      `Subagents (${items.length})`,
      ...items.map(
        (item) => `• ${item.role} ${item.workerModel} [${item.phase}] — ${item.title}`,
      ),
    ]);
  }

  function refreshStatus(ctx: ExtensionContext) {
    updateStatus(ctx, state);
    updateDelegationWidget(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionEpoch += 1;
    turnDelegationState = undefined;
    activeDelegations.clear();
    state = readSavedState(ctx) ?? {};
    refreshStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    sessionEpoch += 1;
    turnDelegationState = undefined;
    activeDelegations.clear();
    SUBAGENTS_WIDGET.clear(ctx);
    ctx.ui.setStatus("worker", undefined);
    ctx.ui.setStatus("worker-auto", undefined);
  });

  pi.on("model_select", async (_event, ctx) => {
    refreshStatus(ctx);
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
      nudgedDirectMutation: false,
    };

    const strictSection = shouldEnforcePlanSplit
      ? `
- Strict plan-implement split is active for this turn.
- Before making any direct file mutation with \`edit\`, \`write\`, or mutating \`bash\`, first break the work into a bounded implementation step and run \`delegate_worker\`.
- After at least one worker task completes, you may do small supervisor-side integration edits if still needed.
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
- Good scout candidates: file discovery, behavior tracing, implementation precedent searches, config inventory, and test surface mapping.
- Good auto-delegation candidates for workers: small code edits, focused tests, local refactors, narrow bug fixes, and file-scoped implementation work.
- Delegate only bounded work with explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model unless the user explicitly asks otherwise.
- Delegate one independently checkable task at a time by default.
- When multiple read-only scouting tasks are independent, prefer \`delegate_scouts\`.
- When multiple implementation tasks are independent and have disjoint \`allowedFiles\`, prefer \`delegate_workers\`.
- If a delegated task comes back escalated or blocked, handle the decision on the current model instead of retrying blindly.
- After a worker returns, review its result, enforce boundaries, and decide whether to continue, revise, or take over on the supervisor model.${strictSection}`
        : `

## Delegation Policy

- Automatic delegation is disabled.
- Do not proactively use \`delegate_scout\` or \`delegate_worker\`.
- Use \`delegate_scout\` only when you explicitly decide a read-only reconnaissance task should be delegated.
- Use \`delegate_worker\` only when the user explicitly asks for delegation or when you explicitly decide a bounded local implementation task should be delegated.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model.
- If you delegate, provide explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers, then review the result before proceeding.`;

    return {
      systemPrompt: `${event.systemPrompt}${policy}`,
    };
  });

  pi.on("tool_result", async (event) => {
    if (!turnDelegationState || event.isError) return;
    if (event.toolName === "delegate_worker") {
      const details = (event.details ?? {}) as { status?: string };
      if (details.status === "completed") {
        turnDelegationState.completedWorkerDelegations += 1;
      }
      return;
    }
    if (event.toolName === "delegate_workers") {
      const details = (event.details ?? {}) as {
        results?: Array<{ status?: string }>;
      };
      turnDelegationState.completedWorkerDelegations +=
        details.results?.filter((result) => result.status === "completed").length ?? 0;
      return;
    }
    if (event.toolName === "delegate_scout") {
      turnDelegationState.completedScoutDelegations += 1;
      return;
    }
    if (event.toolName === "delegate_scouts") {
      const details = (event.details ?? {}) as {
        results?: Array<{ status?: string }>;
      };
      turnDelegationState.completedScoutDelegations +=
        details.results?.filter((result) => result.status === "completed").length ?? 0;
    }
  });

  pi.on("tool_call", async (event, ctx) => {
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
        "Worker-first plan split is active for this turn; consider delegate_worker before direct supervisor edits.",
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
          getEffectiveWorkerRef(ctx, state)?.id ||
          DEFAULT_WORKER_MODEL_ID,
        phase: "starting",
        role: "scout",
      });
      updateDelegationWidget(ctx);
      onUpdate?.({
        content: [{ type: "text", text: "Starting scout subagent..." }],
      });
      try {
        const result = await generateScouting(ctx, state, params, signal, (text) => {
          if (!isCurrentSession()) {
            return;
          }
          const active = activeDelegations.get(delegationKey);
          if (active) {
            active.phase = "running";
            active.workerModel = formatModel(
              params.scoutModel
                ? parseModelRef(params.scoutModel, ctx.model?.provider)
                : getEffectiveWorkerRef(ctx, state),
              params.scoutThinkingLevel ?? getEffectiveThinkingLevel(state),
            );
            updateDelegationWidget(ctx);
          }
          onUpdate?.({ content: [{ type: "text", text }] });
        });
        if (isCurrentSession()) {
          const active = activeDelegations.get(delegationKey);
          if (active) {
            active.phase = "completed";
            active.workerModel = result.scoutModel;
            updateDelegationWidget(ctx);
          }
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
            subagentMetrics: result.subagentMetrics,
            stopReason: result.stopReason,
            errorMessage: result.errorMessage,
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
        onUpdate?.({
          content: [{
            type: "text",
            text: `Parallel scouts: ${done}/${params.tasks.length} finished, ${running} running...`,
          }],
          details: {
            completedCount: done,
            totalCount: params.tasks.length,
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
              getEffectiveWorkerRef(ctx, state)?.id ||
              DEFAULT_WORKER_MODEL_ID,
            phase: "starting",
            role: "scout",
          });
          updateDelegationWidget(ctx);
          emitProgress();

          try {
            const result = await generateScouting(
              ctx,
              state,
              task,
              signal,
              () => {
                if (!isCurrentSession()) return;
                const active = activeDelegations.get(delegationKey);
                if (active) {
                  active.phase = "running";
                  active.workerModel = resultScoutLabelFallback(ctx, state, task);
                  updateDelegationWidget(ctx);
                }
              },
            );
            const finalResult: ParallelScoutTaskResult = {
              ...result,
              label,
              status: "completed",
            };
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              const active = activeDelegations.get(delegationKey);
              if (active) {
                active.phase = finalResult.status;
                active.workerModel = finalResult.scoutModel;
                updateDelegationWidget(ctx);
              }
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
              const active = activeDelegations.get(delegationKey);
              if (active) {
                active.phase = finalResult.status;
                active.workerModel = finalResult.scoutModel;
                updateDelegationWidget(ctx);
              }
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
        onUpdate?.({
          content: [{
            type: "text",
            text: `Parallel workers: ${done}/${params.tasks.length} finished, ${running} running...`,
          }],
          details: {
            status: finishedResults.length > 0
              ? summarizeParallelWorkerStatus(finishedResults)
              : "unknown",
            completedCount: partialResults.filter(
              (result) => result?.status === "completed",
            ).length,
            totalCount: params.tasks.length,
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
              DEFAULT_WORKER_MODEL_ID,
            phase: "starting",
            role: "worker",
          });
          updateDelegationWidget(ctx);
          emitProgress();

          try {
            const result = await generateDelegation(
              ctx,
              state,
              task,
              signal,
              () => {
                if (!isCurrentSession()) return;
                const active = activeDelegations.get(delegationKey);
                if (active) {
                  active.phase = "running";
                  active.workerModel = resultWorkerLabelFallback(ctx, state, task);
                  updateDelegationWidget(ctx);
                }
              },
            );
            const finalResult: ParallelDelegateTaskResult = {
              ...result,
              label,
            };
            partialResults[index] = finalResult;
            if (isCurrentSession()) {
              const active = activeDelegations.get(delegationKey);
              if (active) {
                active.phase = finalResult.status;
                active.workerModel = finalResult.workerModel;
                updateDelegationWidget(ctx);
              }
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
              const active = activeDelegations.get(delegationKey);
              if (active) {
                active.phase = finalResult.status;
                active.workerModel = finalResult.workerModel;
                updateDelegationWidget(ctx);
              }
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
          DEFAULT_WORKER_MODEL_ID,
        phase: "starting",
        role: "worker",
      });
      updateDelegationWidget(ctx);
      onUpdate?.({
        content: [{ type: "text", text: "Starting worker subagent..." }],
      });
      try {
        const result = await generateDelegation(
          ctx,
          state,
          params,
          signal,
          (text) => {
            if (!isCurrentSession()) {
              return;
            }
            const active = activeDelegations.get(delegationKey);
            if (active) {
              active.phase = "running";
              active.workerModel = resultWorkerLabelFallback(
                ctx,
                state,
                params,
              );
              updateDelegationWidget(ctx);
            }
            onUpdate?.({ content: [{ type: "text", text }] });
          },
        );
        if (isCurrentSession()) {
          const active = activeDelegations.get(delegationKey);
          if (active) {
            active.phase = result.status;
            active.workerModel = result.workerModel;
            updateDelegationWidget(ctx);
          }
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
            boundaryViolations: result.boundaryViolations,
            validation: result.validation,
            subagentMetrics: result.subagentMetrics,
            stopReason: result.stopReason,
            errorMessage: result.errorMessage,
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
        state = {
          autoMode: getAutoMode(state),
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

      const ref = parseModelRef(modelArg, ctx.model?.provider);
      if (!ref) {
        ctx.ui.notify(
          "Unable to parse worker model. Use model or provider/model.",
          "error",
        );
        return;
      }
      const model = findModel(ctx, ref);
      if (!model) {
        ctx.ui.notify(
          `Worker model not found: ${formatModel(ref, thinkingArg)}`,
          "error",
        );
        return;
      }

      state = {
        autoMode: getAutoMode(state),
        override: ref,
        thinkingLevel: thinkingArg ?? getEffectiveThinkingLevel(state),
      };
      persistState();
      refreshStatus(ctx);
      ctx.ui.notify(
        `Worker set to ${formatModel(ref, getEffectiveThinkingLevel(state))}`,
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
