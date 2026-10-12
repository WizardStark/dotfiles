import { sumUsages } from "./usage.ts";
import type { AssistantMessage, Message, Usage, ProviderHeaders } from "@earendil-works/pi-ai";
import {
	estimateUsageCost,
} from "./model-cost.ts";
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";

export type SubagentRunState = {
	messages: Message[];
	streamedText: string;
	turnEndMessage?: Message;
	agentEndMessage?: Message;
	agentEndMessages?: Message[];
	stderr: string;
	exitCode: number;
	stopReason?: string;
	errorMessage?: string;
	providerRequestStartedAt?: number;
	firstTextAt?: number;
	assistantCompletedAt?: number;
	finishedAt?: number;
};

export type TempFileSpec = {
	name: string;
	content: string;
};

export type SubagentMetrics = {
	usage?: Usage;
	provider?: string;
	model?: string;
	cost?: {
		amount?: number;
		estimated: boolean;
		knownRate: boolean;
		unknownModel?: string;
	};
	throughput?: {
		ttftMs?: number;
		generationDurationMs?: number;
		outputTokens: number;
		generationTokensPerSecond?: number;
	};
};

export type RunSubagentOptions = {
	cwd: string;
	prompt: string;
	modelArg: string;
	apiKey?: string;
	providerName?: string;
	authHeaders?: ProviderHeaders;
	authBaseUrl?: string;
	authEnv?: Record<string, string>;
	systemPrompt: string;
	extraArgs?: string[];
	tempFiles?: TempFileSpec[];
	env?: NodeJS.ProcessEnv;
	signal?: AbortSignal;
	onUpdate?: (text: string) => void;
	onEvent?: (event: any, state: SubagentRunState) => void;
};

function isPiCli(script: string): boolean {
	if (!/(?:^|[\\/])(?:cli|rpc-entry)\.js$/.test(script) || !existsSync(script)) return false;
	let directory = dirname(script);
	for (let depth = 0; depth < 6; depth++) {
		const metadata = join(directory, "package.json");
		if (existsSync(metadata)) {
			try { return JSON.parse(readFileSync(metadata, "utf8")).name === "@earendil-works/pi-coding-agent"; }
			catch { return false; }
		}
		const parent = dirname(directory);
		if (parent === directory) break;
		directory = parent;
	}
	return false;
}

export function getPiInvocation(args: string[]): { command: string; args: string[] } {
	// Explicit launcher for SDK hosts and offline fixture processes.
	if (process.env.PI_SUBAGENT_CLI) return { command: process.execPath, args: [process.env.PI_SUBAGENT_CLI, ...args] };
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && isPiCli(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}

	return { command: "pi", args };
}

function extractAssistantTextParts(message: AssistantMessage | undefined): string {
	if (!message) {
		return "";
	}
	return message.content
		.filter((part): part is { type: "text"; text: string } => part.type === "text")
		.map((part) => part.text)
		.join("\n")
		.trim();
}

export function extractFinalAssistantMessage(messages: Message[]): AssistantMessage | undefined {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message.role === "assistant") {
			return message as AssistantMessage;
		}
	}
	return undefined;
}

export function extractBestAssistantText(
	messages: Message[],
	streamedText = "",
): {
	text: string;
	stopReason?: string;
	errorMessage?: string;
	source: "final" | "history" | "stream" | "none";
	recovered: boolean;
} {
	const finalMessage = extractFinalAssistantMessage(messages);
	const finalText = extractAssistantTextParts(finalMessage);
	if (finalText) {
		return {
			text: finalText,
			stopReason: finalMessage?.stopReason,
			errorMessage: finalMessage?.errorMessage,
			source: "final",
			recovered: false,
		};
	}

	const streamed = streamedText.trim();
	if (streamed) {
		return {
			text: streamed,
			stopReason: finalMessage?.stopReason,
			errorMessage: finalMessage?.errorMessage,
			source: "stream",
			recovered: true,
		};
	}

	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message.role !== "assistant") {
			continue;
		}
		const assistantMessage = message as AssistantMessage;
		const text = extractAssistantTextParts(assistantMessage);
		if (text) {
			return {
				text,
				stopReason: finalMessage?.stopReason ?? assistantMessage.stopReason,
				errorMessage: finalMessage?.errorMessage ?? assistantMessage.errorMessage,
				source: "history",
				recovered: true,
			};
		}
	}

	return {
		text: "",
		stopReason: finalMessage?.stopReason,
		errorMessage: finalMessage?.errorMessage,
		source: "none",
		recovered: false,
	};
}

