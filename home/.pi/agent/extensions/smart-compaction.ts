import { complete } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ExtensionCommandContext, Theme } from "@earendil-works/pi-coding-agent";
import { convertToLlm, estimateTokens, serializeConversation } from "@earendil-works/pi-coding-agent";
import { matchesKey, visibleWidth } from "@earendil-works/pi-tui";

import { estimateTextTokens, chunkText, chunkSections } from "./lib/text-chunking.ts";
import { TransientWidget } from "./lib/ui-widgets.ts";

type ModelLike = {
	id: string;
	provider: string;
	contextWindow?: number;
	maxTokens?: number;
};

type ResolvedSummarizer = {
	model: ModelLike;
	apiKey?: string;
	headers?: Record<string, string>;
};

type FileOps = {
	readFiles?: string[];
	modifiedFiles?: string[];
};

type ReplayInput = {
	content: string | unknown[];
	fallbackText?: string;
};

type Thresholds = {
	contextWindow: number;
	responseReserve: number;
	promptReserve: number;
	compactThreshold: number;
	warningThreshold: number;
};

const STATUS_KEY = "smart-compact";
const THRESHOLD_WIDGET = new TransientWidget("smart-compaction-thresholds", { placement: "belowEditor" });
const DEFAULT_CONTEXT_WINDOW = 128_000;
const DEFAULT_MAX_TOKENS = 8_192;
const PARTIAL_SUMMARY_MAX_TOKENS = 12_000;
const FINAL_SUMMARY_MAX_TOKENS = 16_000;
const PARTIAL_SUMMARY_PROMPT_RESERVE = 6_000;
const FINAL_SUMMARY_PROMPT_RESERVE = 8_000;
const MIN_CHUNK_INPUT_TOKENS = 3_000;
const MIN_MERGE_INPUT_TOKENS = 4_000;
const WARNING_GAP_CAP = 24_000;
const COMPACTION_QUEUE_LIMIT = 8;

const PREFERRED_SUMMARIZERS: Array<{ provider: string; id: string }> = [
	{ provider: "github-copilot", id: "gpt-5.4-mini" },
	{ provider: "github-copilot", id: "gpt-5.4" },
	{ provider: "github-copilot", id: "gpt-5.4-nano" },
	{ provider: "openai", id: "gpt-5.4-mini" },
	{ provider: "openai", id: "gpt-5.4" },
];

function clamp(value: number, min: number, max: number): number {
	return Math.min(Math.max(value, min), max);
}

function uniqueSorted(values: string[] | undefined): string[] {
	return [...new Set((values ?? []).filter(Boolean))].sort();
}

function getFileDetails(fileOps: FileOps | undefined) {
	return {
		readFiles: uniqueSorted(fileOps?.readFiles),
		modifiedFiles: uniqueSorted(fileOps?.modifiedFiles),
	};
}

function serializeFileSection(tag: "read-files" | "modified-files", files: string[]): string {
	if (files.length === 0) return `<${tag}></${tag}>`;
	return `<${tag}>\n${files.join("\n")}\n</${tag}>`;
}

function summarizeFileOps(fileOps: FileOps | undefined): string {
	const details = getFileDetails(fileOps);
	return [
		serializeFileSection("read-files", details.readFiles),
		serializeFileSection("modified-files", details.modifiedFiles),
	].join("\n\n");
}

function responseText(response: { content: Array<{ type: string; text?: string }> }): string {
	return response.content
		.filter((item): item is { type: "text"; text: string } => item.type === "text" && typeof item.text === "string")
		.map((item) => item.text)
		.join("\n")
		.trim();
}

