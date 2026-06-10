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


function setStatus(ctx: ExtensionContext, content: string, compactContent = content) {
  if (!ctx.hasUI) {
    return;
  }

  statuslineItem.set({ content, compactContent }, getStatuslineSessionKey(ctx));
}

export default function turnTimer(pi: ExtensionAPI) {
  let startedAt: number | undefined;
  let statusTimer: ReturnType<typeof setInterval> | undefined;
  let lastDurationMs: number | undefined;

  function clearLiveStatus() {
    if (statusTimer) {
      clearInterval(statusTimer);
      statusTimer = undefined;
    }
  }

  function renderIdleStatus(ctx: ExtensionContext) {
    if (lastDurationMs === undefined) {
      setStatus(ctx, ctx.ui.theme.fg("dim", "Idle"));
      return;
    }

    const duration = formatDuration(lastDurationMs);
    setStatus(
      ctx,
      `${ctx.ui.theme.fg("success", "✓")}${ctx.ui.theme.fg("dim", ` Last turn ${duration}`)}`,
      `${ctx.ui.theme.fg("success", "✓")}${ctx.ui.theme.fg("dim", ` ${duration}`)}`,
    );
  }

  function renderRunningStatus(ctx: ExtensionContext, runStartedAt: number) {
    const elapsed = formatDuration(Math.max(0, Date.now() - runStartedAt));
    setStatus(
      ctx,
      `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` Running ${elapsed}`)}`,
      `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` ${elapsed}`)}`,
    );
  }

  function startLiveStatus(ctx: ExtensionContext, runStartedAt: number) {
    clearLiveStatus();

    const refresh = () => {
      renderRunningStatus(ctx, runStartedAt);
    };

    refresh();
    statusTimer = setInterval(refresh, STATUS_INTERVAL_MS);
  }

  pi.on("session_start", async (_event, ctx) => {
    clearLiveStatus();
    startedAt = undefined;
    renderIdleStatus(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (startedAt !== undefined) {
      return;
    }

    startedAt = Date.now();
    startLiveStatus(ctx, startedAt);
  });

  pi.on("agent_end", async (_event, ctx) => {
    const runStartedAt = startedAt;

    clearLiveStatus();
    startedAt = undefined;

    if (runStartedAt === undefined) {
      renderIdleStatus(ctx);
      return;
    }

    lastDurationMs = Math.max(0, Date.now() - runStartedAt);
    renderIdleStatus(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    clearLiveStatus();
    statuslineItem.clear(getStatuslineSessionKey(ctx));
    startedAt = undefined;
    lastDurationMs = undefined;
  });
}
