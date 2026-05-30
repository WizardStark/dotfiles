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
 * - SSH: direct OSC52 write to /dev/tty as a fallback when not inside tmux
 * - macOS: pbcopy
 * - Linux: wl-copy, xclip, xsel
 * - WSL: powershell.exe / clip.exe fallback to the Windows clipboard
 * - Windows: powershell.exe, clip
 */
import { spawnSync } from "node:child_process";
import { closeSync, openSync, writeSync } from "node:fs";
import { release } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type AssistantTextSource = {
  text: string;
  timestamp?: number;
};

type CodeBlock = {
  index: number;
  language?: string;
  code: string;
  preview: string;
};

type CopyResult =
  | { ok: true; backend: string }
  | { ok: false; error: string };

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
    blocks.push({
      index: blocks.length + 1,
      language: info.split(/\s+/)[0] || undefined,
      code,
      preview: summarizeCode(code),
    });
    i = closeIndex;
  }

  return blocks;
}

function getWindowsClipboardBackends(): Array<{ name: string; command: string; args: string[] }> {
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

function getClipboardBackends(): Array<{ name: string; command: string; args: string[] }> {
  switch (process.platform) {
    case "darwin":
      return [{ name: "pbcopy", command: "pbcopy", args: [] }];
    case "win32":
      return getWindowsClipboardBackends();
    default:
      return [
        ...(isWsl() ? getWindowsClipboardBackends() : []),
        { name: "wl-copy", command: "wl-copy", args: [] },
        { name: "xclip", command: "xclip", args: ["-selection", "clipboard"] },
        { name: "xsel", command: "xsel", args: ["--clipboard", "--input"] },
      ];
  }
}

function isSshSession(): boolean {
  return !!(process.env.SSH_CONNECTION || process.env.SSH_CLIENT || process.env.SSH_TTY);
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
  });

  if (!result.error && result.status === 0) {
    return { ok: true, backend: "tmux load-buffer -w" };
  }

  if ((result.error as NodeJS.ErrnoException | undefined)?.code === "ENOENT") {
    return { ok: false, error: "tmux load-buffer: not installed" };
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

function runCommandClipboardBackend(text: string, backend: { name: string; command: string; args: string[] }): CopyResult {
  const result = spawnSync(backend.command, backend.args, {
    input: text,
    encoding: "utf8",
    windowsHide: true,
  });

  if (!result.error && result.status === 0) {
    return { ok: true, backend: backend.name };
  }

  if ((result.error as NodeJS.ErrnoException | undefined)?.code === "ENOENT") {
    return { ok: false, error: `${backend.name}: not installed` };
  }

  const stderr = typeof result.stderr === "string" ? result.stderr.trim() : "";
  return { ok: false, error: `${backend.name}: ${result.error instanceof Error ? result.error.message : stderr || `exit ${result.status ?? "unknown"}`}` };
}

function copyToClipboard(text: string): CopyResult {
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
    const result = runCommandClipboardBackend(text, backend);
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

function formatBlockLabel(block: CodeBlock): string {
  const language = block.language ?? "text";
  return `${block.index}. ${language} — ${block.preview}`;
}

async function pickBlock(ctx: any, blocks: CodeBlock[], title: string): Promise<CodeBlock | undefined> {
  if (blocks.length === 0) {
    return undefined;
  }

  if (blocks.length === 1 || !ctx.hasUI) {
    return blocks[0];
  }

  const labels = blocks.map(formatBlockLabel);
  const selected = await ctx.ui.select(title, labels);
  if (!selected) {
    return undefined;
  }

  return blocks[labels.indexOf(selected)];
}

async function resolveBlockSelection(ctx: any, blocks: CodeBlock[], selector: string): Promise<CodeBlock | undefined> {
  const normalized = selector.trim().toLowerCase();
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

  const fuzzyMatches = blocks.filter((block) => {
    const haystack = `${block.language ?? ""} ${block.preview}`.toLowerCase();
    return haystack.includes(normalized);
  });

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
    `tty: ${process.env.TTY ?? process.env.SSH_TTY ?? "(unknown)"}`,
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

  const result = copyToClipboard(block.code);
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
    const result = copyToClipboard(blocks[0].code);
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

  const result = copyToClipboard(lastAssistant.text);
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
