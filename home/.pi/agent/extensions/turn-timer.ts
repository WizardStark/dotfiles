import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { formatDuration } from "./lib/format.ts";
import { createStatuslineItem, getStatuslineSessionKey } from "./statusline/registry";

const STATUS_KEY = "turn-timer";
const STATUS_INTERVAL_MS = 100;

const statuslineItem = createStatuslineItem({
  id: STATUS_KEY,
  side: "left",
  order: 20,
  importance: 60,
  background: "toolSuccessBg",
});


export default function turnTimer(pi: ExtensionAPI) {
  let startedAt: number | undefined;
  let statusTimer: ReturnType<typeof setInterval> | undefined;
  let lastDurationMs: number | undefined;
  let lastAborted = false;
  let promptDepth = 0;

  function clearLiveStatus() {
    if (statusTimer) {
      clearInterval(statusTimer);
      statusTimer = undefined;
    }
  }

  function renderIdleStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    if (lastDurationMs === undefined) {
      statuslineItem.set({
        background: "toolSuccessBg",
        content: (theme) => theme.fg("dim", "Idle"),
        compactContent: (theme) => theme.fg("dim", "Idle"),
      }, getStatuslineSessionKey(ctx));
      return;
    }

    const duration = formatDuration(lastDurationMs);
    const aborted = lastAborted;
    statuslineItem.set({
      background: aborted ? "toolPendingBg" : "toolSuccessBg",
      content: (theme) => `${theme.fg(aborted ? "warning" : "success", aborted ? "⊘" : "✓")}${theme.fg("dim", ` ${aborted ? "Interrupted" : "Last turn"} ${duration}`)}`,
      compactContent: (theme) => `${theme.fg(aborted ? "warning" : "success", aborted ? "⊘" : "✓")}${theme.fg("dim", ` ${duration}`)}`,
    }, getStatuslineSessionKey(ctx));
  }

  function renderRunningStatus(ctx: ExtensionContext, runStartedAt: number) {
    if (!ctx.hasUI) return;
    const elapsed = formatDuration(Math.max(0, Date.now() - runStartedAt));
    const waiting = promptDepth > 0;
    statuslineItem.set({
      background: "toolPendingBg",
      content: (theme) => `${theme.fg(waiting ? "warning" : "accent", waiting ? "◷" : "●")}${theme.fg("dim", ` ${waiting ? "Awaiting input" : "Running"} ${elapsed}`)}`,
      compactContent: (theme) => `${theme.fg(waiting ? "warning" : "accent", waiting ? "◷" : "●")}${theme.fg("dim", ` ${elapsed}`)}`,
    }, getStatuslineSessionKey(ctx));
  }

  function startLiveStatus(ctx: ExtensionContext, runStartedAt: number) {
    clearLiveStatus();

    const refresh = () => {
      renderRunningStatus(ctx, runStartedAt);
    };

    if (!ctx.hasUI) return;
    refresh();
    statusTimer = setInterval(refresh, STATUS_INTERVAL_MS);
  }

  pi.on("session_start", async (_event, ctx) => {
    clearLiveStatus();
    startedAt = undefined;
    lastDurationMs = undefined;
    lastAborted = false;
    promptDepth = 0;
    renderIdleStatus(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (startedAt !== undefined) {
      return;
    }

    startedAt = Date.now();
    startLiveStatus(ctx, startedAt);
  });

  pi.on("ui_prompt_start", (_event, ctx) => {
    promptDepth += 1;
    if (startedAt !== undefined) renderRunningStatus(ctx, startedAt);
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    promptDepth = Math.max(0, promptDepth - 1);
    if (startedAt !== undefined) renderRunningStatus(ctx, startedAt);
  });

  pi.on("agent_settled", async (event, ctx) => {
    const runStartedAt = startedAt;

    clearLiveStatus();
    startedAt = undefined;

    if (runStartedAt === undefined) {
      renderIdleStatus(ctx);
      return;
    }

    lastAborted = event.aborted;
    lastDurationMs = Math.max(0, Date.now() - runStartedAt);
    renderIdleStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    clearLiveStatus();
    statuslineItem.clear(getStatuslineSessionKey(ctx));
    startedAt = undefined;
    lastDurationMs = undefined;
    promptDepth = 0;
  });
}