function getThresholds(model: ModelLike): Thresholds {
	const contextWindow = Math.max(model.contextWindow ?? DEFAULT_CONTEXT_WINDOW, 8_000);
	const maxTokens = Math.max(model.maxTokens ?? DEFAULT_MAX_TOKENS, 1_024);
	const responseReserve = clamp(
		Math.floor(maxTokens * 0.5),
		2_048,
		Math.max(2_048, Math.min(96_000, Math.floor(contextWindow * 0.3))),
	);
	const promptReserve = clamp(
		Math.floor(contextWindow * 0.03),
		1_024,
		Math.max(1_024, Math.min(12_000, Math.floor(contextWindow * 0.08))),
	);
	const compactThreshold = Math.max(0, contextWindow - responseReserve - promptReserve);
	const warningGap = Math.min(WARNING_GAP_CAP, Math.floor(contextWindow * 0.08));
	const warningThreshold = Math.max(0, compactThreshold - warningGap);
	return { contextWindow, responseReserve, promptReserve, compactThreshold, warningThreshold };
}

function formatPercent(tokens: number, total: number): string {
	if (!total) return "0%";
	return `${Math.round((tokens / total) * 100)}%`;
}

function buildStatus(ctx: ExtensionContext): string | undefined {
	const model = ctx.model as ModelLike | undefined;
	const usage = ctx.getContextUsage();
	if (!model?.contextWindow || !usage?.tokens) return undefined;

	const thresholds = getThresholds(model);
	const tokens = usage.tokens;
	if (tokens >= thresholds.compactThreshold) {
		return `ctx ${formatPercent(tokens, thresholds.contextWindow)} · compact on next prompt`;
	}
	if (tokens >= thresholds.warningThreshold) {
		return `ctx ${formatPercent(tokens, thresholds.contextWindow)} · nearing compaction`;
	}
	return undefined;
}

function updateStatus(ctx: ExtensionContext) {
	if (!ctx.hasUI) return;
	ctx.ui.setStatus(STATUS_KEY, buildStatus(ctx));
}

function formatTokens(tokens: number | undefined): string {
	if (tokens === undefined || Number.isNaN(tokens)) return "unknown";
	return tokens.toLocaleString();
}

async function buildThresholdLines(ctx: ExtensionContext): Promise<string[]> {
	const model = ctx.model as ModelLike | undefined;
	if (!model?.contextWindow) {
		return ["Smart compaction thresholds unavailable: active model has no context window metadata."];
	}

	const thresholds = getThresholds(model);
	const usage = ctx.getContextUsage();
	const summarizer = await resolveSummarizer(ctx);
	const usageTokens = usage?.tokens;
	const lines = [
		`smart compaction thresholds`,
		`model: ${model.provider}/${model.id}`,
		`context window: ${formatTokens(thresholds.contextWindow)}`,
		`model max output: ${formatTokens(model.maxTokens)}`,
		`response reserve: ${formatTokens(thresholds.responseReserve)}`,
		`prompt reserve: ${formatTokens(thresholds.promptReserve)}`,
		`warning threshold: ${formatTokens(thresholds.warningThreshold)}`,
		`compact threshold: ${formatTokens(thresholds.compactThreshold)}`,
		`current usage: ${formatTokens(usageTokens)}`,
		`remaining to compact: ${usageTokens === undefined ? "unknown" : formatTokens(Math.max(0, thresholds.compactThreshold - usageTokens))}`,
		`overflow hard edge: ${formatTokens(thresholds.contextWindow - thresholds.responseReserve)}`,
		`summarizer: ${summarizer ? `${summarizer.model.provider}/${summarizer.model.id}` : "unavailable (falls back to built-in compaction if manual compaction runs)"}`,
	];
	return lines;
}

class ThresholdOverlay {
	private readonly theme: Theme;
	private readonly lines: string[];
	private readonly done: () => void;
	private readonly width: number;

	constructor(theme: Theme, lines: string[], done: () => void) {
		this.theme = theme;
		this.lines = lines;
		this.done = done;
		const contentWidth = Math.max(...lines.map((line) => visibleWidth(line)), 40);
		this.width = Math.min(110, Math.max(52, contentWidth + 4));
	}

