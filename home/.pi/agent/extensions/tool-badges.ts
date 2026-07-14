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

type ToolContentBlock = { type?: string; text?: string; data?: string; mimeType?: string };

type ToolResult = {
	content: ToolContentBlock[];
	details?: Record<string, unknown>;
	isError?: boolean;
	terminate?: boolean;
};

type CapturedCtxTool = {
	name: string;
	label?: string;
	description: string;
	parameters: unknown;
	execute: (toolCallId: string, params: Record<string, unknown>) => Promise<ToolResult>;
};

const ORIGINAL_TEXT_KEY = "__toolBadgesOriginalText";
const TOOL_CACHE = new Map<string, ReturnType<typeof createBuiltInTools>>();

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
	let tools = TOOL_CACHE.get(cwd);
	if (!tools) {
		tools = createBuiltInTools(cwd);
		TOOL_CACHE.set(cwd, tools);
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

function getTextContent(result: { content?: ToolContentBlock[] } | undefined) {
	return result?.content
		?.filter((item) => item.type === "text" && typeof item.text === "string")
		.map((item) => item.text as string)
		.join("\n") ?? "";
}

function getOriginalText(result: { details?: Record<string, unknown> } | undefined) {
	const text = result?.details?.[ORIGINAL_TEXT_KEY];
	return typeof text === "string" ? text : "";
}

function withOriginalText(result: ToolResult, originalText: string): ToolResult {
	return {
		...result,
		details: {
			...(result.details ?? {}),
			[ORIGINAL_TEXT_KEY]: originalText,
		},
	};
}

function linePreview(text: string, maxLines = 20) {
	const lines = text.split("\n");
	const preview = lines.slice(0, maxLines);
	if (lines.length > maxLines) {
		preview.push(`... ${lines.length - maxLines} more lines`);
	}
	return preview;
}

function renderPreviewText(text: string, theme: any, maxLines = 20) {
	if (!text) return "";
	return linePreview(text, maxLines)
		.map((line) => theme.fg("toolOutput", line))
		.join("\n");
}

function wrapErrorResult(result: ToolResult): ToolResult {
	const originalText = getTextContent(result);
	const errorText = originalText || (typeof result.details?.error === "string" ? `Error: ${result.details.error}` : "Error");
	return {
		...result,
		content: [{ type: "text", text: "⚠ failed" }],
		details: {
			...(result.details ?? {}),
			[ORIGINAL_TEXT_KEY]: errorText,
		},
	};
}

function wrapSuccessResult(result: ToolResult): ToolResult {
	return withOriginalText(result, getTextContent(result));
}

function normalizeResult(result: ToolResult): ToolResult {
	return result.isError ? wrapErrorResult(result) : wrapSuccessResult(result);
}

function renderGenericResult(result: ToolResult, options: { expanded: boolean; isPartial: boolean }, theme: any, context: any) {
	if (options.isPartial) {
		return new Text(theme.fg("warning", "Running..."), 0, 0);
	}

	const first = result.content?.[0];
	if (first?.type === "image") {
		return new Text(theme.fg("success", "Image loaded"), 0, 0);
	}

	if (context.isError || result.isError) {
		if (!options.expanded) {
			return new Text(theme.fg("error", "⚠ failed"), 0, 0);
		}
		const text = getOriginalText(result) || getTextContent(result) || "";
		if (!text) {
			return new Text(theme.fg("error", "⚠ failed"), 0, 0);
		}
		return new Text(`\n${renderPreviewText(text, theme)}`, 0, 0);
	}

	if (!options.expanded) {
		return new Text("", 0, 0);
	}

	const text = getOriginalText(result) || getTextContent(result) || "";
	if (!text) {
		return new Text("", 0, 0);
	}

	return new Text(`\n${renderPreviewText(text, theme)}`, 0, 0);
}

function registerBuiltInMinimalTools(pi: ExtensionAPI) {
	const names: BuiltInToolName[] = ["bash", "edit", "find", "grep", "ls", "read", "write"];

	for (const name of names) {
		const base = getBuiltInTools(process.cwd())[name];
		pi.registerTool({
			...base,
			name,
			label: name,
			renderShell: "self",
			async execute(toolCallId, params, signal, onUpdate, ctx) {
				const tool = getBuiltInTools(ctx.cwd)[name];
				const result = await tool.execute(toolCallId, params, signal, onUpdate);
				return normalizeResult(result as ToolResult);
			},
			renderCall(_args, theme, context) {
				return renderCollapsedToolCall(name, theme, context);
			},
			renderResult(result, options, theme, context) {
				return renderGenericResult(result as ToolResult, options, theme, context);
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
				const result = await tool.execute(toolCallId, params as Record<string, unknown>);
				return normalizeResult(result);
			},
			renderCall(_args, theme, context) {
				return renderCollapsedToolCall(tool.name, theme, context);
			},
			renderResult(result, options, theme, context) {
				return renderGenericResult(result as ToolResult, options, theme, context);
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

function renderBadgeSummary(theme: any, badges: Badge[]) {
	return badges.length === 0 ? [] : [badges.map((badge) => compactBadge(theme, badge.name, badge.state)).join(" ")];
}

export default function toolBadges(pi: ExtensionAPI) {
	let ctxBridge: CtxBridgeHandle | undefined;
	let ctxToolsReady = false;
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
			ctx.ui.setWidget("tool-badges", renderBadgeSummary(ctx.ui.theme, badges));
			return;
		}

		ctx.ui.setWidget("tool-badges", (_tui, theme) => ({
			invalidate() {},
			render(width: number) {
				return renderBadgeLines(theme, badges, width);
			},
		}));
	}

	function collapseToolOutputs(ctx: ExtensionContext) {
		if (!ctx.hasUI) return;
		ctx.ui.setToolsExpanded(false);
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
		collapseToolOutputs(ctx);
		updateWidget(ctx);
		await ensureMinimalToolRenderers(ctx);
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		collapseToolOutputs(ctx);
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