// message_end is authoritative. turn_end/agent_end repeat the last response;
// never collapse distinct requests just because their timestamp/content match.
export function subagentUsageMessages(run: SubagentRunState): Message[] {
	const records: Message[] = [];
	const seenResponses = new Set<string>();
	const seenTools = new Set<string>();
	for (const message of run.messages) {
		if (message.role === "assistant") {
			if (message.stopReason === "pending") continue;
			const id = message.responseId ? `${message.provider}/${message.model}/${message.responseId}` : undefined;
			if (id && seenResponses.has(id)) continue;
			if (id) seenResponses.add(id);
			records.push(message);
		} else if (message.role === "toolResult" && message.usage) {
			if (seenTools.has(message.toolCallId)) continue;
			seenTools.add(message.toolCallId);
			records.push(message);
		}
	}
	// Reconcile full fallback envelopes by multiplicity. Two identical real
	// requests remain two requests; repeating their agent_end snapshot adds none.
	const identity = (message: Message) => message.role === "assistant"
		? message.responseId ? `response:${message.provider}/${message.model}/${message.responseId}` : JSON.stringify(message)
		: message.role === "toolResult" ? `tool:${message.toolCallId}` : undefined;
	for (const envelope of [
		run.agentEndMessages ?? [],
		run.turnEndMessage ? [run.turnEndMessage] : [],
		run.agentEndMessage ? [run.agentEndMessage] : [],
	]) {
		const existing = new Map<string, number>();
		for (const record of records) {
			const key = identity(record);
			if (key) existing.set(key, (existing.get(key) ?? 0) + 1);
		}
		const occurrences = new Map<string, number>();
		for (const message of envelope) {
			if (message.role !== "assistant" && message.role !== "toolResult") continue;
			if (message.role === "assistant" && message.stopReason === "pending") continue;
			if (message.role === "toolResult" && !message.usage) continue;
			const key = identity(message)!;
			const count = (occurrences.get(key) ?? 0) + 1;
			occurrences.set(key, count);
			// Response/tool IDs identify a single result, even within one envelope.
			if ((message.role === "toolResult" || message.responseId) && count > 1) continue;
			if (count > (existing.get(key) ?? 0)) records.push(message);
		}
	}
	return records;
}

export function buildSubagentMetrics(run: SubagentRunState): SubagentMetrics | undefined {
	const records = subagentUsageMessages(run);
	if (!records.length) return undefined;
	const assistants = records.filter((message): message is AssistantMessage => message.role === "assistant");
	const final = assistants.at(-1);
	const usage = sumUsages(records.map((message) => "usage" in message ? message.usage : undefined));
	const estimates = assistants.filter((message) => message.usage).map(estimateUsageCost);
	const nestedCosts = records.filter((message) => message.role === "toolResult").map((message) => message.usage?.cost.total ?? 0);
	const ttftMs = run.providerRequestStartedAt !== undefined && run.firstTextAt !== undefined
		? Math.max(0, run.firstTextAt - run.providerRequestStartedAt) : undefined;
	const generationDurationMs = run.firstTextAt !== undefined && run.assistantCompletedAt !== undefined
		? Math.max(1, run.assistantCompletedAt - run.firstTextAt) : undefined;
	const outputTokens = usage?.output ?? 0;
	return {
		provider: final?.provider, model: final?.model, usage,
		cost: usage ? {
			amount: estimates.reduce((total, cost) => total + cost.amount, 0) + nestedCosts.reduce((a, b) => a + b, 0),
			estimated: estimates.some((cost) => cost.estimated),
			knownRate: estimates.every((cost) => cost.knownRate),
			unknownModel: estimates.find((cost) => !cost.knownRate)?.unknownModel,
		} : undefined,
		throughput: {
			ttftMs, generationDurationMs, outputTokens,
			generationTokensPerSecond: outputTokens > 0 && generationDurationMs !== undefined
				? outputTokens / (generationDurationMs / 1000) : undefined,
		},
	};
}

