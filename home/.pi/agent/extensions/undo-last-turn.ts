import { isSecretPath } from "./lib/secret-paths.ts";
import { createSessionWork, isCancelledWork } from "./lib/session-work.ts";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
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
  if (await isSecretPath(path)) throw new Error("Undo refuses dotenv snapshots.");
  try {
    const content = await readFile(path, "utf8");
    return { existed: true, content };
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
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
  const sessionWork = createSessionWork(pi);
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

  // A retry or recovery starts another low-level agent run. Reset only at the
  // user-request boundary so preimages from earlier attempts remain undoable.
  pi.on("before_agent_start", async () => {
    pendingTouchedFiles = new Map();
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "edit" && event.toolName !== "write") return;

    const targetPath = getToolPath(event.input);
    if (targetPath == null) return;

    const work = sessionWork.start(ctx.signal);
    try {
      if (await isSecretPath(targetPath, ctx.cwd)) return;
      const absolutePath = await normalizePath(ctx.cwd, targetPath);
      if (pendingTouchedFiles.has(absolutePath)) return;
      const before = await snapshotFile(absolutePath);
      work.assertCurrent();
      pendingTouchedFiles.set(absolutePath, { displayPath: formatDisplayPath(ctx.cwd, absolutePath), before });
    } finally {
      work.dispose();
    }
  });

  pi.on("agent_settled", async (_event, ctx) => {
    const touchedFiles = pendingTouchedFiles;
    pendingTouchedFiles = new Map();

    if (touchedFiles.size === 0) {
      lastBatch = undefined;
      persistState();
      return;
    }

    const work = sessionWork.start();
    try {
      const files: UndoFileChange[] = [];
      for (const [path, pending] of touchedFiles) {
        if (await isSecretPath(path)) continue;
        const after = await snapshotFile(path);
        work.assertCurrent();
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
    } catch (error) {
      if (!isCancelledWork(error)) throw error;
    } finally {
      work.dispose();
    }
  });

  pi.registerCommand("undo", {
    description: "Revert all file edits from the last agent turn and record that they were reverted.",
    handler: async (_args, ctx) => {
      const work = sessionWork.start(ctx.signal);
      try {
        await ctx.waitForIdle();
        work.assertCurrent();
        const batch = lastBatch;
        if (!batch || batch.files.length === 0) {
          ctx.ui.notify("Nothing to undo from the last agent turn", "info");
          return;
        }

        const conflicts: string[] = [];
        for (const file of batch.files) {
          if (await isSecretPath(file.path)) throw new Error("Undo refuses historical dotenv snapshots.");
          const current = await snapshotFile(file.path);
          work.assertCurrent();
          if (!sameSnapshot(current, file.after)) {
            conflicts.push(file.displayPath);
          }
        }

        let force = false;
        if (conflicts.length > 0) {
          const ok = await ctx.ui.confirm(
            "Undo changed files?",
            `These files changed since the last agent turn:\n${conflicts.join("\n")}\n\nForce undo anyway?`,
            { signal: work.signal },
          );
          work.assertCurrent();
          if (!ok) {
            ctx.ui.notify("Undo cancelled", "info");
            return;
          }
          force = true;
        }

        const revertedFiles = [...batch.files].reverse();
        for (const file of revertedFiles) {
          await withFileMutationQueue(file.path, async () => {
            const current = await snapshotFile(file.path);
            work.assertCurrent();
            if (!force && !sameSnapshot(current, file.after)) throw new Error(`File changed during undo: ${file.displayPath}`);
            if (!file.before.existed) {
              await rm(file.path, { force: true });
              return;
            }
            await mkdir(dirname(file.path), { recursive: true });
            work.assertCurrent();
            await writeFile(file.path, file.before.content ?? "", "utf8");
          });
        }

        work.assertCurrent();
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
      } catch (error) {
        if (!isCancelledWork(error)) throw error;
      } finally {
        work.dispose();
      }
    },
  });
}