	handleInput(data: string) {
		if (matchesKey(data, "escape") || matchesKey(data, "return") || matchesKey(data, "q")) {
			this.done();
		}
	}

	render(_width: number): string[] {
		const innerWidth = this.width - 2;
		const pad = (text = "") => text + " ".repeat(Math.max(0, innerWidth - visibleWidth(text)));
		const row = (content = "") => this.theme.fg("border", "│") + pad(content) + this.theme.fg("border", "│");
		return [
			this.theme.fg("border", `╭${"─".repeat(innerWidth)}╮`),
			row(` ${this.theme.bold(this.theme.fg("accent", "Smart compaction thresholds"))}`),
			row(),
			...this.lines.map((line) => row(` ${line}`)),
			row(),
			row(` ${this.theme.fg("dim", "Enter / Esc / q to close")}`),
			this.theme.fg("border", `╰${"─".repeat(innerWidth)}╯`),
		];
	}

	invalidate() {}
}

async function showThresholdOverlay(ctx: ExtensionCommandContext) {
	const lines = await buildThresholdLines(ctx);
	if (!ctx.hasUI) return;

	if (ctx.mode !== "tui") {
		THRESHOLD_WIDGET.set(ctx, lines);
		return;
	}

	await ctx.ui.custom<void>(
		(_tui, theme, _keybindings, done) => new ThresholdOverlay(theme, lines, () => done()),
		{
			overlay: true,
			overlayOptions: {
				anchor: "center",
				width: "70%",
				minWidth: 52,
				maxWidth: 110,
				margin: 1,
			},
		},
	);
}

function restoreReplayInputs(ctx: ExtensionContext, queued: ReplayInput[]) {
	if (!ctx.hasUI || queued.length !== 1) return;
	const [input] = queued;
	if (!input.fallbackText) return;
	ctx.ui.setEditorText(input.fallbackText);
}

function shouldCompactBeforePrompt(ctx: ExtensionContext, promptText: string): boolean {
	const model = ctx.model as ModelLike | undefined;
	const usage = ctx.getContextUsage();
	if (!model?.contextWindow || !usage?.tokens) return false;

	const thresholds = getThresholds(model);
	const currentTokens = usage.tokens;
	const promptTokens = estimateTextTokens(promptText || "continue");
	const projectedTokens = currentTokens + promptTokens;
	const hardPromptThreshold = thresholds.contextWindow - thresholds.responseReserve;

	return currentTokens >= thresholds.compactThreshold || projectedTokens >= hardPromptThreshold;
}

function isOverflowMessage(message: unknown): boolean {
	if (!message || typeof message !== "object") return false;
	const candidate = message as { role?: unknown; stopReason?: unknown; errorMessage?: unknown };
	if (candidate.role !== "assistant" || candidate.stopReason !== "error") return false;
	const errorMessage = typeof candidate.errorMessage === "string" ? candidate.errorMessage : "";
	return /context(?:_|\s|-)?length(?:_|\s|-)?exceeded/i.test(errorMessage)
		|| /maximum context length/i.test(errorMessage)
		|| /context window/i.test(errorMessage)
		|| /too many tokens/i.test(errorMessage)
		|| /prompt is too long/i.test(errorMessage);
}

function getLastUserContent(ctx: ExtensionContext): string | unknown[] | undefined {
	for (const entry of [...ctx.sessionManager.getBranch()].reverse()) {
		if (entry.type !== "message") continue;
		const message = entry.message as { role?: unknown; content?: unknown };
		if (message.role !== "user") continue;
		const content = message.content;
		if (typeof content === "string") return content;
		if (Array.isArray(content)) return content;
	}
	return undefined;
}

