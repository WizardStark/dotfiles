import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  createBashTool,
  createEditTool,
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
  createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Text, visibleWidth } from "@earendil-works/pi-tui";

type BuiltInToolName = "bash" | "edit" | "find" | "grep" | "ls" | "read" | "write";
type BadgeState = "pending" | "success" | "error";

type Badge = {
  id: string;
  name: string;
  state: BadgeState;
};

type CtxBridgeHandle = {
  shutdown: () => void;
};

type CapturedCtxTool = {
  name: string;
  label?: string;
  description: string;
  parameters: unknown;
  execute: (toolCallId: string, params: Record<string, unknown>) => Promise<{
    content: Array<{ type?: string; text?: string; data?: string; mimeType?: string }>;
    details?: Record<string, unknown>;
    isError?: boolean;
  }>;
};

const toolCache = new Map<string, ReturnType<typeof createBuiltInTools>>();

function createBuiltInTools(cwd: string) {
  return {
    bash: createBashTool(cwd),
    edit: createEditTool(cwd),
    find: createFindTool(cwd),
    grep: createGrepTool(cwd),
    ls: createLsTool(cwd),
    read: createReadTool(cwd),
    write: createWriteTool(cwd),
  };
}

function getBuiltInTools(cwd: string) {
  let tools = toolCache.get(cwd);
  if (!tools) {
    tools = createBuiltInTools(cwd);
    toolCache.set(cwd, tools);
  }
  return tools;
}

function badgeBgToken(state: BadgeState) {
  switch (state) {
    case "error":
      return "toolErrorBg" as const;
    case "success":
      return "toolSuccessBg" as const;
    default:
      return "toolPendingBg" as const;
  }
}

function compactBadge(theme: any, label: string, state: BadgeState) {
  const text = theme.fg("toolTitle", ` ${label} `);
  return theme.bg(badgeBgToken(state), text);
}

function firstTextBlock(result: { content?: Array<{ type?: string; text?: string }> } | undefined) {
  const block = result?.content?.find((item) => item.type === "text" && typeof item.text === "string");
  return block?.text ?? "";
}

function formatExpandedResult(name: string, result: { content?: Array<{ type?: string; text?: string }>; details?: Record<string, unknown> }, theme: any) {
  if (name === "edit" && typeof result.details?.diff === "string") {
    return result.details.diff
      .split("\n")
      .map((line) => {
        if (line.startsWith("+") && !line.startsWith("+++")) return theme.fg("toolDiffAdded", line);
        if (line.startsWith("-") && !line.startsWith("---")) return theme.fg("toolDiffRemoved", line);
        return theme.fg("toolDiffContext", line);
      })
      .join("\n");
  }

  const text = firstTextBlock(result);
  if (!text) return "";
  return text
    .split("\n")
    .map((line) => theme.fg("toolOutput", line))
    .join("\n");
}

function renderCollapsedToolCall(name: string, theme: any, context: any) {
  const state: BadgeState = context.isError ? "error" : context.isPartial ? "pending" : "success";
  return new Text(compactBadge(theme, name, state), 0, 0);
}

function renderCollapsedToolResult(name: string, result: any, options: { expanded: boolean; isPartial: boolean }, theme: any, context: any) {
  if (options.isPartial) {
    return new Text("", 0, 0);
  }

  if (!options.expanded && !context.isError) {
    return new Text("", 0, 0);
  }

  const text = formatExpandedResult(name, result, theme);
  if (!text) {
    return new Text("", 0, 0);
  }

  return new Text(`\n${text}`, 0, 0);
}

function registerBuiltInMinimalTools(pi: ExtensionAPI) {
  const names: BuiltInToolName[] = ["bash", "edit", "find", "grep", "ls", "read", "write"];

  for (const name of names) {
    const base = getBuiltInTools(process.cwd())[name];
    pi.registerTool({
      name,
      label: name,
      description: base.description,
      parameters: base.parameters,
      renderShell: "self",
      async execute(toolCallId, params, signal, onUpdate, ctx) {
        const tool = getBuiltInTools(ctx.cwd)[name];
        return tool.execute(toolCallId, params, signal, onUpdate);
      },
      renderCall(_args, theme, context) {
        return renderCollapsedToolCall(name, theme, context);
      },
      renderResult(result, options, theme, context) {
        return renderCollapsedToolResult(name, result, options, theme, context);
      },
    });
  }
}

