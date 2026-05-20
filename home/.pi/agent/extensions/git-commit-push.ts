import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function firstLine(value: string): string {
  return value.split(/\r?\n/).find((line) => line.trim().length > 0)?.trim() ?? "";
}

function quoteForMessage(value: string): string {
  return value.replace(/\r?\n/g, " ").replace(/\s+/g, " ").trim();
}

type PorcelainEntry = {
  x: string;
  y: string;
  path: string;
  originalPath?: string;
};

function parsePorcelainStatus(status: string): PorcelainEntry[] {
  if (!status.includes("\0")) {
    return [];
  }

  const chunks = status.split("\0");
  const entries: PorcelainEntry[] = [];

  for (let index = 0; index < chunks.length; index += 1) {
    const chunk = chunks[index];
    if (!chunk) continue;

    const x = chunk[0] ?? " ";
    const y = chunk[1] ?? " ";
    const path = chunk.length > 3 ? chunk.slice(3) : "";
    if (!path) continue;

    if ([x, y].includes("R") || [x, y].includes("C")) {
      const originalPath = chunks[index + 1] ?? "";
      entries.push({ x, y, path, originalPath: originalPath || path });
      index += 1;
      continue;
    }

    entries.push({ x, y, path });
  }

  return entries;
}

function hasStatusCode(entry: PorcelainEntry, codes: string[]): boolean {
  return codes.includes(entry.x) || codes.includes(entry.y);
}

async function git(pi: ExtensionAPI, args: string[], signal?: AbortSignal) {
  return pi.exec("git", args, { signal, timeout: 120_000 });
}

function generateCommitMessage(status: string, stat: string): string {
  const entries = parsePorcelainStatus(status);

  const files = entries.map((entry) => entry.path).filter(Boolean);
  const topDirs = [...new Set(files.map((file) => file.split("/")[0]).filter(Boolean))];
  const scope = topDirs.length === 1 ? `(${topDirs[0].replace(/^\./, "")})` : "";

  const hasAdded = entries.some((entry) => entry.x === "?" || entry.y === "?" || hasStatusCode(entry, ["A"]));
  const hasDeleted = entries.some((entry) => hasStatusCode(entry, ["D"]));
  const hasModified = entries.some((entry) => hasStatusCode(entry, ["M", "R", "C", "T", "U"]));
  const type = hasAdded && !hasModified && !hasDeleted ? "add" : hasDeleted && !hasAdded && !hasModified ? "remove" : "update";

  const statLine = firstLine(stat);
  const noun = files.length === 1 ? files[0] : topDirs.length > 0 ? topDirs.slice(0, 3).join(", ") : "repository changes";

  if (statLine) return `${type}${scope}: ${quoteForMessage(statLine)}`;
  return `${type}${scope}: ${quoteForMessage(noun)}`;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("gcp", {
    description: "Git commit and push. Usage: /gcp [commit message]",
    handler: async (args, ctx) => {
      const providedMessage = quoteForMessage(args ?? "");

      const inside = await git(pi, ["rev-parse", "--is-inside-work-tree"], ctx.signal);
      if (inside.code !== 0) {
        ctx.ui.notify("/gcp must be run inside a git repository", "error");
        return;
      }

      const statusBefore = await git(pi, ["status", "--porcelain=1", "-z"], ctx.signal);
      if (statusBefore.code !== 0) {
        ctx.ui.notify(`git status failed: ${statusBefore.stderr || statusBefore.stdout}`, "error");
        return;
      }
      if (!statusBefore.stdout.trim()) {
        ctx.ui.notify("No changes to commit", "info");
        return;
      }

      const stat = await git(pi, ["diff", "--stat", "HEAD"], ctx.signal);
      const message = providedMessage || generateCommitMessage(statusBefore.stdout, stat.stdout);

      ctx.ui.notify(`Committing: ${message}`, "info");

      const add = await git(pi, ["add", "-A"], ctx.signal);
      if (add.code !== 0) {
        ctx.ui.notify(`git add failed: ${add.stderr || add.stdout}`, "error");
        return;
      }

      const commit = await git(pi, ["commit", "-m", message], ctx.signal);
      if (commit.code !== 0) {
        ctx.ui.notify(`git commit failed: ${commit.stderr || commit.stdout}`, "error");
        return;
      }

      const push = await git(pi, ["push"], ctx.signal);
      if (push.code !== 0) {
        ctx.ui.notify(`git push failed: ${push.stderr || push.stdout}`, "error");
        return;
      }

      ctx.ui.notify(`Committed and pushed: ${message}`, "info");
    },
  });
}