async function resolveSummarizer(ctx: ExtensionContext): Promise<ResolvedSummarizer | undefined> {
	for (const candidate of PREFERRED_SUMMARIZERS) {
		const model = ctx.modelRegistry.find(candidate.provider, candidate.id) as ModelLike | undefined;
		if (!model) continue;
		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model as never);
		if (!auth.ok) continue;
		return { model, apiKey: auth.apiKey, headers: auth.headers };
	}

	const fallback = ctx.model as ModelLike | undefined;
	if (!fallback) return undefined;
	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(fallback as never);
	if (!auth.ok) return undefined;
	return { model: fallback, apiKey: auth.apiKey, headers: auth.headers };
}

function summarizerBudgets(model: ModelLike) {
	const contextWindow = Math.max(model.contextWindow ?? DEFAULT_CONTEXT_WINDOW, 8_000);
	const modelMaxTokens = Math.max(model.maxTokens ?? DEFAULT_MAX_TOKENS, 1_024);
	const partialMaxTokens = Math.min(PARTIAL_SUMMARY_MAX_TOKENS, Math.max(1_024, modelMaxTokens));
	const finalMaxTokens = Math.min(FINAL_SUMMARY_MAX_TOKENS, Math.max(1_024, modelMaxTokens));
	const partialInputBudget = Math.max(
		MIN_CHUNK_INPUT_TOKENS,
		contextWindow - partialMaxTokens - PARTIAL_SUMMARY_PROMPT_RESERVE,
	);
	const finalInputBudget = Math.max(
		MIN_MERGE_INPUT_TOKENS,
		contextWindow - finalMaxTokens - FINAL_SUMMARY_PROMPT_RESERVE,
	);
	return {
		partialMaxTokens,
		finalMaxTokens,
		partialInputBudget,
		finalInputBudget,
	};
}

function baseSummaryInstructions(customInstructions?: string): string {
	return [
		"You are compacting a pi coding-agent session so work can continue with minimal loss.",
		"Preserve exact technical intent, user preferences, decisions, file paths, commands, errors, blockers, and next steps.",
		"Be concise, but never omit information that would change what the assistant should do next.",
		"If something is uncertain, say so explicitly instead of inventing details.",
		"Output structured markdown using exactly these top-level sections:",
		"## Goal",
		"## Constraints & Preferences",
		"## Progress",
		"### Done",
		"### In Progress",
		"### Blocked",
		"## Key Decisions",
		"## Critical Context",
		"## Next Steps",
		"After the markdown sections, include <read-files> and <modified-files> blocks exactly once.",
		customInstructions?.trim() ? `Additional instructions:\n${customInstructions.trim()}` : "",
	]
		.filter(Boolean)
		.join("\n\n");
}

function chunkPrompt(chunk: string, index: number, total: number, fileOpsText: string, customInstructions?: string): string {
	return `${baseSummaryInstructions(customInstructions)}\n\nThis is chunk ${index} of ${total} from the conversation being compacted. Summarize only what appears in this chunk, but keep details that matter for continuation.\n\n${fileOpsText}\n\n<conversation-chunk index="${index}" total="${total}">\n${chunk}\n</conversation-chunk>`;
}

function mergePrompt(
	summaries: string,
	fileOpsText: string,
	previousSummary?: string,
	customInstructions?: string,
): string {
	const previousBlock = previousSummary?.trim()
		? `\n\n<previous-summary>\n${previousSummary.trim()}\n</previous-summary>`
		: "";
	return `${baseSummaryInstructions(customInstructions)}\n\nMerge the partial summaries below into one final continuation-safe compaction summary. Deduplicate repeated facts, preserve chronology where it matters, and keep the final summary action-oriented.${previousBlock}\n\n${fileOpsText}\n\n<partial-summaries>\n${summaries}\n</partial-summaries>`;
}

async function callSummarizer(
	resolved: ResolvedSummarizer,
	prompt: string,
	maxTokens: number,
	signal: AbortSignal,
): Promise<string> {
	const response = await complete(
		resolved.model as never,
		{
			messages: [
				{
					role: "user",
					content: [{ type: "text", text: prompt }],
					timestamp: Date.now(),
				},
			],
		},
		{
			apiKey: resolved.apiKey,
			headers: resolved.headers,
			maxTokens,
			signal,
		},
	);
	return responseText(response as { content: Array<{ type: string; text?: string }> });
}

