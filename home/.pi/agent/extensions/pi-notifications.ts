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
  let running = false;
  let promptDepth = 0;
  let generation = 0;

  function clearStuckTimer() {
    if (stuckTimer) clearTimeout(stuckTimer);
    stuckTimer = undefined;
  }

  function armStuckTimer(ctx: ExtensionContext) {
    clearStuckTimer();
    if (!running || promptDepth > 0) return;
    const owner = generation;
    stuckTimer = setTimeout(() => {
      if (owner !== generation || !running || promptDepth > 0 || stuckReported || ctx.isIdle()) return;
      stuckReported = true;
      void appendNotification(ctx, "stuck", taskSummary, pi.getSessionName()).catch((error) => {
        if (owner === generation) ctx.ui.notify(`Pi notification failed: ${error instanceof Error ? error.message : String(error)}`, "warning");
      });
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
    if (ctx.mode === "tui" && running && !stuckReported) armStuckTimer(ctx);
  }

  pi.on("before_agent_start", (event, ctx) => {
    if (ctx.mode === "tui") taskSummary = summarize(event.prompt) || "Pi task";
  });

  pi.on("agent_start", (_event, ctx) => {
    if (ctx.mode === "tui") {
      running = true;
      startStuckTimer(ctx);
    }
  });

  pi.on("turn_start", (_event, ctx) => noteActivity(ctx));
  pi.on("message_update", (_event, ctx) => noteActivity(ctx));
  pi.on("after_provider_response", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_start", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_update", (_event, ctx) => noteActivity(ctx));
  pi.on("tool_execution_end", (_event, ctx) => noteActivity(ctx));

  pi.on("ui_prompt_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    promptDepth += 1;
    clearStuckTimer();
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    promptDepth = Math.max(0, promptDepth - 1);
    if (promptDepth === 0) noteActivity(ctx);
  });

  pi.on("agent_settled", async (event, ctx) => {
    const wasRunning = running;
    running = false;
    generation += 1;
    clearStuckTimer();
    if (ctx.mode !== "tui" || !wasRunning || event.aborted) return;

    // Read the persisted active branch after Pi has settled. This covers prompts
    // expanded by templates/skills and is more reliable than transient hooks.
    await appendNotification(ctx, "completed", latestUserTask(ctx) ?? taskSummary, pi.getSessionName());
  });

  const reset = () => {
    generation += 1;
    running = false;
    promptDepth = 0;
    stuckReported = false;
    clearStuckTimer();
  };
  pi.on("session_start", reset);
  pi.on("session_shutdown", reset);
}
