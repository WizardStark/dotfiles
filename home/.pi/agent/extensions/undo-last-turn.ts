import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import { mkdir, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";

const STATE_TYPE = "undo-last-agent-turn-state";
const MESSAGE_TYPE = "undo-last-agent-turn";

type FileSnapshot = {
  existed: boolean;
  content?: string;
};

type UndoFileChange = {
  path: string;
  displayPath: string;
  before: FileSnapshot;
  after: FileSnapshot;
};

type UndoBatch = {
  createdAt: number;
  files: UndoFileChange[];
};

type PersistedUndoState = {
  lastBatch?: UndoBatch;
};

function sameSnapshot(left: FileSnapshot, right: FileSnapshot): boolean {
  return left.existed === right.existed && left.content === right.content;
}

function summarizePaths(paths: string[]): string {
  if (paths.length === 0) return "no files";
  if (paths.length === 1) return paths[0] ?? "1 file";
  if (paths.length === 2) return `${paths[0]}, ${paths[1]}`;
  return `${paths[0]}, ${paths[1]}, and ${paths.length - 2} more`;
}

function formatDisplayPath(cwd: string, absolutePath: string): string {
  const rel = relative(cwd, absolutePath);
  if (rel !== "" && !rel.startsWith("..")) {
    return rel;
  }
  return absolutePath;
}

async function normalizePath(cwd: string, targetPath: string): Promise<string> {
  const absolutePath = resolve(cwd, targetPath);
  try {
    return await realpath(absolutePath);
  } catch {
    return absolutePath;
  }
}

async function snapshotFile(path: string): Promise<FileSnapshot> {
  try {
    const content = await readFile(path, "utf8");
    return { existed: true, content };
  } catch (error: any) {
    if (error?.code === "ENOENT") {
      return { existed: false };
    }
    throw error;
  }
}

function getToolPath(input: Record<string, unknown>): string | undefined {
  const value = typeof input.path === "string" ? input.path : typeof input.file_path === "string" ? input.file_path : undefined;
  if (value == null || value.trim() === "") return undefined;
  return value;
}

function isUndoState(value: unknown): value is PersistedUndoState {
  if (value == null || typeof value !== "object") return false;
  return true;
}

export default function (pi: ExtensionAPI) {
  let lastBatch: UndoBatch | undefined;
  let pendingTouchedFiles = new Map<string, { displayPath: string; before: FileSnapshot }>();

  function loadState(ctx: ExtensionContext) {
    lastBatch = undefined;
    pendingTouchedFiles = new Map();

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== STATE_TYPE) continue;
      if (!isUndoState(entry.data)) continue;
      lastBatch = entry.data.lastBatch;
    }
  }

  function persistState() {
    pi.appendEntry(STATE_TYPE, { lastBatch } satisfies PersistedUndoState);
  }

  pi.registerMessageRenderer(MESSAGE_TYPE, (message, { expanded }, theme) => {
    const details = (message.details ?? {}) as { files?: string[]; revertedAt?: number };
    const files = Array.isArray(details.files) ? details.files : [];
    const lines = [theme.fg("muted", "Undo") + theme.fg("dim", " · ") + theme.fg("accent", String(message.content))];

    if (expanded && files.length > 0) {
      for (const file of files) {
        lines.push(theme.fg("dim", `- ${file}`));
      }
      if (typeof details.revertedAt === "number") {
        lines.push(theme.fg("dim", new Date(details.revertedAt).toLocaleTimeString()));
      }
    }

    const box = new Box(1, 0, (text) => theme.bg("customMessageBg", text));
    box.addChild(new Text(lines.join("\n"), 0, 0));
    return box;
  });

  pi.on("session_start", async (_event, ctx) => {
    loadState(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    loadState(ctx);
  });

  pi.on("agent_start", async () => {
    pendingTouchedFiles = new Map();
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "edit" && event.toolName !== "write") return;

    const targetPath = getToolPath(event.input);
    if (targetPath == null) return;

    const absolutePath = await normalizePath(ctx.cwd, targetPath);
    if (pendingTouchedFiles.has(absolutePath)) return;

    pendingTouchedFiles.set(absolutePath, {
      displayPath: formatDisplayPath(ctx.cwd, absolutePath),
      before: await snapshotFile(absolutePath),
    });
  });

  pi.on("agent_end", async (_event, ctx) => {
    const touchedFiles = pendingTouchedFiles;
    pendingTouchedFiles = new Map();

    if (touchedFiles.size === 0) {
      lastBatch = undefined;
      persistState();
      return;
    }

    const files: UndoFileChange[] = [];
    for (const [path, pending] of touchedFiles) {
      const after = await snapshotFile(path);
      if (sameSnapshot(pending.before, after)) continue;
      files.push({
        path,
        displayPath: pending.displayPath,
        before: pending.before,
        after,
      });
    }

    lastBatch = files.length > 0 ? { createdAt: Date.now(), files } : undefined;
    persistState();

    if (lastBatch && ctx.hasUI) {
      ctx.ui.notify(`Undo ready for ${lastBatch.files.length} file(s)`, "info");
    }
  });

  pi.registerCommand("undo", {
    description: "Revert all file edits from the last agent turn and record that they were reverted.",
    handler: async (_args, ctx) => {
      await ctx.waitForIdle();

      const batch = lastBatch;
      if (!batch || batch.files.length === 0) {
        ctx.ui.notify("Nothing to undo from the last agent turn", "info");
        return;
      }

      const conflicts: string[] = [];
      for (const file of batch.files) {
        const current = await snapshotFile(file.path);
        if (!sameSnapshot(current, file.after)) {
          conflicts.push(file.displayPath);
        }
      }

      if (conflicts.length > 0) {
        const ok = await ctx.ui.confirm(
          "Undo changed files?",
          `These files changed since the last agent turn:\n${conflicts.join("\n")}\n\nForce undo anyway?`,
        );
        if (!ok) {
          ctx.ui.notify("Undo cancelled", "info");
          return;
        }
      }

      const revertedFiles = [...batch.files].reverse();
      for (const file of revertedFiles) {
        if (!file.before.existed) {
          await rm(file.path, { force: true });
          continue;
        }

        await mkdir(dirname(file.path), { recursive: true });
        await writeFile(file.path, file.before.content ?? "", "utf8");
      }

      lastBatch = undefined;
      persistState();

      const fileList = batch.files.map((file) => file.displayPath);
      const summary = `Reverted the previous agent turn in ${batch.files.length} file(s): ${summarizePaths(fileList)}`;

      pi.sendMessage({
        customType: MESSAGE_TYPE,
        content: summary,
        display: true,
        details: {
          files: fileList,
          revertedAt: Date.now(),
        },
      });

      ctx.ui.notify(summary, "info");
    },
  });
}