async function summarizeConversation(
	conversationText: string,
	previousSummary: string | undefined,
	fileOps: FileOps | undefined,
	customInstructions: string | undefined,
	resolved: ResolvedSummarizer,
	signal: AbortSignal,
): Promise<string> {
	const budgets = summarizerBudgets(resolved.model);
	const fileOpsText = summarizeFileOps(fileOps);
	const chunks = chunkText(conversationText, budgets.partialInputBudget);
	const partials: string[] = [];

	for (let index = 0; index < chunks.length; index += 1) {
		const partial = await callSummarizer(
			resolved,
			chunkPrompt(chunks[index]!, index + 1, chunks.length, fileOpsText, customInstructions),
			budgets.partialMaxTokens,
			signal,
		);
		if (partial.trim()) {
			partials.push(partial.trim());
		}
	}

	if (partials.length === 0) {
		throw new Error("Summarizer returned no partial summaries");
	}

	let current = partials;
	let currentPreviousSummary = previousSummary;
	while (true) {
		const sections = current.map((summary, index) => `### Partial summary ${index + 1}\n${summary}`);
		const groups = chunkSections(sections, budgets.finalInputBudget);
		if (groups.length === 1) {
			const merged = await callSummarizer(
				resolved,
				mergePrompt(groups[0]!, fileOpsText, currentPreviousSummary, customInstructions),
				budgets.finalMaxTokens,
				signal,
			);
			if (!merged.trim()) {
				throw new Error("Summarizer returned an empty final summary");
			}
			return merged.trim();
		}

		const reduced: string[] = [];
		for (const group of groups) {
			const mergedGroup = await callSummarizer(
				resolved,
				mergePrompt(group, fileOpsText, undefined, customInstructions),
				budgets.finalMaxTokens,
				signal,
			);
			if (mergedGroup.trim()) reduced.push(mergedGroup.trim());
		}
		if (reduced.length === 0) {
			throw new Error("Summarizer returned empty merge summaries");
		}
		current = reduced;
		currentPreviousSummary = previousSummary;
	}
}

