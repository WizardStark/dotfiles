import { appendFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STUCK_AFTER_MS = 5 * 60 * 1000;
const SUMMARY_LIMIT = 180;

function notificationStorePath(): string {
  return process.env.PI_NOTIFICATION_STORE
    ?? join(homedir(), ".pi", "agent", "notifications.jsonl");
}

function summarize(text: string): string {
  const singleLine = text.replace(/\s+/g, " ").trim();
  if (singleLine.length <= SUMMARY_LIMIT) return singleLine;
  return `${singleLine.slice(0, SUMMARY_LIMIT - 1).trimEnd()}…`;
}

function latestUserTask(ctx: ExtensionContext): string | undefined {
  for (const entry of [...ctx.sessionManager.getBranch()].reverse()) {
    if (entry.type !== "message" || entry.message.role !== "user") continue;

    const { content } = entry.message;
    const text = typeof content === "string"
      ? content
      : content
        .filter((part) => part.type === "text")
        .map((part) => part.text ?? "")
        .join("\n");
    if (text.trim()) return summarize(text);
  }
  return undefined;
}

function sessionDetails(ctx: ExtensionContext) {
  const sessionFile = ctx.sessionManager.getSessionFile();
  const paneId = process.env.TMUX_PANE;
  return {
    sessionKey: sessionFile ?? (paneId ? `pane:${paneId}` : `cwd:${ctx.cwd}`),
    sessionFile,
    paneId,
    // Pane IDs are only meaningful within one tmux server. Keep its socket and
    // PID so an old %N cannot route to a reused pane after a server restart.
    tmuxServer: process.env.TMUX?.split(",").slice(0, 2).join(","),
    cwd: ctx.cwd,
  };
}

async function appendNotification(
  ctx: ExtensionContext,
  kind: "completed" | "stuck",
  summary: string,
  sessionName?: string,
): Promise<void> {
  const path = notificationStorePath();
  await mkdir(dirname(path), { recursive: true });
  await appendFile(path, `${JSON.stringify({
    type: "notification",
    id: randomUUID(),
    createdAt: new Date().toISOString(),
    kind,
    summary: summarize(summary) || "Pi task",
    sessionName,
    ...sessionDetails(ctx),
  })}\n`, "utf8");
}

export default function piNotifications(pi: ExtensionAPI) {
  let taskSummary = "Pi task";
  let stuckTimer: ReturnType<typeof setTimeout> | undefined;
  let stuckReported = false;

  function clearStuckTimer() {
    if (stuckTimer) clearTimeout(stuckTimer);
    stuckTimer = undefined;
  }

  function armStuckTimer(ctx: ExtensionContext) {
    clearStuckTimer();
    stuckTimer = setTimeout(() => {
      if (stuckReported || ctx.isIdle()) return;
      stuckReported = true;
      void appendNotification(ctx, "stuck", taskSummary, pi.getSessionName());
    }, STUCK_AFTER_MS);
  }

  function startStuckTimer(ctx: ExtensionContext) {
    stuckReported = false;
    armStuckTimer(ctx);
  }

  // Activity postpones the warning. A warning therefore means Pi has had no
  // agent, model, or tool progress for five minutes rather than merely running
  // a long task.
  function noteActivity(ctx: ExtensionContext) {
    if (ctx.mode === "tui" && !stuckReported) armStuckTimer(ctx);
  }

  pi.on("before_agent_start", (event, ctx) => {
    if (ctx.mode === "tui") taskSummary = summarize(event.prompt) || "Pi task";
  });

  pi.on("agent_start", (_event, ctx) => {
    if (ctx.mode === "tui") startStuckTimer(ctx);
  });

  pi.on("turn_start", (_event, ctx) => noteActivity(ctx));
  pi.on("message_update", (_event, ctx) => noteActivity(ctx));
  pi.on("after_provider_response", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_start", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_update", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_end", (_event, ctx) => noteActivity(ctx));

  pi.on("agent_settled", async (_event, ctx) => {
    clearStuckTimer();
    if (ctx.mode !== "tui") return;

    // Read the persisted active branch after Pi has settled. This covers prompts
    // expanded by templates/skills and is more reliable than transient hooks.
    await appendNotification(ctx, "completed", latestUserTask(ctx) ?? taskSummary, pi.getSessionName());
  });

  pi.on("session_shutdown", () => {
    clearStuckTimer();
  });
}
