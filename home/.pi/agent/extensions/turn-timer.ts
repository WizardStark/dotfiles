import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

const TURN_TIMER_TYPE = "agent-turn-duration";
const STATUS_KEY = "turn-timer";
const STATUS_INTERVAL_MS = 100;

type TimerDetails = {
  durationMs: number;
  startedAt: number;
  endedAt: number;
};

function formatDuration(durationMs: number): string {
  if (durationMs < 1_000) return `${durationMs}ms`;
  if (durationMs < 10_000) return `${(durationMs / 1_000).toFixed(1)}s`;
  if (durationMs < 60_000) return `${Math.round(durationMs / 1_000)}s`;

  const totalSeconds = Math.round(durationMs / 1_000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return seconds === 0 ? `${minutes}m` : `${minutes}m ${seconds}s`;
}

function formatTimestamp(timestamp: number): string {
  return new Date(timestamp).toLocaleTimeString();
}

export default function (pi: ExtensionAPI) {
  let startedAt: number | undefined;
  let statusTimer: ReturnType<typeof setInterval> | undefined;

  function clearLiveStatus(ctx: ExtensionContext) {
    if (statusTimer) {
      clearInterval(statusTimer);
      statusTimer = undefined;
    }
  }

  function setLiveStatus(ctx: ExtensionContext, label: string) {
    ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", label));
  }

  function startLiveStatus(ctx: ExtensionContext, runStartedAt: number) {
    clearLiveStatus(ctx);

    const refresh = () => {
      setLiveStatus(ctx, formatDuration(Math.max(0, Date.now() - runStartedAt)));
    };

    refresh();
    statusTimer = setInterval(refresh, STATUS_INTERVAL_MS);
  }

  pi.registerMessageRenderer(TURN_TIMER_TYPE, (message, { expanded }, theme) => {
    const details = (message.details ?? {}) as Partial<TimerDetails>;
    const durationMs = typeof details.durationMs === "number" ? details.durationMs : undefined;
    const started = typeof details.startedAt === "number" ? details.startedAt : undefined;
    const ended = typeof details.endedAt === "number" ? details.endedAt : undefined;
    const summary = typeof message.content === "string" ? message.content : durationMs ? formatDuration(durationMs) : "Turn complete";

    const lines = [
      `${theme.fg("muted", "Agent turn")}${theme.fg("dim", " took ")}${theme.fg("accent", summary)}`,
    ];

    if (expanded && durationMs !== undefined) {
      if (started !== undefined && ended !== undefined) {
        lines.push(theme.fg("dim", `${formatTimestamp(started)} → ${formatTimestamp(ended)}`));
      }
      lines.push(theme.fg("dim", `${durationMs.toLocaleString()} ms`));
    }

    const box = new Box(1, 0, (text) => theme.bg("customMessageBg", text));
    box.addChild(new Text(lines.join("\n"), 0, 0));
    return box;
  });

  pi.on("context", async (event) => {
    return {
      messages: event.messages.filter(
        (message) => !(message.role === "custom" && message.customType === TURN_TIMER_TYPE),
      ),
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    clearLiveStatus(ctx);
    startedAt = undefined;
    ctx.ui.setStatus(STATUS_KEY, undefined);
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

    clearLiveStatus(ctx);
    startedAt = undefined;

    if (runStartedAt === undefined) {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }

    const endedAt = Date.now();
    const durationMs = Math.max(0, endedAt - runStartedAt);

    pi.sendMessage({
      customType: TURN_TIMER_TYPE,
      content: formatDuration(durationMs),
      display: true,
      details: {
        durationMs,
        startedAt: runStartedAt,
        endedAt,
      } satisfies TimerDetails,
    });
    ctx.ui.setStatus(STATUS_KEY, undefined);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    clearLiveStatus(ctx);
    ctx.ui.setStatus(STATUS_KEY, undefined);
    startedAt = undefined;
  });
}
