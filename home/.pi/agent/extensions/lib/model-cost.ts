import type { AssistantMessage } from "@earendil-works/pi-ai";

export const TOKENS_PER_MILLION = 1_000_000;

export type ModelRates = {
	input: number;
	cachedInput: number;
	output: number;
	cacheWrite?: number;
};

export const MODEL_RATES: Record<string, ModelRates> = {
	"gpt-4.1": { input: 2.0, cachedInput: 0.5, output: 8.0 },
	"gpt-5-mini": { input: 0.25, cachedInput: 0.025, output: 2.0 },
	"gpt-5.2": { input: 1.75, cachedInput: 0.175, output: 14.0 },
	"gpt-5.2-codex": { input: 1.75, cachedInput: 0.175, output: 14.0 },
	"gpt-5.3-codex": { input: 1.75, cachedInput: 0.175, output: 14.0 },
	"gpt-5.4": { input: 2.5, cachedInput: 0.25, output: 15.0 },
	"gpt-5.4-mini": { input: 0.75, cachedInput: 0.075, output: 4.5 },
	"gpt-5.4-nano": { input: 0.2, cachedInput: 0.02, output: 1.25 },
	"gpt-5.5": { input: 5.0, cachedInput: 0.5, output: 30.0 },
	"claude-haiku-4.5": { input: 1.0, cachedInput: 0.1, cacheWrite: 1.25, output: 5.0 },
	"claude-sonnet-4": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
	"claude-sonnet-4.5": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
	"claude-sonnet-4.6": { input: 3.0, cachedInput: 0.3, cacheWrite: 3.75, output: 15.0 },
	"claude-opus-4.5": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
	"claude-opus-4.6": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
	"claude-opus-4.7": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
	"claude-opus-4.8": { input: 5.0, cachedInput: 0.5, cacheWrite: 6.25, output: 25.0 },
	"mai-code-1-flash": { input: 0.75, cachedInput: 0.075, output: 4.5 },
	"gemini-3-flash-preview": { input: 0.1, cachedInput: 0.025, output: 0.4 },
	"gemini-3.5-flash": { input: 0.15, cachedInput: 0.0375, output: 0.6 },
};

export function normalizeModelId(model: string | undefined): string {
	const raw = (model ?? "").trim().toLowerCase();
	const withoutBuildSuffix = raw.split("@")[0] || raw;
	const withoutThinkingSuffix = withoutBuildSuffix.replace(/:(off|minimal|low|medium|high|xhigh)$/, "");
	const withoutPathPrefix = withoutThinkingSuffix.split("/").pop() || withoutThinkingSuffix;
	const withoutProviderPrefix = withoutPathPrefix.includes(":")
		? withoutPathPrefix.split(":").slice(1).join(":") || withoutPathPrefix
		: withoutPathPrefix;
	return withoutProviderPrefix.replace(/[_\s]+/g, "-").replace(/-+/g, "-");
}

export function estimateUsageCost(message: AssistantMessage): {
	amount: number;
	estimated: boolean;
	knownRate: boolean;
	unknownModel?: string;
} {
	const usage = message.usage;
	if (!usage) {
		return { amount: 0, estimated: false, knownRate: true };
	}

	const actualCost = usage.cost?.total;
	const provider = message.provider ?? "";
	if (
		typeof actualCost === "number" &&
		(actualCost > 0 || (actualCost === 0 && provider !== "" && provider !== "github-copilot"))
	) {
		return { amount: actualCost, estimated: false, knownRate: true };
	}

	const normalizedModel = normalizeModelId(message.model);
	const rates = MODEL_RATES[normalizedModel];
	if (!rates) {
		return {
			amount: 0,
			estimated: true,
			knownRate: false,
			unknownModel: normalizedModel || "unknown-model",
		};
	}

	const input = usage.input ?? 0;
	const cacheRead = usage.cacheRead ?? 0;
	const cacheWrite = usage.cacheWrite ?? 0;
	const output = usage.output ?? 0;
	const amount =
		(input * rates.input +
			cacheRead * rates.cachedInput +
			output * rates.output +
			cacheWrite * (rates.cacheWrite ?? 0)) /
		TOKENS_PER_MILLION;

	return { amount, estimated: true, knownRate: true };
}

export function formatUsd(amount: number): string {
	if (amount >= 10) return `$${amount.toFixed(2)}`;
	if (amount >= 1) return `$${amount.toFixed(3)}`;
	return `$${amount.toFixed(4)}`;
}
