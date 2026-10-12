import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { formatDuration } from "./lib/format.ts";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { compactRenderers } from "./lib/compact-tool-renderers.ts";

type BadgeState = "pending" | "success" | "error";
type Badge = { id: string; name: string; state: BadgeState; durationMs?: number };

function badgeLabel(badge: Badge) {
  return `${badge.name}${badge.durationMs === undefined ? "" : ` ${formatDuration(Math.round(badge.durationMs))}`}`;
}

function compactBadge(theme: ExtensionContext["ui"]["theme"], label: string, state: BadgeState) {
  const background = state === "error" ? "toolErrorBg" : state === "success" ? "toolSuccessBg" : "toolPendingBg";
  return theme.style(` ${label} `, { fg: "toolTitle", bg: background });
}

function renderBadgeLines(theme: ExtensionContext["ui"]["theme"], badges: Badge[], width: number) {
  const lines: string[] = [];
  let current = "";
  let currentWidth = 0;

  for (const badge of badges) {
    const rendered = compactBadge(theme, badgeLabel(badge), badge.state);
    const clipped = truncateToWidth(rendered, width);
    const renderedWidth = visibleWidth(clipped);
    if (current && currentWidth + 1 + renderedWidth > width) {
      lines.push(current);
      current = "";
      currentWidth = 0;
    }
    if (current) {
      current += " ";
      currentWidth += 1;
    }
    current += clipped;
    currentWidth += renderedWidth;
  }
  if (current) lines.push(current);
  return lines;
}

// Rendering is independent of tool registration and execution (including zsh bash).
export default function toolBadges(pi: ExtensionAPI) {
  const names = new Set(["bash", "edit", "find", "grep", "ls", "read", "write"]);
  pi.registerToolRenderer((name, next) => names.has(name) ? compactRenderers(name, next()) : next());

  let recentBadges: Badge[] = [];
  let pendingBadges = new Map<string, Badge>();

  function updateWidget(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    const badges = [...pendingBadges.values(), ...recentBadges].slice(-16);
    if (badges.length === 0) {
      ctx.ui.setWidget("tool-badges", undefined);
      return;
    }
    if (ctx.mode !== "tui") {
      ctx.ui.setWidget("tool-badges", [badges.map((badge) => compactBadge(ctx.ui.theme, badgeLabel(badge), badge.state)).join(" ")]);
      return;
    }
    ctx.ui.setWidget("tool-badges", (_tui, _theme) => ({
      invalidate() {},
      render(width: number) {
        return renderBadgeLines(ctx.ui.theme, badges, width);
      },
    }));
  }

  pi.on("session_start", async (_event, ctx) => {
    recentBadges = [];
    pendingBadges = new Map();
    if (ctx.hasUI) ctx.ui.setToolsExpanded(false);
    updateWidget(ctx);
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setToolsExpanded(false);
  });

  pi.on("turn_start", async (_event, ctx) => {
    recentBadges = [];
    updateWidget(ctx);
  });

  pi.on("tool_execution_start", async (event, ctx) => {
    const name = event.parentToolCallId ? `↳ ${event.toolName}` : event.toolName;
    pendingBadges.set(event.toolCallId, { id: event.toolCallId, name, state: "pending" });
    updateWidget(ctx);
  });

  pi.on("tool_execution_end", async (event, ctx) => {
    const pending = pendingBadges.get(event.toolCallId);
    pendingBadges.delete(event.toolCallId);
    recentBadges.push({
      id: event.toolCallId,
      name: pending?.name ?? (event.parentToolCallId ? `↳ ${event.toolName}` : event.toolName),
      state: event.isError ? "error" : "success",
      durationMs: event.durationMs,
    });
    recentBadges = recentBadges.slice(-16);
    updateWidget(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setWidget("tool-badges", undefined);
  });
}
