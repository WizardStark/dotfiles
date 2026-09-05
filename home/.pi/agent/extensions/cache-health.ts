import { homedir } from "node:os";
import { join } from "node:path";
import { promises as fs } from "node:fs";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createStatuslineItem, getStatuslineSessionKey } from "./statusline/registry";

// These are intentionally conservative: a million cache-read tokens is material, but a
// read without a write is not itself evidence of a cache miss or provider fault.
const CACHE_READ_WARNING_TOKENS = 1_000_000;
// A 25k-token floor excludes routine prompts, while a sub-10% hit rate catches the
// observed 0%/4.8%/6.6% large prompts. A prior cache read establishes that cache reuse
// was available; excluding cache writes avoids treating an actively priming response as
// evidence of degraded reuse.
const LOW_HIT_MIN_PROMPT_TOKENS = 25_000;
const LOW_HIT_RATIO = 0.1;
const TOKEN_MISMATCH_TOLERANCE = 1;
const MATERIAL_COST_TOLERANCE_USD = 0.01;
const MATERIAL_COST_TOLERANCE_RATIO = 0.05;
const LEDGER_PATH = join(homedir(), ".pi", "agent", "cache-health-ledger.jsonl");
const STATUS_KEY = "cache-health";

type NumericUsage = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

type CacheHealthState = {
  responses: number;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  responseCost: number;
  cacheReadResponses: number;
  cacheWriteResponses: number;
  cacheMissResponses: number;
  lowHitLargePromptResponses: number;
  readSinceWrite: number;
  warningActive: boolean;
  warningShown: boolean;
  lastLowHit: boolean;
  lastPromptTokens: number;
  lastHitRatio: number;
  lastClassification: "normal" | "priming" | "anomaly";
  lastModel?: string;
  lastTimestamp?: string;
};

type LedgerRecord = {
  timestamp: string;
  sessionId: string;
  sessionPath: string | null;
  provider: string;
  model: string;
  usage: NumericUsage;
  responseCost: number | null;
};

type ReconcileAggregate = {
  date: string;
  model: string;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  grossCost: number;
  inputRows: number;
  outputRows: number;
  cacheReadRows: number;
  cacheWriteRows: number;
  grossRows: number;
  invalidFields: number;
};

type CsvRow = {
  date?: string;
  model?: string;
  input?: number;
  output?: number;
  cacheRead?: number;
  cacheWrite?: number;
  grossCost?: number;
  invalidFields: number;
};

const statuslineItem = createStatuslineItem({
  id: STATUS_KEY,
  side: "right",
  order: 30,
  importance: 80,
  background: "toolPendingBg",
});

function numeric(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : undefined;
}

function usageFrom(message: AssistantMessage): NumericUsage | undefined {
  const usage = message.usage as Partial<NumericUsage> | undefined;
  const input = numeric(usage?.input);
  const output = numeric(usage?.output);
  const cacheRead = numeric(usage?.cacheRead);
  const cacheWrite = numeric(usage?.cacheWrite);
  if (input === undefined || output === undefined || cacheRead === undefined || cacheWrite === undefined) {
    return undefined;
  }
  return { input, output, cacheRead, cacheWrite };
}

function responseCost(message: AssistantMessage): number | null {
  const value = numeric(message.usage?.cost?.total);
  return value ?? null;
}

function formatTokens(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(2)}m`;
  if (value >= 100_000) return `${Math.round(value / 1_000)}k`;
  if (value >= 10_000) return `${(value / 1_000).toFixed(1)}k`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(2)}k`;
  return String(Math.round(value));
}

function formatUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

function responseTimestamp(message: AssistantMessage): string {
  const date = new Date(message.timestamp || Date.now());
  return Number.isFinite(date.getTime()) ? date.toISOString() : new Date().toISOString();
}

