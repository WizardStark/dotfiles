import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createEditTool, createFindTool, createGrepTool, createLsTool, createReadTool, createWriteTool } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import { compactCall, compactResult } from "./lib/compact-tool-renderers.ts";

type BadgeState = "pending" | "success" | "error";
type Badge = { id: string; name: string; state: BadgeState };

function compactBadge(theme: ExtensionContext["ui"]["theme"], label: string, state: BadgeState) {
  const background = state === "error" ? "toolErrorBg" : state === "success" ? "toolSuccessBg" : "toolPendingBg";
  return theme.style(` ${label} `, { fg: "toolTitle", bg: background });
}

function renderBadgeLines(theme: ExtensionContext["ui"]["theme"], badges: Badge[], width: number) {
  const lines: string[] = [];
  let current = "";
  let currentWidth = 0;

  for (const badge of badges) {
    const rendered = compactBadge(theme, badge.name, badge.state);
    const renderedWidth = visibleWidth(rendered);
    if (current && currentWidth + 1 + renderedWidth > width) {
      lines.push(current);
      current = "";
      currentWidth = 0;
    }
    if (current) {
      current += " ";
      currentWidth += 1;
    }
    current += rendered;
    currentWidth += renderedWidth;
  }
  if (current) lines.push(current);
  return lines;
}

// Pi has no renderer-only registration API: an override must delegate execution
// and return the original result unchanged. zsh-env owns the bash override.
export default function toolBadges(pi: ExtensionAPI) {
  let renderersRegistered = false;
  function registerRenderers() {
    if (renderersRegistered) return;
    const cwd = process.cwd();
    const tools = {
      edit: createEditTool(cwd),
      find: createFindTool(cwd),
      grep: createGrepTool(cwd),
      ls: createLsTool(cwd),
      read: createReadTool(cwd),
      write: createWriteTool(cwd),
    };
    for (const name of Object.keys(tools) as Array<keyof typeof tools>) {
      const base = tools[name];
      pi.registerTool({
        ...base,
        name,
        renderShell: "self",
        // Forward ctx too: reads need its cwd and model image limits.
        execute(toolCallId, params, signal, onUpdate, ctx) {
          return base.execute(toolCallId, params, signal, onUpdate, ctx);
        },
        renderCall(_args, theme, context) {
          return compactCall(name, theme, context);
        },
        renderResult: compactResult,
      });
    }
    renderersRegistered = true;
  }

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
      ctx.ui.setWidget("tool-badges", [badges.map((badge) => compactBadge(ctx.ui.theme, badge.name, badge.state)).join(" ")]);
      return;
    }
    ctx.ui.setWidget("tool-badges", (_tui, theme) => ({
      invalidate() {},
      render(width: number) {
        return renderBadgeLines(theme, badges, width);
      },
    }));
  }

  pi.on("session_start", async (_event, ctx) => {
    recentBadges = [];
    pendingBadges = new Map();
    if (ctx.hasUI) ctx.ui.setToolsExpanded(false);
    updateWidget(ctx);
    registerRenderers();
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setToolsExpanded(false);
    registerRenderers();
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
    });
    recentBadges = recentBadges.slice(-16);
    updateWidget(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setWidget("tool-badges", undefined);
  });
}
