/**
 * Copy helper extension for pi.
 *
 * Commands:
 * - /copy-smart        -> copy the only fenced block, or prompt, or fall back to the full assistant message
 * - /copy-block        -> copy a specific fenced block from the last assistant message
 * - /copy-block 2      -> copy block #2
 * - /copy-block bash   -> copy the first/selected bash block
 *
 * Shortcut:
 * - Ctrl+Alt+Y         -> run the smart copy flow
 *
 * Clipboard backends:
 * - tmux: tmux load-buffer -w, then OSC52 via tmux passthrough fallback
 * - OSC52: direct write to /dev/tty when outside tmux over SSH or in likely-compatible local terminals
 * - macOS: pbcopy
 * - Linux: wl-copy, xclip, xsel
 * - WSL: powershell.exe / clip.exe fallback to the Windows clipboard
 * - Windows: powershell.exe, clip
 */
import { spawn, spawnSync } from "node:child_process";
import { closeSync, openSync, writeSync } from "node:fs";
import { release } from "node:os";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth, type TUI } from "@earendil-works/pi-tui";

type AssistantTextSource = {
  text: string;
  timestamp?: number;
};

type CodeBlock = {
  index: number;
  language?: string;
  code: string;
  preview: string;
  searchText: string;
  codeSearchText: string;
};

type CopyResult =
  | { ok: true; backend: string }
  | { ok: false; error: string };

type ClipboardBackend = {
  name: string;
  command: string;
  args: string[];
  supported?: () => boolean;
  timeoutMs?: number;
};

const CLIPBOARD_COMMAND_TIMEOUT_MS = 5000;
const BLOCK_PICKER_MAX_VISIBLE_ITEMS = 5;
const BLOCK_PICKER_OVERLAY_MAX_HEIGHT_RATIO = 0.85;

function extractAssistantText(messageContent: unknown): string {
  if (typeof messageContent === "string") {
    return messageContent;
  }

  if (!Array.isArray(messageContent)) {
    return "";
  }

  return messageContent
    .filter((part): part is { type: "text"; text: string } => {
      return !!part && typeof part === "object" && (part as { type?: unknown }).type === "text" && typeof (part as any).text === "string";
    })
    .map((part) => part.text)
    .join("");
}

function stripUpToIndent(line: string, indent: string): string {
  if (!indent) {
    return line;
  }

  let index = 0;
  let remaining = indent.length;
  while (index < line.length && remaining > 0) {
    const char = line[index];
    if (char !== " " && char !== "\t") {
      break;
    }
    index += 1;
    remaining -= 1;
  }

  return line.slice(index);
}

function getLastAssistantText(sessionManager: any): AssistantTextSource | undefined {
  const branch = sessionManager.getBranch();

  for (let i = branch.length - 1; i >= 0; i -= 1) {
    const entry = branch[i];
    if (entry?.type !== "message" || entry.message?.role !== "assistant") {
      continue;
    }

    const text = extractAssistantText(entry.message.content);
    if (!text.trim()) {
      continue;
    }

    return {
      text,
      timestamp: entry.message.timestamp,
    };
  }

  return undefined;
}

function summarizeCode(code: string): string {
  const firstMeaningfulLine = code
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0);

  if (!firstMeaningfulLine) {
    return "(empty block)";
  }

  return firstMeaningfulLine.length > 60 ? `${firstMeaningfulLine.slice(0, 57)}...` : firstMeaningfulLine;
}

function normalizeSearchText(value: string): string {
  return value.toLowerCase().replace(/\s+/g, " ").trim();
}

function buildBlockSearchText(language: string | undefined, preview: string, code: string): string {
  return normalizeSearchText([language ?? "", preview, code].join("\n"));
}

function buildCodeSearchText(code: string): string {
  return normalizeSearchText(code);
}