function localDate(timestamp: string | number): string | undefined {
  const date = typeof timestamp === "number" ? new Date(timestamp) : new Date(timestamp);
  if (!Number.isFinite(date.getTime())) return undefined;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function normalizedModel(value: string): string {
  return value
    .toLowerCase()
    .replace(/\b(copilot|model)\b/g, "")
    .replace(/[^a-z0-9]+/g, "");
}

function messageKey(message: AssistantMessage): string {
  const usage = usageFrom(message);
  return [
    message.responseId ?? "",
    message.timestamp,
    message.provider,
    message.model,
    usage?.input,
    usage?.output,
    usage?.cacheRead,
    usage?.cacheWrite,
  ].join("|");
}

function emptyState(): CacheHealthState {
  return {
    responses: 0,
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    responseCost: 0,
    cacheReadResponses: 0,
    cacheWriteResponses: 0,
    cacheMissResponses: 0,
    lowHitLargePromptResponses: 0,
    readSinceWrite: 0,
    warningActive: false,
    warningShown: false,
    lastLowHit: false,
    lastPromptTokens: 0,
    lastHitRatio: 0,
    lastClassification: "normal",
  };
}

function isLowHitLargePrompt(state: CacheHealthState, usage: NumericUsage): boolean {
  const promptTokens = usage.input + usage.cacheRead;
  return (
    state.cacheRead > 0 &&
    promptTokens >= LOW_HIT_MIN_PROMPT_TOKENS &&
    usage.cacheWrite === 0 &&
    usage.cacheRead / promptTokens < LOW_HIT_RATIO
  );
}

function classify(state: CacheHealthState, usage: NumericUsage): "normal" | "priming" | "anomaly" {
  if (state.warningActive || state.lastLowHit) return "anomaly";
  if (usage.cacheWrite > 0) return "priming";
  return "normal";
}

function updateState(
  state: CacheHealthState,
  usage: NumericUsage,
  message: AssistantMessage,
): { newlyWarned: boolean; lowHit: boolean } {
  const lowHit = isLowHitLargePrompt(state, usage);
  state.responses++;
  state.input += usage.input;
  state.output += usage.output;
  state.cacheRead += usage.cacheRead;
  state.cacheWrite += usage.cacheWrite;
  state.responseCost += responseCost(message) ?? 0;
  if (usage.cacheRead > 0) state.cacheReadResponses++;
  if (usage.cacheWrite > 0) state.cacheWriteResponses++;
  if (usage.cacheRead === 0 && usage.cacheWrite === 0) state.cacheMissResponses++;

  state.lastPromptTokens = usage.input + usage.cacheRead;
  state.lastHitRatio = state.lastPromptTokens > 0 ? usage.cacheRead / state.lastPromptTokens : 0;
  state.lastLowHit = lowHit;
  if (lowHit) state.lowHitLargePromptResponses++;

  if (usage.cacheWrite > 0) {
    state.readSinceWrite = 0;
    state.warningActive = false;
    state.warningShown = false;
  } else {
    state.readSinceWrite += usage.cacheRead;
  }

  const newlyWarned =
    state.cacheWrite === 0 && state.readSinceWrite >= CACHE_READ_WARNING_TOKENS && !state.warningShown;
  if (newlyWarned) {
    state.warningActive = true;
    state.warningShown = true;
  }
  state.lastClassification = classify(state, usage);
  state.lastModel = message.model;
  state.lastTimestamp = responseTimestamp(message);
  return { newlyWarned, lowHit: state.lastLowHit };
}

function sessionIdentity(ctx: ExtensionContext) {
  return {
    id: ctx.sessionManager.getSessionId(),
    path: ctx.sessionManager.getSessionFile() ?? null,
  };
}

async function appendLedger(record: LedgerRecord): Promise<void> {
  const directory = join(homedir(), ".pi", "agent");
  await fs.mkdir(directory, { recursive: true, mode: 0o700 });
  const handle = await fs.open(LEDGER_PATH, "a", 0o600);
  try {
    await handle.writeFile(`${JSON.stringify(record)}\n`, "utf8");
  } finally {
    await handle.close();
  }
}

function renderStatus(ctx: ExtensionContext, state: CacheHealthState) {
  if (!ctx.hasUI) return;
  const theme = ctx.ui.theme;
  const key = getStatuslineSessionKey(ctx);
  if (state.lastClassification === "anomaly") {
    const lowHitDetail = state.lastLowHit ? `hit ${(state.lastHitRatio * 100).toFixed(1)}%` : undefined;
    const noWriteDetail = state.warningActive ? `read ${formatTokens(state.readSinceWrite)} without writes` : undefined;
    const detail = [lowHitDetail, noWriteDetail].filter(Boolean).join(" · ");
    statuslineItem.set(
      {
        content: theme.fg("warning", `⚠ Cache anomaly · ${detail}`),
        compactContent: theme.fg("warning", `⚠ Cache anomaly ${detail}`),
      },
      key,
    );
  } else if (state.lastClassification === "priming") {
    statuslineItem.set(
      {
        content: theme.fg("accent", `↗ Cache priming · write ${formatTokens(state.cacheWrite)}`),
        compactContent: theme.fg("accent", "↗ Cache priming"),
      },
      key,
    );
  } else {
    statuslineItem.set(
      {
        content: theme.fg("dim", "✓ Cache normal"),
        compactContent: theme.fg("dim", "✓ Cache normal"),
      },
      key,
    );
  }
}

function warningText(state: CacheHealthState): string {
  return `Cache-write telemetry/billing anomaly: ${formatTokens(state.readSinceWrite)} cache-read tokens with no cache writes. This is not proof of a cache miss. Run /cache-health for session evidence.`;
}

function lowHitWarningText(state: CacheHealthState): string {
  return `Low cache-hit telemetry: ${(state.lastHitRatio * 100).toFixed(1)}% of a ${formatTokens(state.lastPromptTokens)}-token prompt was cache-read. This is telemetry evidence, not proof of a provider fault. Run /cache-health for session evidence.`;
}

function notify(ctx: ExtensionContext, message: string, level: "info" | "warning" | "error" = "info") {
  if (ctx.hasUI) ctx.ui.notify(message, level);
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"' && field.length === 0) {
      quoted = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field.replace(/\r$/, ""));
      if (row.some((value) => value.trim() !== "")) rows.push(row);
      row = [];
      field = "";
    } else {
      field += char;
    }
  }
  if (field !== "" || row.length > 0) {
    row.push(field.replace(/\r$/, ""));
    if (row.some((value) => value.trim() !== "")) rows.push(row);
  }
  return rows;
}