export function extractFinalAssistantText(
	messages: Message[],
	streamedText = "",
	allowStreamFallback = false,
): { text: string; stopReason?: string; errorMessage?: string } {
	const message = extractFinalAssistantMessage(messages);
	if (!message) {
		return { text: allowStreamFallback ? streamedText.trim() : "" };
	}

	const text = extractAssistantTextParts(message);

	return {
		text: text || (allowStreamFallback ? streamedText.trim() : ""),
		stopReason: message.stopReason,
		errorMessage: message.errorMessage,
	};
}

export async function runSubagentProcess(options: RunSubagentOptions): Promise<SubagentRunState> {
	options.signal?.throwIfAborted();
	const tempDir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
	const systemPromptPath = join(tempDir, "system-prompt.md");

	try {
		await writeFile(systemPromptPath, options.systemPrompt, { encoding: "utf8", mode: 0o600 });
		const tempFiles = [...(options.tempFiles ?? [])];
		const authHeaders = options.authHeaders
			? Object.fromEntries(
					Object.entries(options.authHeaders).filter(
						([key, value]) => key.trim().length > 0 && (typeof value === "string" || value === null),
					),
			  )
			: undefined;
		if (options.providerName && (options.authBaseUrl || (authHeaders && Object.keys(authHeaders).length > 0))) {
			tempFiles.push({
				name: "auth-provider.ts",
				content: `export default function (pi) {\n\tpi.registerProvider(${JSON.stringify(options.providerName)}, {\n\t\theaders: ${JSON.stringify(authHeaders)},\n\t\tbaseUrl: ${JSON.stringify(options.authBaseUrl)},\n\t});\n}\n`,
			});
		}
		for (const tempFile of tempFiles) {
			const filePath = join(tempDir, tempFile.name);
			await writeFile(filePath, tempFile.content, { encoding: "utf8", mode: 0o600 });
		}
		const extraArgs = [
			...(options.providerName && (options.authBaseUrl || (authHeaders && Object.keys(authHeaders).length > 0))
				? ["-e", "@temp/auth-provider.ts"]
				: []),
			...(options.extraArgs ?? []),
		].map((value) => value.replace(/^@temp\//, `${tempDir}/`));
		const args = [
			"--mode",
			"json",
			"-p",
			"--no-session",
			"--model",
			options.modelArg,
			...(options.apiKey ? ["--api-key", options.apiKey] : []),
			...extraArgs,
			"--append-system-prompt",
			systemPromptPath,
			options.prompt,
		];
		options.signal?.throwIfAborted();
		const invocation = getPiInvocation(args);

		return await new Promise<SubagentRunState>((resolve) => {
			const proc = spawn(invocation.command, invocation.args, {
				cwd: options.cwd,
				stdio: ["ignore", "pipe", "pipe"],
				env: {
					...process.env,
					...(options.authEnv ?? {}),
					...(options.env ?? {}),
				},
			});

			const state: SubagentRunState = {
				messages: [],
				streamedText: "",
				stderr: "",
				exitCode: 1,
			};
			let buffer = "";
			let settled = false;
			let killTimer: ReturnType<typeof setTimeout> | undefined;
			let callbackError: string | undefined;
			const streamedTextParts: string[] = [];
			const terminate = () => {
				if (settled) return;
				proc.kill("SIGTERM");
				killTimer ??= setTimeout(() => { try { proc.kill("SIGKILL"); } catch { /* already exited */ } }, 5000);
			};

			const finish = (exitCode: number) => {
				if (settled) return;
				settled = true;
				if (killTimer) clearTimeout(killTimer);
				options.signal?.removeEventListener("abort", terminate);
				state.exitCode = callbackError ? 1 : exitCode;
				state.finishedAt = Date.now();
				state.streamedText = streamedTextParts.map((part) => part ?? "").join("").trim();
				const final = extractFinalAssistantText(
					[
						...state.messages,
						...(state.turnEndMessage ? [state.turnEndMessage] : []),
						...(state.agentEndMessage ? [state.agentEndMessage] : []),
					],
					state.streamedText,
				);
				state.stopReason = callbackError ? "error" : options.signal?.aborted ? "aborted" : final.stopReason;
				state.errorMessage = callbackError ?? final.errorMessage;
				resolve(state);
			};

			const emitUpdate = () => {
				if (!options.onUpdate) return;
				const preview = streamedTextParts.map((part) => part ?? "").join("").trim();
				if (preview) {
					options.onUpdate(preview);
				}
			};

			const processLine = (line: string) => {
				if (settled || !line.trim()) return;
				let event;
				try { event = JSON.parse(line); } catch { return; }
				try {
					if (event.type === "message_start" && event.message?.role === "assistant") {
						streamedTextParts.length = 0;
						state.providerRequestStartedAt ??= Date.now();
					}
					if (event.type === "message_update") {
						const assistantEvent = event.assistantMessageEvent;
						if (assistantEvent?.type === "text_start") {
							streamedTextParts[assistantEvent.contentIndex] ??= "";
						}
						if (assistantEvent?.type === "text_delta") {
							if (assistantEvent.delta) {
								state.firstTextAt ??= Date.now();
							}
							const index = assistantEvent.contentIndex;
							streamedTextParts[index] = `${streamedTextParts[index] ?? ""}${assistantEvent.delta ?? ""}`;
							emitUpdate();
						}
						if (assistantEvent?.type === "text_end") {
							streamedTextParts[assistantEvent.contentIndex] = assistantEvent.content ?? "";
							emitUpdate();
						}
					}
					if (event.type === "message_end" && event.message) {
						if (event.message.role === "assistant") {
							state.assistantCompletedAt = Date.now();
						}
						state.messages.push(event.message as Message);
					}
					if (event.type === "turn_end" && event.message) {
						state.turnEndMessage = event.message as Message;
					}
					if (event.type === "agent_end" && Array.isArray(event.messages)) {
						state.agentEndMessages = event.messages as Message[];
						for (let i = event.messages.length - 1; i >= 0; i--) {
							if (event.messages[i]?.role === "assistant") {
								state.agentEndMessage = event.messages[i] as Message;
								break;
							}
						}
					}
					if (event.type === "error" && typeof event.error === "string") {
						state.stderr += `${event.error}\n`;
					}
					options.onEvent?.(event, state);
				} catch (error) {
					callbackError = `Subagent event handler failed: ${error instanceof Error ? error.message : String(error)}`;
					terminate();
				}
			};

			proc.stdout.on("data", (chunk) => {
				buffer += chunk.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() ?? "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (chunk) => {
				state.stderr += chunk.toString();
			});

			proc.on("close", (code) => { code ??= 1; if (buffer.trim()) processLine(buffer); finish(code); });
			proc.on("error", (error) => {
				state.stderr += `${error instanceof Error ? error.message : String(error)}\n`;
				finish(1);
			});

			if (options.signal?.aborted) terminate();
			else options.signal?.addEventListener("abort", terminate, { once: true });
		});
	} finally {
		await rm(tempDir, { recursive: true, force: true });
	}
}
