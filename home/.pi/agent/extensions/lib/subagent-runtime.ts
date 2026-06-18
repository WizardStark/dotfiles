import type { AssistantMessage, Message } from "@earendil-works/pi-ai";
import {
	estimateUsageCost,
} from "./model-cost";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";

export type SubagentRunState = {
	messages: Message[];
	streamedText: string;
	lastAssistantPartial?: Message;
	turnEndMessage?: Message;
	agentEndMessage?: Message;
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
	provider?: string;
	model?: string;
	cost?: {
		amount?: number;
		estimated: boolean;
		knownRate: boolean;
		unknownModel?: string;
	};
	throughput: {
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
	authHeaders?: Record<string, string>;
	systemPrompt: string;
	extraArgs?: string[];
	tempFiles?: TempFileSpec[];
	env?: NodeJS.ProcessEnv;
	signal?: AbortSignal;
	onUpdate?: (text: string) => void;
	onEvent?: (event: any, state: SubagentRunState) => void;
};

export function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && existsSync(currentScript)) {
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

export function buildSubagentMetrics(run: SubagentRunState): SubagentMetrics | undefined {
	const partialAssistant =
		run.lastAssistantPartial?.role === "assistant" ? (run.lastAssistantPartial as AssistantMessage) : undefined;
	const finalizedAssistant = extractFinalAssistantMessage([
		...run.messages,
		...(run.turnEndMessage ? [run.turnEndMessage] : []),
		...(run.agentEndMessage ? [run.agentEndMessage] : []),
	]);
	const finalAssistant = finalizedAssistant ?? partialAssistant;
	if (!finalAssistant) {
		return undefined;
	}

	const assistantForUsage = {
		...finalAssistant,
		provider: finalAssistant.provider ?? partialAssistant?.provider,
		model: finalAssistant.model ?? partialAssistant?.model,
		usage: finalAssistant.usage ?? partialAssistant?.usage,
	} as AssistantMessage;

	const ttftMs =
		run.providerRequestStartedAt !== undefined && run.firstTextAt !== undefined
			? Math.max(0, run.firstTextAt - run.providerRequestStartedAt)
			: undefined;
	const generationDurationMs =
		run.firstTextAt !== undefined && run.assistantCompletedAt !== undefined
			? Math.max(1, run.assistantCompletedAt - run.firstTextAt)
			: undefined;
	const outputTokens = Math.max(0, assistantForUsage.usage?.output ?? 0);
	const generationTokensPerSecond =
		outputTokens > 0 && generationDurationMs !== undefined
			? outputTokens / (generationDurationMs / 1_000)
			: undefined;

	const cost = estimateUsageCost(assistantForUsage);
	const hasUsage = assistantForUsage.usage !== undefined;

	return {
		provider: assistantForUsage.provider,
		model: assistantForUsage.model,
		cost: hasUsage ? cost : undefined,
		throughput: {
			ttftMs,
			generationDurationMs,
			outputTokens,
			generationTokensPerSecond,
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
	const tempDir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
	const systemPromptPath = join(tempDir, "system-prompt.md");

	try {
		await writeFile(systemPromptPath, options.systemPrompt, "utf8");
		const tempFiles = [...(options.tempFiles ?? [])];
		const authHeaders = options.authHeaders
			? Object.fromEntries(
					Object.entries(options.authHeaders).filter(
						([key, value]) => key.trim().length > 0 && typeof value === "string",
					),
			  )
			: undefined;
		if (options.providerName && authHeaders && Object.keys(authHeaders).length > 0) {
			tempFiles.push({
				name: "auth-provider.ts",
				content: `export default function (pi) {\n\tpi.registerProvider(${JSON.stringify(options.providerName)}, {\n\t\theaders: ${JSON.stringify(authHeaders)},\n\t});\n}\n`,
			});
		}
		for (const tempFile of tempFiles) {
			const filePath = join(tempDir, tempFile.name);
			await writeFile(filePath, tempFile.content, "utf8");
		}
		const extraArgs = [
			...(options.providerName && authHeaders && Object.keys(authHeaders).length > 0
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
		const invocation = getPiInvocation(args);

		return await new Promise<SubagentRunState>((resolve) => {
			const proc = spawn(invocation.command, invocation.args, {
				cwd: options.cwd,
				stdio: ["ignore", "pipe", "pipe"],
				env: {
					...process.env,
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
			const streamedTextParts: string[] = [];

			const finish = (exitCode: number) => {
				if (settled) return;
				settled = true;
				state.exitCode = exitCode;
				state.finishedAt = Date.now();
				state.streamedText = streamedTextParts.map((part) => part ?? "").join("").trim();
				const final = extractFinalAssistantText(
					[
						...(state.lastAssistantPartial ? [state.lastAssistantPartial] : []),
						...state.messages,
						...(state.turnEndMessage ? [state.turnEndMessage] : []),
						...(state.agentEndMessage ? [state.agentEndMessage] : []),
					],
					state.streamedText,
				);
				state.stopReason = final.stopReason;
				state.errorMessage = final.errorMessage;
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
				if (!line.trim()) return;
				try {
					const event = JSON.parse(line);
					if (event.type === "message_update") {
						const assistantEvent = event.assistantMessageEvent;
						if (assistantEvent?.partial) {
							state.lastAssistantPartial = assistantEvent.partial as Message;
						}
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
				} catch {
					// ignore malformed lines
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

			if (options.signal) {
				const onAbort = () => {
					proc.kill("SIGTERM");
					setTimeout(() => {
						try {
							proc.kill("SIGKILL");
						} catch {
							// ignore
						}
					}, 5000);
				};
				if (options.signal.aborted) onAbort();
				else options.signal.addEventListener("abort", onAbort, { once: true });
			}
		});
	} finally {
		await rm(tempDir, { recursive: true, force: true });
	}
}