function headerIndex(headers: string[], names: string[]): number {
  const normalized = headers.map((header) => header.toLowerCase().replace(/[^a-z0-9]/g, ""));
  return normalized.findIndex((header) => names.includes(header));
}

function csvNumber(value: string | undefined, allowNegative = false): number | undefined {
  if (value === undefined || value.trim() === "") return undefined;
  const parsed = Number(value.replace(/,/g, "").trim());
  if (!Number.isFinite(parsed) || (!allowNegative && parsed < 0)) return undefined;
  return parsed;
}

function parseCsvRows(text: string): CsvRow[] {
  const rows = parseCsv(text);
  if (rows.length < 1) return [];
  const headers = rows[0]!;
  const indexes = {
    date: headerIndex(headers, ["date", "usagedate", "timestamp"]),
    model: headerIndex(headers, ["model", "modelname"]),
    input: headerIndex(headers, ["input", "inputtokens"]),
    output: headerIndex(headers, ["output", "outputtokens"]),
    cacheRead: headerIndex(headers, ["cacheread", "cachereadtokens"]),
    cacheWrite: headerIndex(headers, ["cachewrite", "cachewritetokens"]),
    grossCost: headerIndex(headers, ["grossamount", "grosscost", "gross"]),
  };
  return rows.slice(1).map((row) => {
    let invalidFields = 0;
    const dateValue = indexes.date >= 0 ? row[indexes.date]?.trim() : undefined;
    const model = indexes.model >= 0 ? row[indexes.model]?.trim() : undefined;
    const date = dateValue ? (dateValue.length === 10 ? localDate(`${dateValue}T00:00:00`) : localDate(dateValue)) : undefined;
    const parsed = (index: number, allowNegative = false) => {
      if (index < 0) {
        invalidFields++;
        return undefined;
      }
      const raw = row[index];
      const value = csvNumber(raw, allowNegative);
      if (raw === undefined || (raw.trim() !== "" && value === undefined)) invalidFields++;
      return value;
    };
    if (!date) invalidFields++;
    if (!model) invalidFields++;
    return {
      date,
      model,
      input: parsed(indexes.input),
      output: parsed(indexes.output),
      cacheRead: parsed(indexes.cacheRead),
      cacheWrite: parsed(indexes.cacheWrite),
      grossCost: parsed(indexes.grossCost, true),
      invalidFields,
    };
  });
}