function extractCodeBlocks(text: string): CodeBlock[] {
  const lines = text.split("\n");
  const blocks: CodeBlock[] = [];

  for (let i = 0; i < lines.length; i += 1) {
    const openMatch = lines[i]?.match(/^([ \t]*)(`{3,}|~{3,})([^\n]*)$/);
    if (!openMatch) {
      continue;
    }

    const indent = openMatch[1] ?? "";
    const fence = openMatch[2] ?? "```";
    const fenceChar = fence[0] ?? "`";
    const minimumFenceLength = fence.length;
    const info = (openMatch[3] ?? "").trim();
    const closePattern = new RegExp(`^[ \\t]*${fenceChar}{${minimumFenceLength},}\\s*$`);
    const contentLines: string[] = [];

    let closeIndex = -1;
    for (let j = i + 1; j < lines.length; j += 1) {
      if (closePattern.test(lines[j] ?? "")) {
        closeIndex = j;
        break;
      }

      const line = lines[j] ?? "";
      contentLines.push(stripUpToIndent(line, indent));
    }

    if (closeIndex === -1) {
      continue;
    }

    const code = contentLines.join("\n");
    const language = info.split(/\s+/)[0] || undefined;
    const preview = summarizeCode(code);
    blocks.push({
      index: blocks.length + 1,
      language,
      code,
      preview,
      searchText: buildBlockSearchText(language, preview, code),
      codeSearchText: buildCodeSearchText(code),
    });
    i = closeIndex;
  }

  return blocks;
}

function getWindowsClipboardBackends(): ClipboardBackend[] {
  return [
    {
      name: "powershell Set-Clipboard",
      command: "powershell.exe",
      args: [
        "-NoProfile",
        "-Command",
        "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; $text=[Console]::In.ReadToEnd(); Set-Clipboard -Value $text",
      ],
    },
    { name: "clip", command: "clip", args: [] },
    { name: "clip.exe", command: "clip.exe", args: [] },
  ];
}

function isWsl(): boolean {
  return process.platform === "linux" && !!(process.env.WSL_DISTRO_NAME || process.env.WSL_INTEROP || /microsoft/i.test(release()));
}

function isWaylandSession(): boolean {
  return !!(process.env.WAYLAND_DISPLAY || process.env.XDG_SESSION_TYPE === "wayland");
}

function isX11Session(): boolean {
  return !!(process.env.DISPLAY || process.env.XDG_SESSION_TYPE === "x11");
}

function getClipboardBackends(): ClipboardBackend[] {
  switch (process.platform) {
    case "darwin":
      return [{ name: "pbcopy", command: "pbcopy", args: [] }];
    case "win32":
      return getWindowsClipboardBackends();
    default:
      return [
        ...(isWsl() ? getWindowsClipboardBackends() : []),
        {
          name: "wl-copy",
          command: "wl-copy",
          args: [],
          supported: isWaylandSession,
          timeoutMs: CLIPBOARD_COMMAND_TIMEOUT_MS,
        },
        {
          name: "xclip",
          command: "xclip",
          args: ["-selection", "clipboard", "-in", "-silent"],
          supported: isX11Session,
          timeoutMs: CLIPBOARD_COMMAND_TIMEOUT_MS,
        },
        {
          name: "xsel",
          command: "xsel",
          args: ["--clipboard", "--input"],
          supported: isX11Session,
          timeoutMs: CLIPBOARD_COMMAND_TIMEOUT_MS,
        },
      ];
  }
}

function isSshSession(): boolean {
  return !!(process.env.SSH_CONNECTION || process.env.SSH_CLIENT || process.env.SSH_TTY);
}

function likelySupportsOsc52(): boolean {
  const term = (process.env.TERM ?? "").toLowerCase();
  const termProgram = (process.env.TERM_PROGRAM ?? "").toLowerCase();

  return !!(
    process.env.KITTY_WINDOW_ID ||
    process.env.WEZTERM_EXECUTABLE ||
    process.env.GHOSTTY_RESOURCES_DIR ||
    process.env.ITERM_SESSION_ID ||
    process.env.VSCODE_GIT_IPC_HANDLE ||
    term.includes("kitty") ||
    term.includes("wezterm") ||
    term.includes("ghostty") ||
    term.includes("foot") ||
    term.includes("alacritty") ||
    termProgram.includes("kitty") ||
    termProgram.includes("wezterm") ||
    termProgram.includes("ghostty") ||
    termProgram.includes("iterm") ||
    termProgram.includes("vscode")
  );
}

function encodeOsc52(text: string): string {
  return `\u001b]52;c;${Buffer.from(text, "utf8").toString("base64")}\u0007`;
}

function encodeTmuxPassthrough(sequence: string): string {
  return `\u001bPtmux;${sequence.replace(/\u001b/g, "\u001b\u001b")}\u001b\\`;
}

function copyViaTmuxPassthrough(text: string): CopyResult {
  let fd: number | undefined;

  try {
    fd = openSync("/dev/tty", "w");
    writeSync(fd, encodeTmuxPassthrough(encodeOsc52(text)));
    return { ok: true, backend: "tmux passthrough OSC52" };
  } catch (error) {
    return { ok: false, error: `tmux passthrough: ${error instanceof Error ? error.message : String(error)}` };
  } finally {
    if (typeof fd === "number") {
      closeSync(fd);
    }
  }
}

function copyViaTmuxLoadBuffer(text: string): CopyResult {
  const result = spawnSync("tmux", ["load-buffer", "-w", "-"], {
    input: text,
    encoding: "utf8",
    windowsHide: true,
    timeout: CLIPBOARD_COMMAND_TIMEOUT_MS,
  });

  if (!result.error && result.status === 0) {
    return { ok: true, backend: "tmux load-buffer -w" };
  }

  const errorCode = (result.error as NodeJS.ErrnoException | undefined)?.code;
  if (errorCode === "ENOENT") {
    return { ok: false, error: "tmux load-buffer: not installed" };
  }

  if (errorCode === "ETIMEDOUT") {
    return { ok: false, error: "tmux load-buffer: timed out" };
  }

  const stderr = typeof result.stderr === "string" ? result.stderr.trim() : "";
  return { ok: false, error: `tmux load-buffer: ${result.error instanceof Error ? result.error.message : stderr || `exit ${result.status ?? "unknown"}`}` };
}

function copyViaOsc52(text: string): CopyResult {
  let fd: number | undefined;

  try {
    fd = openSync("/dev/tty", "w");
    writeSync(fd, encodeOsc52(text));
    return { ok: true, backend: "OSC52" };
  } catch (error) {
    return { ok: false, error: `OSC52: ${error instanceof Error ? error.message : String(error)}` };
  } finally {
    if (typeof fd === "number") {
      closeSync(fd);
    }
  }
}

function runWlCopyBackend(text: string, backend: ClipboardBackend): Promise<CopyResult> {
  if (backend.supported && !backend.supported()) {
    return Promise.resolve({ ok: false, error: `${backend.name}: skipped for this session type` });
  }

  return new Promise((resolve) => {
    let settled = false;
    let successTimer: NodeJS.Timeout | undefined;
    let watchdogTimer: NodeJS.Timeout | undefined;

    const finish = (result: CopyResult) => {
      if (settled) {
        return;
      }
      settled = true;
      if (successTimer) {
        clearTimeout(successTimer);
      }
      if (watchdogTimer) {
        clearTimeout(watchdogTimer);
      }
      resolve(result);
    };

    try {
      const child = spawn(backend.command, backend.args, {
        stdio: ["pipe", "ignore", "ignore"],
        windowsHide: true,
        detached: process.platform !== "win32",
      });

      watchdogTimer = setTimeout(() => {
        try {
          child.kill();
        } catch {
          // ignore kill errors from already-exited child processes
        }
        child.unref();
        finish({ ok: false, error: `${backend.name}: timed out` });
      }, backend.timeoutMs ?? CLIPBOARD_COMMAND_TIMEOUT_MS);

      child.once("error", (error) => {
        const errorCode = (error as NodeJS.ErrnoException).code;
        if (errorCode === "ENOENT") {
          finish({ ok: false, error: `${backend.name}: not installed` });
          return;
        }
        finish({ ok: false, error: `${backend.name}: ${error.message}` });
      });

      child.once("exit", (code, signal) => {
        if (code === 0) {
          finish({ ok: true, backend: backend.name });
          return;
        }
        finish({ ok: false, error: `${backend.name}: ${signal ? `signal ${signal}` : `exit ${code ?? "unknown"}`}` });
      });

      child.stdin.on("error", (error) => {
        finish({ ok: false, error: `${backend.name}: ${error.message}` });
      });

      child.stdin.end(text, "utf8", () => {
        successTimer = setTimeout(() => {
          child.unref();
          finish({ ok: true, backend: backend.name });
        }, 150);
      });
    } catch (error) {
      finish({ ok: false, error: `${backend.name}: ${error instanceof Error ? error.message : String(error)}` });
    }
  });
}

async function runCommandClipboardBackend(text: string, backend: ClipboardBackend): Promise<CopyResult> {
  if (backend.command === "wl-copy") {
    return runWlCopyBackend(text, backend);
  }

  if (backend.supported && !backend.supported()) {
    return { ok: false, error: `${backend.name}: skipped for this session type` };
  }

  const result = spawnSync(backend.command, backend.args, {
    input: text,
    encoding: "utf8",
    windowsHide: true,
    timeout: backend.timeoutMs,
  });

  if (!result.error && result.status === 0) {
    return { ok: true, backend: backend.name };
  }

  const errorCode = (result.error as NodeJS.ErrnoException | undefined)?.code;
  if (errorCode === "ENOENT") {
    return { ok: false, error: `${backend.name}: not installed` };
  }

  if (errorCode === "ETIMEDOUT") {
    return { ok: false, error: `${backend.name}: timed out` };
  }

  const stderr = typeof result.stderr === "string" ? result.stderr.trim() : "";
  return { ok: false, error: `${backend.name}: ${result.error instanceof Error ? result.error.message : stderr || `exit ${result.status ?? "unknown"}`}` };
}

async function copyToClipboard(text: string): Promise<CopyResult> {
  const attempts: string[] = [];

  if (process.env.TMUX) {
    const loadBufferResult = copyViaTmuxLoadBuffer(text);
    if (loadBufferResult.ok) {
      return loadBufferResult;
    }
    attempts.push(loadBufferResult.error);

    const passthroughResult = copyViaTmuxPassthrough(text);
    if (passthroughResult.ok) {
      return passthroughResult;
    }
    attempts.push(passthroughResult.error);
  }

  if (!process.env.TMUX && isSshSession()) {
    const result = copyViaOsc52(text);
    if (result.ok) {
      return result;
    }
    attempts.push(result.error);
  }

  for (const backend of getClipboardBackends()) {
    const result = await runCommandClipboardBackend(text, backend);
    if (result.ok) {
      return result;
    }
    attempts.push(result.error);
  }

  if (!process.env.TMUX && !isSshSession() && likelySupportsOsc52()) {
    const result = copyViaOsc52(text);
    if (result.ok) {
      return result;
    }
    attempts.push(result.error);
  }

  return {
    ok: false,
    error: attempts.length > 0 ? attempts.join("; ") : "no clipboard backend available",
  };
}

function getCodeLines(code: string): string[] {
  const normalized = code.replace(/\r\n?/g, "\n");
  const trimmed = normalized.replace(/\n+$/, "");

  if (trimmed === "") {
    return normalized === "" ? [] : [""];
  }

  return trimmed.split("\n");
}

function getBlockLineCount(block: CodeBlock): number {
  return getCodeLines(block.code).length;
}

function formatBlockLabel(block: CodeBlock): string {
  const language = block.language ?? "text";
  const lineCount = getBlockLineCount(block);
  const lineLabel = `${lineCount} ${lineCount === 1 ? "line" : "lines"}`;
  return `${block.index}. ${language} — ${lineLabel} — ${block.preview}`;
}

function formatBlockMeta(block: CodeBlock): string {
  const language = block.language ?? "text";
  const lineCount = getBlockLineCount(block);
  const lineLabel = `${lineCount} ${lineCount === 1 ? "line" : "lines"}`;
  const charLabel = `${block.code.length} ${block.code.length === 1 ? "char" : "chars"}`;
  return `Block ${block.index} • ${language} • ${lineLabel} • ${charLabel}`;
}

function getFuzzyMatchScore(normalizedQuery: string, normalizedText: string): number | undefined {
  if (!normalizedQuery) {
    return 0;
  }

  const exactIndex = normalizedText.indexOf(normalizedQuery);
  if (exactIndex >= 0) {
    return 1_000_000 + Math.max(0, normalizedText.length - exactIndex);
  }

  let score = 0;
  let firstIndex = -1;
  let lastIndex = -1;

  for (const char of normalizedQuery) {
    if (char === " ") {
      continue;
    }

    const index = normalizedText.indexOf(char, lastIndex + 1);
    if (index === -1) {
      return undefined;
    }

    if (firstIndex === -1) {
      firstIndex = index;
    }

    score += 10;
    if (index === lastIndex + 1) {
      score += 15;
    }

    const previousChar = index === 0 ? " " : normalizedText[index - 1] ?? " ";
    if (/\s|[([{\'"`_\-/:.]/.test(previousChar)) {
      score += 20;
    }

    lastIndex = index;
  }

  const span = Math.max(1, lastIndex - firstIndex + 1);
  return score - span - firstIndex;
}

function rankBlocks(blocks: CodeBlock[], query: string): CodeBlock[] {
  const normalizedQuery = normalizeSearchText(query);
  if (!normalizedQuery) {
    return [...blocks];
  }

  return blocks
    .map((block) => ({
      block,
      score: getFuzzyMatchScore(normalizedQuery, block.searchText),
    }))
    .filter((entry): entry is { block: CodeBlock; score: number } => entry.score !== undefined)
    .sort((left, right) => right.score - left.score || left.block.index - right.block.index)
    .map((entry) => entry.block);
}

function findExactMatchRange(text: string, query: string): { start: number; end: number } | undefined {
  const normalizedQuery = normalizeSearchText(query);
  if (!normalizedQuery) {
    return undefined;
  }

  const normalizedChars: string[] = [];
  const rawIndices: number[] = [];
  let sawNonWhitespace = false;
  let pendingWhitespace = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index]!;
    if (/\s/.test(char)) {
      pendingWhitespace = sawNonWhitespace;
      continue;
    }

    if (pendingWhitespace) {
      normalizedChars.push(" ");
      rawIndices.push(index);
      pendingWhitespace = false;
    }

    normalizedChars.push(char.toLowerCase());
    rawIndices.push(index);
    sawNonWhitespace = true;
  }

  const normalizedText = normalizedChars.join("");
  const exactIndex = normalizedText.indexOf(normalizedQuery);
  if (exactIndex === -1) {
    return undefined;
  }

  const start = rawIndices[exactIndex]!;
  const end = rawIndices[exactIndex + normalizedQuery.length - 1]! + 1;
  return { start, end };
}

function getMatchRanges(text: string, query: string): Array<{ start: number; end: number }> {
  const normalizedQuery = normalizeSearchText(query);
  if (!normalizedQuery) {
    return [];
  }

  const exactRange = findExactMatchRange(text, query);
  if (exactRange) {
    return [exactRange];
  }

  const lowerText = text.toLowerCase();
  const matchedIndices: number[] = [];
  let searchFrom = 0;

  for (const char of normalizedQuery) {
    if (char === " ") {
      continue;
    }

    const index = lowerText.indexOf(char, searchFrom);
    if (index === -1) {
      return [];
    }

    matchedIndices.push(index);
    searchFrom = index + 1;
  }

  if (matchedIndices.length === 0) {
    return [];
  }

  const ranges: Array<{ start: number; end: number }> = [];
  let rangeStart = matchedIndices[0]!;
  let previousIndex = matchedIndices[0]!;

  for (let i = 1; i < matchedIndices.length; i += 1) {
    const index = matchedIndices[i]!;
    if (index === previousIndex + 1) {
      previousIndex = index;
      continue;
    }

    ranges.push({ start: rangeStart, end: previousIndex + 1 });
    rangeStart = index;
    previousIndex = index;
  }

  ranges.push({ start: rangeStart, end: previousIndex + 1 });
  return ranges;
}

function getVisibleWindow(selectedIndex: number, total: number, limit: number): { start: number; end: number } {
  if (total <= limit) {
    return { start: 0, end: total };
  }

  const half = Math.floor(limit / 2);
  let start = Math.max(0, selectedIndex - half);
  let end = start + limit;

  if (end > total) {
    end = total;
    start = Math.max(0, end - limit);
  }

  return { start, end };
}

class BlockPickerOverlay {
  private selectedIndex = 0;
  private query = "";
  private filteredBlocks: CodeBlock[];

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly blocks: CodeBlock[],
    private readonly title: string,
    private readonly done: (result: CodeBlock | undefined) => void,
  ) {
    this.filteredBlocks = [...blocks];
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.done(undefined);
      return;
    }

    if (matchesKey(data, "up")) {
      this.moveSelection(-1);
      return;
    }

    if (matchesKey(data, "down")) {
      this.moveSelection(1);
      return;
    }

    if (matchesKey(data, "enter") || matchesKey(data, "return")) {
      const selectedBlock = this.filteredBlocks[this.selectedIndex];
      if (selectedBlock) {
        this.done(selectedBlock);
      }
      return;
    }

    if (matchesKey(data, "backspace") || data === "\u007f" || data === "\b") {
      if (this.query.length > 0) {
        this.updateQuery(this.query.slice(0, -1));
      }
      return;
    }

    if (data === "\u0015") {
      if (this.query.length > 0) {
        this.updateQuery("");
      }
      return;
    }

    if (data === "\u0017") {
      if (this.query.length > 0) {
        this.updateQuery(this.query.replace(/\s*\S+\s*$/, ""));
      }
      return;
    }

    const printableInput = this.getPrintableInput(data);
    if (printableInput) {
      this.updateQuery(this.query + printableInput);
    }
  }

  render(width: number): string[] {
    const innerWidth = Math.max(1, width - 2);
    const maxOverlayRows = Math.max(1, Math.floor(this.tui.terminal.rows * BLOCK_PICKER_OVERLAY_MAX_HEIGHT_RATIO));
    const showMeta = maxOverlayRows >= 7;
    const showBlocksHeader = maxOverlayRows >= 8;
    const showHelp = maxOverlayRows >= 9;
    const fixedRows = 2 + 2 + (showMeta ? 1 : 0) + (showBlocksHeader ? 1 : 0) + (showHelp ? 1 : 0);
    const availableBodyRows = Math.max(1, maxOverlayRows - fixedRows);
    const listRows = availableBodyRows === 1
      ? 1
      : Math.max(1, Math.min(BLOCK_PICKER_MAX_VISIBLE_ITEMS + 2, Math.floor(availableBodyRows / 2)));
    const previewRows = Math.max(0, availableBodyRows - listRows);
    const border = (text: string) => this.theme.fg("border", text);
    const row = (content = "") => border("│") + this.pad(content, innerWidth) + border("│");
    const selectedBlock = this.filteredBlocks[this.selectedIndex];
    const lines: string[] = [];
    const matchCount = this.filteredBlocks.length;
    const searchLabel = this.query
      ? this.theme.fg("accent", this.query)
      : this.theme.fg("dim", "type to search full block content");

    lines.push(border(`╭${"─".repeat(innerWidth)}╮`));
    lines.push(row(` ${this.theme.fg("accent", this.theme.bold(this.title))}`));
    lines.push(row(` Search: ${searchLabel}`));

    if (showMeta) {
      const meta = selectedBlock
        ? `${formatBlockMeta(selectedBlock)} • ${matchCount}/${this.blocks.length} matches`
        : `No matching blocks • 0/${this.blocks.length} matches`;
      lines.push(row(` ${this.theme.fg("dim", meta)}`));
    }

    for (const previewLine of this.renderPreview(selectedBlock, innerWidth, previewRows)) {
      lines.push(row(previewLine));
    }

    if (showBlocksHeader) {
      lines.push(row(` ${this.theme.fg("accent", "Matches")}`));
    }

    for (const optionLine of this.renderBlockList(listRows)) {
      lines.push(row(optionLine));
    }

    if (showHelp) {
      lines.push(row(` ${this.theme.fg("dim", "Type to filter • ↑↓ move • Enter copy • ⌫ delete • Esc cancel")}`));
    }

    lines.push(border(`╰${"─".repeat(innerWidth)}╯`));

    return lines;
  }

  invalidate(): void {}

  dispose(): void {}

  private moveSelection(delta: number): void {
    if (this.filteredBlocks.length === 0) {
      return;
    }

    this.selectedIndex = Math.max(0, Math.min(this.filteredBlocks.length - 1, this.selectedIndex + delta));
    this.tui.requestRender();
  }

  private updateQuery(nextQuery: string): void {
    this.query = nextQuery;
    this.filteredBlocks = rankBlocks(this.blocks, this.query);
    this.selectedIndex = 0;
    this.tui.requestRender();
  }

  private getPrintableInput(data: string): string {
    return data
      .replace(/\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)/g, "")
      .replace(/\u001b[P^_][\s\S]*?\u001b\\/g, "")
      .replace(/\u001b\[200~/g, "")
      .replace(/\u001b\[201~/g, "")
      .replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, "")
      .replace(/\u001b./g, "")
      .replace(/[\r\n\t]+/g, " ")
      .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "");
  }

  private renderPreview(block: CodeBlock | undefined, innerWidth: number, maxRows: number): string[] {
    if (!block) {
      return [this.theme.fg("dim", " no matching blocks")].slice(0, maxRows);
    }

    const codeLines = getCodeLines(block.code);
    if (codeLines.length === 0) {
      return [this.theme.fg("dim", " (empty block)")].slice(0, maxRows);
    }

    const lineStarts: number[] = [];
    let blockOffset = 0;
    for (const line of codeLines) {
      lineStarts.push(blockOffset);
      blockOffset += line.length + 1;
    }

    const exactBlockMatch = this.query ? findExactMatchRange(block.code, this.query) : undefined;
    const previewWidth = Math.max(8, innerWidth - 1);
    const lineNumberWidth = String(codeLines.length).length;
    const visibleCodeLines = codeLines.length > maxRows && maxRows > 1 ? maxRows - 1 : maxRows;
    const matchLineIndex = exactBlockMatch
      ? this.getLineIndexForOffset(codeLines, exactBlockMatch.start)
      : this.findPreviewMatchLineIndex(codeLines);
    const { start, end } = matchLineIndex >= 0
      ? getVisibleWindow(matchLineIndex, codeLines.length, visibleCodeLines)
      : { start: 0, end: visibleCodeLines };
    const rendered = codeLines.slice(start, end).map((line, index) => {
      const absoluteIndex = start + index;
      const lineNumber = absoluteIndex + 1;
      const prefix = this.theme.fg("dim", `${String(lineNumber).padStart(lineNumberWidth, " ")} │ `);
      const available = Math.max(1, previewWidth - visibleWidth(prefix));
      const exactLineRanges = exactBlockMatch
        ? this.getExactLineMatchRanges(line, lineStarts[absoluteIndex]!, exactBlockMatch)
        : [];
      return ` ${prefix}${this.renderHighlightedExcerpt(line, available, exactLineRanges.length > 0 ? exactLineRanges : undefined)}`;
    });

    if ((start > 0 || end < codeLines.length) && rendered.length < maxRows) {
      const parts: string[] = [];
      if (start > 0) {
        parts.push(`${start} earlier line${start === 1 ? "" : "s"}`);
      }
      if (end < codeLines.length) {
        parts.push(`${codeLines.length - end} more line${codeLines.length - end === 1 ? "" : "s"}`);
      }
      rendered.push(this.theme.fg("dim", ` … ${parts.join(" • ")} not shown`));
    }

    return rendered.slice(0, maxRows);
  }

  private renderBlockList(maxRows: number): string[] {
    if (this.filteredBlocks.length === 0) {
      return [` ${this.theme.fg("dim", `No matches for “${this.query}”`)}`].slice(0, maxRows);
    }

    if (maxRows <= 1) {
      const selected = this.filteredBlocks[this.selectedIndex]!;
      return [` ${this.theme.fg("accent", "▶ ")}${this.highlightText(formatBlockLabel(selected), this.query, { selected: true })}`];
    }

    if (maxRows === 2) {
      const selected = this.filteredBlocks[this.selectedIndex]!;
      return [
        ` ${this.theme.fg("accent", "▶ ")}${this.highlightText(formatBlockLabel(selected), this.query, { selected: true })}`,
        this.theme.fg("dim", ` ${this.selectedIndex + 1} of ${this.filteredBlocks.length} matches`),
      ];
    }

    const { start, end } = getVisibleWindow(
      this.selectedIndex,
      this.filteredBlocks.length,
      Math.max(1, Math.min(BLOCK_PICKER_MAX_VISIBLE_ITEMS, maxRows - 2)),
    );
    const lines: string[] = [];

    if (start > 0) {
      lines.push(this.theme.fg("dim", ` … ${start} earlier match${start === 1 ? "" : "es"}`));
    }

    for (let index = start; index < end; index += 1) {
      const block = this.filteredBlocks[index]!;
      const isSelected = index === this.selectedIndex;
      const prefix = isSelected ? this.theme.fg("accent", "▶ ") : "  ";
      const label = this.highlightText(formatBlockLabel(block), this.query, { selected: isSelected });
      lines.push(` ${prefix}${label}`);
    }

    if (end < this.filteredBlocks.length) {
      const remaining = this.filteredBlocks.length - end;
      lines.push(this.theme.fg("dim", ` … ${remaining} more match${remaining === 1 ? "" : "es"}`));
    }

    return lines.slice(0, maxRows);
  }

  private findPreviewMatchLineIndex(codeLines: string[]): number {
    if (!normalizeSearchText(this.query)) {
      return -1;
    }

    const exactLineIndex = codeLines.findIndex((line) => !!findExactMatchRange(line, this.query));
    if (exactLineIndex >= 0) {
      return exactLineIndex;
    }

    return codeLines.findIndex((line) => getMatchRanges(line, this.query).length > 0);
  }

  private getLineIndexForOffset(codeLines: string[], offset: number): number {
    let lineStart = 0;

    for (let index = 0; index < codeLines.length; index += 1) {
      const line = codeLines[index]!;
      const lineEnd = lineStart + line.length;
      if (offset <= lineEnd || index === codeLines.length - 1) {
        return index;
      }
      lineStart = lineEnd + 1;
    }

    return 0;
  }

  private getExactLineMatchRanges(line: string, lineStart: number, exactMatch: { start: number; end: number }): Array<{ start: number; end: number }> {
    const lineEnd = lineStart + line.length;
    const start = Math.max(lineStart, exactMatch.start);
    const end = Math.min(lineEnd, exactMatch.end);

    if (start >= end) {
      return [];
    }

    return [{ start: start - lineStart, end: end - lineStart }];
  }

  private renderHighlightedExcerpt(text: string, width: number, rangesOverride?: Array<{ start: number; end: number }>): string {
    if (!this.query && !rangesOverride) {
      return truncateToWidth(text, width, "…", true);
    }

    const ranges = rangesOverride ?? getMatchRanges(text, this.query);
    if (ranges.length === 0) {
      return this.highlightText(truncateToWidth(text, width, "…", true), this.query);
    }

    const firstRange = ranges[0]!;
    const matchLength = Math.max(1, firstRange.end - firstRange.start);
    const targetStart = Math.max(0, firstRange.start - Math.max(0, Math.floor((width - matchLength) / 2)));
    const targetEnd = Math.min(text.length, Math.max(firstRange.end, targetStart + width));
    const start = Math.max(0, targetEnd - width);
    const end = Math.min(text.length, Math.max(firstRange.end, start + width));
    const leftEllipsis = start > 0;
    const rightEllipsis = end < text.length;
    const excerptBudget = Math.max(1, width - (leftEllipsis ? 1 : 0) - (rightEllipsis ? 1 : 0));
    const excerptEnd = Math.min(text.length, start + excerptBudget);
    const excerpt = text.slice(start, excerptEnd);
    const adjustedRanges = ranges
      .map((range) => ({
        start: Math.max(0, range.start - start) + (leftEllipsis ? 1 : 0),
        end: Math.min(excerpt.length, range.end - start) + (leftEllipsis ? 1 : 0),
      }))
      .filter((range) => range.end > range.start);
    const decorated = `${leftEllipsis ? "…" : ""}${excerpt}${rightEllipsis ? "…" : ""}`;

    return this.highlightText(decorated, this.query, undefined, adjustedRanges);
  }

  private highlightText(text: string, query: string, options?: { selected?: boolean }, rangesOverride?: Array<{ start: number; end: number }>): string {
    const ranges = rangesOverride ?? getMatchRanges(text, query);
    const base = (value: string) => (options?.selected ? this.theme.fg("accent", value) : value);
    const highlight = (value: string) => this.theme.fg("accent", this.theme.bold(value));

    if (ranges.length === 0) {
      return base(text);
    }

    let result = "";
    let cursor = 0;

    for (const range of ranges) {
      if (range.start > cursor) {
        result += base(text.slice(cursor, range.start));
      }

      result += highlight(text.slice(range.start, range.end));
      cursor = range.end;
    }

    if (cursor < text.length) {
      result += base(text.slice(cursor));
    }

    return result;
  }

  private pad(content: string, width: number): string {
    const truncated = truncateToWidth(content, width, "…", true);
    return truncated + " ".repeat(Math.max(0, width - visibleWidth(truncated)));
  }
}

async function pickBlockWithPreview(ctx: any, blocks: CodeBlock[], title: string): Promise<CodeBlock | undefined> {
  return ctx.ui.custom<CodeBlock | undefined>(
    (tui: TUI, theme: Theme, _keybindings: unknown, done: (result: CodeBlock | undefined) => void) =>
      new BlockPickerOverlay(tui, theme, blocks, title, done),
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: "85%",
        minWidth: 60,
        maxHeight: "85%",
        margin: 1,
      },
    },
  );
}

