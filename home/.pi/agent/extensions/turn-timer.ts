import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "turn-timer";
const STATUS_INTERVAL_MS = 100;

function formatDuration(durationMs: number): string {
  if (durationMs < 1_000) return `${durationMs}ms`;
  if (durationMs < 10_000) return `${(durationMs / 1_000).toFixed(1)}s`;
  if (durationMs < 60_000) return `${Math.round(durationMs / 1_000)}s`;

  const totalSeconds = Math.round(durationMs / 1_000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return seconds === 0 ? `${minutes}m` : `${minutes}m ${seconds}s`;
}

export default function (pi: ExtensionAPI) {
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
      ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", "Idle"));
      return;
    }

    ctx.ui.setStatus(
      STATUS_KEY,
      `${ctx.ui.theme.fg("success", "✓")}${ctx.ui.theme.fg("dim", ` Last turn ${formatDuration(lastDurationMs)}`)}`,
    );
  }

  function renderRunningStatus(ctx: ExtensionContext, runStartedAt: number) {
    const elapsed = formatDuration(Math.max(0, Date.now() - runStartedAt));
    ctx.ui.setStatus(
      STATUS_KEY,
      `${ctx.ui.theme.fg("accent", "●")}${ctx.ui.theme.fg("dim", ` Running ${elapsed}`)}`,
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
    ctx.ui.setStatus(STATUS_KEY, undefined);
    startedAt = undefined;
    lastDurationMs = undefined;
  });
}