function aggregate(map: Map<string, ReconcileAggregate>, date: string, model: string, row: CsvRow | LedgerRecord, source: "csv" | "ledger") {
  const key = `${date}|${normalizedModel(model)}`;
  if (!normalizedModel(model)) return;
  let item = map.get(key);
  if (!item) {
    item = {
      date,
      model,
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      grossCost: 0,
      inputRows: 0,
      outputRows: 0,
      cacheReadRows: 0,
      cacheWriteRows: 0,
      grossRows: 0,
      invalidFields: 0,
    };
    map.set(key, item);
  }
  item.invalidFields += "invalidFields" in row ? row.invalidFields : 0;
  const usage = "usage" in row ? row.usage : row;
  if (numeric(usage.input) !== undefined) {
    item.input += usage.input;
    item.inputRows++;
  }
  if (numeric(usage.output) !== undefined) {
    item.output += usage.output;
    item.outputRows++;
  }
  if (numeric(usage.cacheRead) !== undefined) {
    item.cacheRead += usage.cacheRead;
    item.cacheReadRows++;
  }
  if (numeric(usage.cacheWrite) !== undefined) {
    item.cacheWrite += usage.cacheWrite;
    item.cacheWriteRows++;
  }
  const cost = "responseCost" in row ? row.responseCost : row.grossCost;
  if (typeof cost === "number" && Number.isFinite(cost)) {
    item.grossCost += cost;
    item.grossRows++;
  }
  // Keep the parameter explicit so this remains easy to audit when the CSV schema grows.
  void source;
}

async function readLedger(): Promise<{ records: LedgerRecord[]; invalidLines: number }> {
  let text: string;
  try {
    text = await fs.readFile(LEDGER_PATH, "utf8");
  } catch {
    return { records: [], invalidLines: 0 };
  }
  const records: LedgerRecord[] = [];
  let invalidLines = 0;
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    try {
      const value = JSON.parse(line) as Partial<LedgerRecord>;
      const usage = value.usage as Partial<NumericUsage> | undefined;
      const timestamp = typeof value.timestamp === "string" ? value.timestamp : undefined;
      const provider = typeof value.provider === "string" ? value.provider : undefined;
      const model = typeof value.model === "string" ? value.model : undefined;
      const input = numeric(usage?.input);
      const output = numeric(usage?.output);
      const cacheRead = numeric(usage?.cacheRead);
      const cacheWrite = numeric(usage?.cacheWrite);
      if (!timestamp || !provider || !model || input === undefined || output === undefined || cacheRead === undefined || cacheWrite === undefined) {
        invalidLines++;
        continue;
      }
      records.push({
        timestamp,
        sessionId: typeof value.sessionId === "string" ? value.sessionId : "unknown",
        sessionPath: typeof value.sessionPath === "string" ? value.sessionPath : null,
        provider,
        model,
        usage: { input, output, cacheRead, cacheWrite },
        responseCost: numeric(value.responseCost) ?? null,
      });
    } catch {
      invalidLines++;
    }
  }
  return { records, invalidLines };
}

function dotenvLike(path: string): boolean {
  return /(^|[\\/])\.env(?:\.[^\\/]*)?(?:$|[\\/])/i.test(path);
}