async function pickBlock(ctx: any, blocks: CodeBlock[], title: string): Promise<CodeBlock | undefined> {
  if (blocks.length === 0) {
    return undefined;
  }

  if (blocks.length === 1 || !ctx.hasUI) {
    return blocks[0];
  }

  try {
    return await pickBlockWithPreview(ctx, blocks, title);
  } catch (error) {
    console.warn("[copy-smart] preview picker failed, falling back to standard select", error);
    ctx.ui.notify?.("Preview picker unavailable, falling back to the standard block picker.", "warning");

    const labels = blocks.map(formatBlockLabel);
    const selected = await ctx.ui.select(title, labels);
    if (!selected) {
      return undefined;
    }

    return blocks[labels.indexOf(selected)];
  }
}

async function resolveBlockSelection(ctx: any, blocks: CodeBlock[], selector: string): Promise<CodeBlock | undefined> {
  const normalized = normalizeSearchText(selector);
  if (!normalized) {
    return pickBlock(ctx, blocks, "Copy which block?");
  }

  if (/^\d+$/.test(normalized)) {
    return blocks[Number.parseInt(normalized, 10) - 1];
  }

  if (normalized === "last") {
    return blocks[blocks.length - 1];
  }

  const exactLanguageMatches = blocks.filter((block) => (block.language ?? "").toLowerCase() === normalized);
  if (exactLanguageMatches.length === 1) {
    return exactLanguageMatches[0];
  }
  if (exactLanguageMatches.length > 1) {
    return pickBlock(ctx, exactLanguageMatches, `Multiple ${normalized} blocks found`);
  }

  const fuzzyMatches = blocks.filter((block) => block.codeSearchText.includes(normalized));

  if (fuzzyMatches.length === 1) {
    return fuzzyMatches[0];
  }
  if (fuzzyMatches.length > 1) {
    return pickBlock(ctx, fuzzyMatches, `Multiple matches for ${selector}`);
  }

  return undefined;
}