export default function smartCompaction(pi: ExtensionAPI) {
	let queuedInputs: ReplayInput[] = [];
	let compactionInFlight = false;
	let overflowRecoveryAttempted = false;

	const flushQueuedInputs = () => {
		const queue = queuedInputs;
		queuedInputs = [];
		if (queue.length === 0) return;

		const [first, ...rest] = queue;
		pi.sendUserMessage(first.content);
		for (const item of rest) {
			pi.sendUserMessage(item.content, { deliverAs: "followUp" });
		}
	};

	pi.registerCommand("smart-compact-thresholds", {
		description: "Show smart compaction thresholds for the active model",
		handler: async (_args, ctx) => {
			await showThresholdOverlay(ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		overflowRecoveryAttempted = false;
		updateStatus(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		THRESHOLD_WIDGET.clear(ctx);
	});

	pi.on("context", async (event) => {
		const messages = event.messages.filter((message) => !isOverflowMessage(message));
		return { messages };
	});

	pi.on("agent_end", async (_event, ctx) => {
		updateStatus(ctx);
	});

	pi.on("model_select", async (_event, ctx) => {
		updateStatus(ctx);
	});

	pi.on("session_compact", async (_event, ctx) => {
		compactionInFlight = false;
		updateStatus(ctx);
	});

	pi.on("message_end", async (event, ctx) => {
		if (!isOverflowMessage(event.message)) {
			if ((event.message as { role?: unknown; stopReason?: unknown }).role === "assistant"
				&& (event.message as { stopReason?: unknown }).stopReason !== "error") {
				overflowRecoveryAttempted = false;
			}
			return;
		}

		if (overflowRecoveryAttempted || compactionInFlight) {
			ctx.ui.notify("Context overflow persisted after one smart-compaction retry.", "warning");
			return;
		}

		const content = getLastUserContent(ctx);
		if (!content) {
			ctx.ui.notify("Context overflow detected, but the last user prompt could not be replayed.", "warning");
			return;
		}

		overflowRecoveryAttempted = true;
		compactionInFlight = true;
		ctx.ui.notify("Context overflow detected; compacting and retrying…", "warning");
		ctx.compact({
			customInstructions:
				"Focus on preserving exact technical details, user intent, unresolved issues, and the next concrete action.",
			onComplete: () => {
				compactionInFlight = false;
				updateStatus(ctx);
				pi.sendUserMessage(content);
			},
			onError: (error) => {
				compactionInFlight = false;
				updateStatus(ctx);
				ctx.ui.notify(`Compaction failed after overflow: ${error.message}`, "error");
			},
		});
	});

	pi.on("input", async (event, ctx) => {
		updateStatus(ctx);
		if (!ctx.isIdle()) return { action: "continue" };
		if (!ctx.model?.contextWindow) return { action: "continue" };
		if (!shouldCompactBeforePrompt(ctx, event.text)) return { action: "continue" };

		if (queuedInputs.length >= COMPACTION_QUEUE_LIMIT) {
			ctx.ui.notify("Compaction queue is full; wait for the current compaction to finish.", "warning");
			return { action: "handled" };
		}

		queuedInputs.push({
			content: event.images && event.images.length > 0 ? [{ type: "text", text: event.text }, ...event.images] : event.text,
			fallbackText: event.images && event.images.length > 0 ? undefined : event.text,
		});
		if (compactionInFlight) {
			ctx.ui.notify("Queued prompt until compaction finishes.", "info");
			return { action: "handled" };
		}

		compactionInFlight = true;
		ctx.ui.notify("Compacting before continuing…", "info");
		ctx.compact({
			customInstructions:
				"Focus on preserving exact technical details, user intent, unresolved issues, and the next concrete action.",
			onComplete: () => {
				compactionInFlight = false;
				updateStatus(ctx);
				flushQueuedInputs();
			},
			onError: (error) => {
				compactionInFlight = false;
				const queue = queuedInputs;
				queuedInputs = [];
				restoreReplayInputs(ctx, queue);
				updateStatus(ctx);
				ctx.ui.notify(`Compaction failed: ${error.message}`, "error");
			},
		});
		return { action: "handled" };
	});

	pi.on("session_before_compact", async (event, ctx) => {
		const { preparation, customInstructions, signal } = event;
		const allMessages = [...preparation.messagesToSummarize, ...preparation.turnPrefixMessages];
		const conversationText = serializeConversation(convertToLlm(allMessages));
		if (!conversationText.trim()) {
			return;
		}

		const resolved = await resolveSummarizer(ctx);
		if (!resolved) {
			ctx.ui.notify("No summarizer model available for smart compaction; using default compaction.", "warning");
			return;
		}

		const details = getFileDetails((preparation as { fileOps?: FileOps }).fileOps);
		ctx.ui.notify(
			`Smart compaction: summarizing ${preparation.tokensBefore.toLocaleString()} tokens with ${resolved.model.provider}/${resolved.model.id}.`,
			"info",
		);

		try {
			const summary = await summarizeConversation(
				conversationText,
				preparation.previousSummary,
				details,
				customInstructions,
				resolved,
				signal,
			);

			return {
				compaction: {
					summary,
					firstKeptEntryId: preparation.firstKeptEntryId,
					tokensBefore: preparation.tokensBefore,
					details,
				},
			};
		} catch (error) {
			if (!signal.aborted) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Smart compaction failed: ${message}`, "warning");
			}
			return;
		}
	});
}