function compareValues(label: string, left: number, right: number, warnings: string[]): string {
  const difference = left - right;
  if (Math.abs(difference) > TOKEN_MISMATCH_TOLERANCE) {
    warnings.push(`${label} mismatch (${formatTokens(Math.abs(difference))} tokens)`);
  }
  return `${label} ${formatTokens(left)} vs ${formatTokens(right)}`;
}

function buildReconcileReport(
  ledger: LedgerRecord[],
  csvRows: CsvRow[],
  invalidLedgerLines: number,
): string {
  const ledgerMap = new Map<string, ReconcileAggregate>();
  const csvMap = new Map<string, ReconcileAggregate>();
  for (const record of ledger) {
    const date = localDate(record.timestamp);
    if (date && record.provider === "github-copilot") aggregate(ledgerMap, date, record.model, record, "ledger");
  }
  for (const row of csvRows) {
    if (row.date && row.model) aggregate(csvMap, row.date, row.model, row, "csv");
  }

  const keys = [...new Set([...ledgerMap.keys(), ...csvMap.keys()])].sort();
  const lines = [`Cache reconciliation (local dates; ${keys.length} date/model groups)`];
  if (invalidLedgerLines > 0) lines.push(`Warning: ignored ${invalidLedgerLines} invalid ledger line(s).`);
  let warningCount = 0;
  for (const key of keys) {
    const pi = ledgerMap.get(key);
    const csv = csvMap.get(key);
    const warnings: string[] = [];
    const display = pi ?? csv!;
    lines.push(`${display.date} ${display.model}`);
    if (!pi) {
      warnings.push("no matching Pi ledger records");
    } else if (!csv) {
      warnings.push("no matching GitHub CSV records");
    } else {
      if (pi.inputRows > 0 && csv.inputRows > 0) lines.push(`  ${compareValues("input", pi.input, csv.input, warnings)}`);
      if (pi.outputRows > 0 && csv.outputRows > 0) lines.push(`  ${compareValues("output", pi.output, csv.output, warnings)}`);
      if (pi.cacheReadRows > 0 && csv.cacheReadRows > 0) lines.push(`  ${compareValues("cache-read", pi.cacheRead, csv.cacheRead, warnings)}`);
      if (pi.cacheWriteRows > 0 && csv.cacheWriteRows > 0) lines.push(`  ${compareValues("cache-write", pi.cacheWrite, csv.cacheWrite, warnings)}`);
      if (pi.grossRows > 0 && csv.grossRows > 0) {
        const difference = Math.abs(pi.grossCost - csv.grossCost);
        const material = Math.max(MATERIAL_COST_TOLERANCE_USD, Math.abs(csv.grossCost) * MATERIAL_COST_TOLERANCE_RATIO);
        lines.push(`  gross ${formatUsd(pi.grossCost)} recorded vs ${formatUsd(csv.grossCost)} CSV`);
        if (difference > material) warnings.push(`material gross-cost discrepancy (${formatUsd(difference)})`);
      }
      if (pi.invalidFields > 0 || csv.invalidFields > 0) warnings.push("missing or invalid fields were skipped");
    }
    for (const warning of warnings) lines.push(`  Warning: ${warning}`);
    warningCount += warnings.length;
  }
  lines.push(warningCount === 0 ? "No comparison warnings." : `${warningCount} warning(s); cost comparison uses recorded response cost vs CSV gross only.`);
  return lines.join("\n");
}