function runCommand(command: string, args: string[]): { ok: boolean; stdout: string; stderr: string; status: number | null; error?: string } {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    windowsHide: true,
  });

  return {
    ok: !result.error && result.status === 0,
    stdout: typeof result.stdout === "string" ? result.stdout.trim() : "",
    stderr: typeof result.stderr === "string" ? result.stderr.trim() : "",
    status: result.status,
    error: result.error instanceof Error ? result.error.message : undefined,
  };
}

function isCommandAvailable(command: string): boolean {
  if (process.platform === "win32") {
    return runCommand("where", [command]).ok;
  }

  return runCommand("sh", ["-lc", `command -v ${JSON.stringify(command)} >/dev/null 2>&1`]).ok;
}

function getTmuxCommand(args: string[]): string {
  const result = runCommand("tmux", args);
  if (result.ok) {
    return result.stdout || "(empty)";
  }
  return result.error || result.stderr || `exit ${result.status ?? "unknown"}`;
}

function getTmuxClientValue(format: string): string {
  if (!process.env.TMUX) {
    return "(not in tmux)";
  }
  return getTmuxCommand(["display-message", "-p", format]);
}

function buildCopyDebugReport(): string {
  const commandBackends = getClipboardBackends();
  const lines = [
    "copy-debug",
    `platform: ${process.platform}`,
    `kernel: ${release()}`,
    `term: ${process.env.TERM ?? "(unset)"}`,
    `term_program: ${process.env.TERM_PROGRAM ?? "(unset)"}`,
    `tmux env: ${process.env.TMUX ? "yes" : "no"}`,
    `ssh env: ${isSshSession() ? "yes" : "no"}`,
    `wsl: ${isWsl() ? "yes" : "no"}`,
    `wayland: ${isWaylandSession() ? "yes" : "no"}`,
    `x11: ${isX11Session() ? "yes" : "no"}`,
    `tty: ${process.env.TTY ?? process.env.SSH_TTY ?? "(unknown)"}`,
    `osc52 ssh path: ${!process.env.TMUX && isSshSession() ? "yes" : "no"}`,
    `osc52 local fallback: ${!process.env.TMUX && !isSshSession() && likelySupportsOsc52() ? "yes" : "no"}`,
    "",
    "backend order:",
  ];

  if (process.env.TMUX) {
    lines.push("- tmux load-buffer -w");
    lines.push("- tmux passthrough OSC52");
  }
  if (!process.env.TMUX && isSshSession()) {
    lines.push("- direct OSC52");
  }
  for (const backend of commandBackends) {
    lines.push(`- ${backend.name}`);
  }
  if (!process.env.TMUX && !isSshSession() && likelySupportsOsc52()) {
    lines.push("- direct OSC52 (local fallback)");
  }

  lines.push("", "command availability:");
  if (process.env.TMUX || isCommandAvailable("tmux")) {
    lines.push(`- tmux: ${isCommandAvailable("tmux") ? "yes" : "no"}`);
  }
  for (const backend of commandBackends) {
    lines.push(`- ${backend.name}: ${isCommandAvailable(backend.command) ? "yes" : "no"}`);
  }

  if (process.env.TMUX || isCommandAvailable("tmux")) {
    lines.push(
      "",
      "tmux state:",
      `- version: ${getTmuxCommand(["-V"])}`,
      `- set-clipboard: ${getTmuxCommand(["show-options", "-sqv", "set-clipboard"])}`,
      `- allow-passthrough: ${getTmuxCommand(["show-options", "-wqv", "allow-passthrough"])}`,
      `- client termname: ${getTmuxClientValue("#{client_termname}")}`,
      `- client termfeatures: ${getTmuxClientValue("#{client_termfeatures}")}`,
      `- default-terminal: ${getTmuxCommand(["show-options", "-gqv", "default-terminal"])}`,
      `- terminal-features: ${getTmuxCommand(["show-options", "-gqv", "terminal-features"])}`,
    );
  }

  lines.push(
    "",
    "notes:",
    "- For kitty -> local tmux -> ssh -> remote tmux, the local tmux client must advertise clipboard support.",
    "- After tmux.conf changes, fully reattach local tmux if client_termfeatures still looks stale.",
    "- Successful /dev/tty writes do not prove the outer terminal accepted OSC52."
  );

  return lines.join("\n");
}

