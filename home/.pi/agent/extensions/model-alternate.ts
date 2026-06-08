import type { Api, Model } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface ModelRef {
	provider: string;
	id: string;
}

interface ModelAltState {
	previous?: ModelRef;
}

const STATE_ENTRY = "model-alt-state";
const SHORTCUT = "alt+l";

function toRef(model?: Model<Api>): ModelRef | undefined {
	if (!model) return undefined;
	return {
		provider: model.provider,
		id: model.id,
	};
}

function sameModel(a?: ModelRef, b?: ModelRef): boolean {
	return !!a && !!b && a.provider === b.provider && a.id === b.id;
}

function formatModel(ref?: ModelRef): string {
	return ref ? `${ref.provider}/${ref.id}` : "none";
}

function findModel(ctx: ExtensionContext, ref?: ModelRef): Model<Api> | undefined {
	if (!ref) return undefined;
	return ctx.modelRegistry.find(ref.provider, ref.id);
}

function readSavedState(ctx: ExtensionContext): ModelAltState | undefined {
	const entry = [...ctx.sessionManager.getEntries()]
		.reverse()
		.find((item) => item.type === "custom" && item.customType === STATE_ENTRY) as
		| { data?: ModelAltState }
		| undefined;

	const previous = entry?.data?.previous;
	if (!previous?.provider || !previous?.id) return undefined;
	return { previous };
}

export default function modelAlternateExtension(pi: ExtensionAPI) {
	let previousModel: ModelRef | undefined;

	function persistPreviousModel() {
		pi.appendEntry(STATE_ENTRY, { previous: previousModel });
	}

	function updateStatus(ctx: ExtensionContext) {
		if (!previousModel) {
			ctx.ui.setStatus("model-alt", undefined);
			return;
		}

		ctx.ui.setStatus("model-alt", ctx.ui.theme.fg("muted", `prev:${previousModel.id}`));
	}

	async function swapToPreviousModel(ctx: ExtensionContext) {
		if (!previousModel) {
			ctx.ui.notify("No previous model is stored yet", "warning");
			return;
		}

		const model = findModel(ctx, previousModel);
		if (!model) {
			ctx.ui.notify(`Previous model not found: ${formatModel(previousModel)}`, "error");
			return;
		}

		const success = await pi.setModel(model);
		if (!success) {
			ctx.ui.notify(`No API key available for ${formatModel(previousModel)}`, "error");
		}
	}

	pi.registerCommand("model-alt", {
		description: "Swap to the previously selected model",
		handler: async (_args, ctx) => {
			await swapToPreviousModel(ctx);
		},
	});

	pi.registerShortcut(SHORTCUT, {
		description: "Swap to the previously selected model",
		handler: async (ctx) => {
			await swapToPreviousModel(ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		previousModel = readSavedState(ctx)?.previous;
		updateStatus(ctx);
	});

	pi.on("model_select", async (event, ctx) => {
		const current = toRef(event.model);
		const previous = toRef(event.previousModel);

		if (previous && !sameModel(previous, current)) {
			previousModel = previous;
			persistPreviousModel();
		}

		updateStatus(ctx);
	});
}