export default function cacheHealth(pi: ExtensionAPI) {
  let state = emptyState();
  let seen = new Set<string>();

  function resetFromBranch(ctx: ExtensionContext) {
    state = emptyState();
    seen = new Set<string>();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message" || entry.message.role !== "assistant") continue;
      const message = entry.message as AssistantMessage;
      if (message.provider !== "github-copilot") continue;
      const usage = usageFrom(message);
      if (!usage) continue;
      seen.add(messageKey(message));
      updateState(state, usage, message);
    }
  }

  pi.registerCommand("cache-health", {
    description: "Show prompt-free GitHub Copilot cache health for this session",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;
      const noWriteWarning = state.warningActive
        ? "ACTIVE: 1m cache-read/no-write telemetry anomaly (not proof of a cache miss)"
        : "clear";
      const lowHitWarning = state.lastLowHit
        ? `ACTIVE: last large prompt had ${(state.lastHitRatio * 100).toFixed(1)}% cache-hit ratio`
        : "clear";
      const promptTokens = state.input + state.cacheRead;
      const sessionHitRatio = promptTokens > 0 ? state.cacheRead / promptTokens : 0;
      notify(ctx, [
        "Cache health (GitHub Copilot)",
        `Responses: ${state.responses} · cache-read responses: ${state.cacheReadResponses} · cache-write responses: ${state.cacheWriteResponses} · zero-cache responses: ${state.cacheMissResponses}`,
        `Totals: input ${formatTokens(state.input)} · output ${formatTokens(state.output)} · cache-read ${formatTokens(state.cacheRead)} · cache-write ${formatTokens(state.cacheWrite)} · response cost ${formatUsd(state.responseCost)}`,
        `Session cache-hit ratio: ${(sessionHitRatio * 100).toFixed(1)}% · low-hit large-prompt responses: ${state.lowHitLargePromptResponses}`,
        `Read since last write: ${formatTokens(state.readSinceWrite)} · 1m no-write/read warning: ${noWriteWarning}`,
        `Last-response low-hit warning: ${lowHitWarning}`,
        `Last classification: ${state.lastClassification}${state.lastModel ? ` · ${state.lastModel}` : ""}`,
      ].join("\n"), state.warningActive || state.lastLowHit ? "warning" : "info");
    },
  });

  pi.registerCommand("cache-reconcile", {
    description: "Compare the prompt-free Copilot ledger with an explicit GitHub usage CSV path",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      const path = args.trim().replace(/^(\"|')(.*)\1$/, "$2");
      if (!path) {
        notify(ctx, "Usage: /cache-reconcile /explicit/path/to/usage.csv", "error");
        return;
      }
      if (dotenvLike(path)) {
        notify(ctx, "Refusing dotenv-like CSV paths.", "error");
        return;
      }
      let csvText: string;
      try {
        csvText = await fs.readFile(path, "utf8");
      } catch {
        notify(ctx, `Could not read CSV: ${path}`, "error");
        return;
      }
      const { records, invalidLines } = await readLedger();
      const report = buildReconcileReport(records, parseCsvRows(csvText), invalidLines);
      notify(ctx, report, report.includes("Warning:") ? "warning" : "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    resetFromBranch(ctx);
    renderStatus(ctx, state);
  });

  pi.on("message_end", async (event, ctx) => {
    if (event.message.role !== "assistant") return;
    const message = event.message as AssistantMessage;
    if (message.provider !== "github-copilot") return;
    const usage = usageFrom(message);
    if (!usage) return;
    const key = messageKey(message);
    if (seen.has(key)) return;
    seen.add(key);
    const { newlyWarned, lowHit } = updateState(state, usage, message);
    renderStatus(ctx, state);
    if (newlyWarned && lowHit) {
      notify(ctx, `${warningText(state)}\n${lowHitWarningText(state)}`, "warning");
    } else if (newlyWarned) {
      notify(ctx, warningText(state), "warning");
    } else if (lowHit) {
      notify(ctx, lowHitWarningText(state), "warning");
    }

    const identity = sessionIdentity(ctx);
    const timestamp = responseTimestamp(message);
    try {
      await appendLedger({
        timestamp,
        sessionId: identity.id,
        sessionPath: identity.path,
        provider: message.provider,
        model: message.model,
        usage,
        responseCost: responseCost(message),
      });
    } catch {
      notify(ctx, "Cache-health ledger could not be updated; cache counters remain in memory.", "warning");
    }
  });

  pi.on("session_tree", async (_event, ctx) => {
    resetFromBranch(ctx);
    renderStatus(ctx, state);
  });

  pi.on("session_compact", async (_event, ctx) => {
    resetFromBranch(ctx);
    renderStatus(ctx, state);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    statuslineItem.clear(getStatuslineSessionKey(ctx));
    state = emptyState();
    seen = new Set<string>();
  });
}