async function captureContextModeTools(): Promise<{ handle: CtxBridgeHandle; tools: CapturedCtxTool[] } | null> {
  const home = homedir();
  const bridgePath = join(home, ".pi", "agent", "npm", "node_modules", "context-mode", "build", "adapters", "pi", "mcp-bridge.js");
  const serverScript = join(home, ".pi", "agent", "npm", "node_modules", "context-mode", "server.bundle.mjs");

  if (!existsSync(bridgePath) || !existsSync(serverScript)) {
    return null;
  }

  const bridgeModule = await import(pathToFileURL(bridgePath).href);
  const bootstrapMCPTools = bridgeModule.bootstrapMCPTools as ((
    pi: { registerTool: (tool: CapturedCtxTool) => void },
    serverScript: string,
  ) => Promise<CtxBridgeHandle>);

  const tools: CapturedCtxTool[] = [];
  const handle = await bootstrapMCPTools(
    {
      registerTool(tool) {
        if (tool.name.startsWith("ctx_")) {
          tools.push(tool);
        }
      },
    },
    serverScript,
  );

  return { handle, tools };
}

function registerContextModeMinimalTools(pi: ExtensionAPI, tools: CapturedCtxTool[]) {
  for (const tool of tools) {
    pi.registerTool({
      name: tool.name,
      label: tool.label ?? tool.name,
      description: tool.description,
      parameters: tool.parameters,
      renderShell: "self",
      async execute(toolCallId, params) {
        return tool.execute(toolCallId, params as Record<string, unknown>);
      },
      renderCall(_args, theme, context) {
        return renderCollapsedToolCall(tool.name, theme, context);
      },
      renderResult(result, options, theme, context) {
        return renderCollapsedToolResult(tool.name, result, options, theme, context);
      },
    });
  }
}

function renderBadgeLines(theme: any, badges: Badge[], width: number) {
  const lines: string[] = [];
  let current = "";
  let currentWidth = 0;

  for (const badge of badges) {
    const rendered = compactBadge(theme, badge.name, badge.state);
    const renderedWidth = visibleWidth(rendered);
    const separatorWidth = current ? 1 : 0;

    if (current && currentWidth + separatorWidth + renderedWidth > width) {
      lines.push(current);
      current = rendered;
      currentWidth = renderedWidth;
      continue;
    }

    if (current) {
      current += " ";
      currentWidth += 1;
    }

    current += rendered;
    currentWidth += renderedWidth;
  }

  if (current) {
    lines.push(current);
  }

  return lines;
}

export default function toolBadges(pi: ExtensionAPI) {
  let ctxBridge: CtxBridgeHandle | undefined;
  let ctxToolsReady = false;
  let recentBadges: Badge[] = [];
  let pendingBadges = new Map<string, Badge>();

  function updateWidget(ctx: ExtensionContext) {
    const badges = [...pendingBadges.values(), ...recentBadges].slice(-16);
    if (badges.length === 0) {
      ctx.ui.setWidget("tool-badges", undefined);
      return;
    }

    ctx.ui.setWidget("tool-badges", (_tui, theme) => ({
      invalidate() {},
      render(width: number) {
        return renderBadgeLines(theme, badges, width);
      },
    }));
  }

  async function ensureMinimalToolRenderers(ctx: ExtensionContext) {
    registerBuiltInMinimalTools(pi);

    if (!ctxToolsReady) {
      const captured = await captureContextModeTools();
      if (captured) {
        ctxBridge = captured.handle;
        registerContextModeMinimalTools(pi, captured.tools);
      }
      ctxToolsReady = true;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    recentBadges = [];
    pendingBadges = new Map();
    updateWidget(ctx);
    await ensureMinimalToolRenderers(ctx);
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    await ensureMinimalToolRenderers(ctx);
  });

  pi.on("turn_start", async (_event, ctx) => {
    recentBadges = [];
    updateWidget(ctx);
  });

  pi.on("tool_execution_start", async (event, ctx) => {
    pendingBadges.set(event.toolCallId, { id: event.toolCallId, name: event.toolName, state: "pending" });
    updateWidget(ctx);
  });

  pi.on("tool_execution_end", async (event, ctx) => {
    pendingBadges.delete(event.toolCallId);
    recentBadges.push({
      id: event.toolCallId,
      name: event.toolName,
      state: event.isError ? "error" : "success",
    });
    recentBadges = recentBadges.slice(-16);
    updateWidget(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ctx.ui.setWidget("tool-badges", undefined);
    ctxBridge?.shutdown();
    ctxBridge = undefined;
    ctxToolsReady = false;
  });
}
