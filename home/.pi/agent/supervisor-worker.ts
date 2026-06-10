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
  extractFinalAssistantText,
  runSubagentProcess,
} from "../lib/subagent-runtime";

interface ModelRef {
  provider: string;
  id: string;
}

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
  stopReason?: string;
  errorMessage?: string;
};

const STATE_ENTRY = "supervisor-worker-state";
const DEFAULT_WORKER_MODEL_ID = "gpt-5.4-mini";
const DEFAULT_WORKER_THINKING_LEVEL: ThinkingLevel = "minimal";
const DEFAULT_AUTO_MODE = "conservative" as const;
const MAX_CONTEXT_CHARS = 10_000;
const MAX_MESSAGES = 10;
const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
] as const;
const WORKER_ENV_FLAG = "PI_SUPERVISOR_WORKER_ROLE";

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

function toRef(model?: Model<Api>): ModelRef | undefined {
  if (!model) return undefined;
  return {
    provider: model.provider,
    id: model.id,
  };
}

function sameModel(a?: ModelRef, b?: ModelRef): boolean {
  return !!a && !!b && a.provider === b.provider && a.id === b.id;
}

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

function findModel(
  ctx: ExtensionContext,
  ref: ModelRef,
): Model<Api> | undefined {
  return ctx.modelRegistry.find(ref.provider, ref.id);
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
    provider: ctx.model.provider,
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

function updateStatus(ctx: ExtensionContext, state: SupervisorWorkerState) {
  const worker = getEffectiveWorkerRef(ctx, state);
  if (!worker) {
    ctx.ui.setStatus("worker", undefined);
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

function textFromMessage(message: AgentMessage): string {
  if (
    message.role === "assistant" ||
    message.role === "user" ||
    message.role === "system"
  ) {
    return (message.content ?? [])
      .map((part) => {
        if (part.type === "text") return part.text ?? "";
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

function getSessionMessages(branch: SessionEntry[]): AgentMessage[] {
  let compactionIndex = -1;
  for (let i = branch.length - 1; i >= 0; i--) {
    if (branch[i].type === "compaction") {
      compactionIndex = i;
      break;
    }
  }

  if (compactionIndex < 0) {
    return branch
      .map(entryToMessage)
      .filter((message): message is AgentMessage => message !== undefined);
  }

  const compaction = branch[compactionIndex];
  const firstKeptIndex =
    compaction.type === "compaction"
      ? branch.findIndex((entry) => entry.id === compaction.firstKeptEntryId)
      : -1;
  const compactedBranch = [
    compaction,
    ...(firstKeptIndex >= 0
      ? branch.slice(firstKeptIndex, compactionIndex)
      : []),
    ...branch.slice(compactionIndex + 1),
  ];

  return compactedBranch
    .map(entryToMessage)
    .filter((message): message is AgentMessage => message !== undefined);
}

function truncate(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n...[truncated ${text.length - maxChars} chars]`;
}

function singleLine(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function formatTaskTitle(text: string): string {
  const normalized = singleLine(text);
  return normalized.length > 72 ? `${normalized.slice(0, 69)}...` : normalized;
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

async function runWorkerSubagent(
  cwd: string,
  prompt: string,
  modelArg: string,
  apiKey: string | undefined,
  tools: string[] | undefined,
  signal?: AbortSignal,
  onUpdate?: (text: string) => void,
) {
  return await runSubagentProcess({
    cwd,
    prompt,
    modelArg,
    apiKey,
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
    auth.apiKey,
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
        "Worker model id or provider/id. Defaults to the configured worker model, or current-provider/gpt-5.4-mini.",
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

export default function supervisorWorkerExtension(pi: ExtensionAPI) {
  if (process.env[WORKER_ENV_FLAG] === "worker") {
    return;
  }

  let state: SupervisorWorkerState = {};
  let sessionEpoch = 0;
  const activeDelegations = new Map<string, ActiveDelegation>();

  function persistState() {
    pi.appendEntry(STATE_ENTRY, state);
  }

  function updateDelegationWidget(ctx: ExtensionContext) {
    const items = [...activeDelegations.values()];
    if (items.length === 0) {
      ctx.ui.setWidget("subagents", undefined);
      return;
    }

    ctx.ui.setWidget(
      "subagents",
      [
        `Subagents (${items.length})`,
        ...items.map(
          (item) => `• ${item.workerModel} [${item.phase}] — ${item.title}`,
        ),
      ],
      { placement: "belowEditor" },
    );
  }

  function refreshStatus(ctx: ExtensionContext) {
    updateStatus(ctx, state);
    updateDelegationWidget(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionEpoch += 1;
    activeDelegations.clear();
    state = readSavedState(ctx) ?? {};
    refreshStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    sessionEpoch += 1;
    activeDelegations.clear();
    ctx.ui.setWidget("subagents", undefined);
    ctx.ui.setStatus("worker", undefined);
    ctx.ui.setStatus("worker-auto", undefined);
  });

  pi.on("model_select", async (_event, ctx) => {
    refreshStatus(ctx);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    const workerRef = getEffectiveWorkerRef(ctx, state);
    if (!ctx.model || sameModel(toRef(ctx.model), workerRef)) {
      return;
    }

    const autoMode = getAutoMode(state);
    const policy =
      autoMode === "conservative"
        ? `

## Delegation Policy

- Conservative auto mode is enabled.
- For coding requests, proactively use \`delegate_worker\` without asking first when the next step is a bounded implementation task that is local, well-specified, and objectively checkable.
- Good auto-delegation candidates: small code edits, focused tests, local refactors, narrow bug fixes, and file-scoped implementation work.
- Delegate only bounded work with explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model unless the user explicitly asks otherwise.
- Delegate one independently checkable task at a time, then review the result before issuing the next delegation.
- If a delegated task comes back escalated or blocked, handle the decision on the current model instead of retrying blindly.
- After a worker returns, review its result, enforce boundaries, and decide whether to continue, revise, or take over on the supervisor model.`
        : `

## Delegation Policy

- Automatic delegation is disabled.
- Do not proactively use \`delegate_worker\`.
- Use \`delegate_worker\` only when the user explicitly asks for delegation or when you explicitly decide a bounded local implementation task should be delegated.
- Keep architecture, ambiguous debugging, security-sensitive decisions, migrations, and broad cross-cutting refactors on the current model.
- If you delegate, provide explicit scope, file boundaries, acceptance criteria, validation commands, and escalation triggers, then review the result before proceeding.`;

    return {
      systemPrompt: `${event.systemPrompt}${policy}`,
    };
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
        return {
          content: [{ type: "text", text: result.report }],
          details: {
            workerModel: result.workerModel,
            status: result.status,
            filesChanged: result.filesChanged,
            boundaryViolations: result.boundaryViolations,
            validation: result.validation,
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