function notifyCopied(ctx: any, label: string, backend: string) {
  ctx.ui.notify(`Copied ${label} via ${backend}`, "info");
}

function notifyCopyError(ctx: any, message: string) {
  ctx.ui.notify(message, "error");
}

async function copySelectedBlock(ctx: any, selector?: string): Promise<boolean> {
  const lastAssistant = getLastAssistantText(ctx.sessionManager);
  if (!lastAssistant) {
    notifyCopyError(ctx, "No assistant message with text found.");
    return false;
  }

  const blocks = extractCodeBlocks(lastAssistant.text);
  if (blocks.length === 0) {
    notifyCopyError(ctx, "No fenced code blocks found in the last assistant message.");
    return false;
  }

  const block = await resolveBlockSelection(ctx, blocks, selector ?? "");
  if (!block) {
    if (selector?.trim()) {
      notifyCopyError(ctx, `No code block matched '${selector.trim()}'.`);
    }
    return false;
  }

  const result = await copyToClipboard(block.code);
  if (!result.ok) {
    notifyCopyError(ctx, `Copy failed: ${result.error}`);
    return false;
  }

  notifyCopied(ctx, `block ${block.index}${block.language ? ` (${block.language})` : ""}`, result.backend);
  return true;
}

async function copySmart(ctx: any, selector?: string): Promise<boolean> {
  const lastAssistant = getLastAssistantText(ctx.sessionManager);
  if (!lastAssistant) {
    notifyCopyError(ctx, "No assistant message with text found.");
    return false;
  }

  const blocks = extractCodeBlocks(lastAssistant.text);
  if (selector?.trim()) {
    return copySelectedBlock(ctx, selector);
  }

  if (blocks.length === 1) {
    const result = await copyToClipboard(blocks[0].code);
    if (!result.ok) {
      notifyCopyError(ctx, `Copy failed: ${result.error}`);
      return false;
    }

    notifyCopied(ctx, `block 1${blocks[0].language ? ` (${blocks[0].language})` : ""}`, result.backend);
    return true;
  }

  if (blocks.length > 1) {
    return copySelectedBlock(ctx);
  }

  const result = await copyToClipboard(lastAssistant.text);
  if (!result.ok) {
    notifyCopyError(ctx, `Copy failed: ${result.error}`);
    return false;
  }

  notifyCopied(ctx, "last assistant message", result.backend);
  return true;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("copy-smart", {
    description: "Copy the last assistant code block when obvious, otherwise prompt or fall back to the full message",
    handler: async (args, ctx) => {
      await copySmart(ctx, args);
    },
  });

  pi.registerCommand("copy-block", {
    description: "Copy a fenced code block from the last assistant message by number, language, or picker",
    handler: async (args, ctx) => {
      await copySelectedBlock(ctx, args);
    },
  });

  pi.registerCommand("copy-debug", {
    description: "Show SSH/tmux clipboard diagnostics for copy-smart",
    handler: async (_args, ctx) => {
      const report = buildCopyDebugReport();
      pi.sendMessage({
        customType: "copy-debug",
        content: report,
        display: true,
      });
      ctx.ui.notify("Posted copy debug report", "info");
    },
  });

  pi.registerShortcut("ctrl+alt+y", {
    description: "Copy the latest assistant code block or message",
    handler: async (ctx) => {
      await copySmart(ctx);
    },
  });
}
