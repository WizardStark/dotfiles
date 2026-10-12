import { keyHint, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createSessionWork, isCancelledWork } from "./lib/session-work.ts";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { ManagedWidget } from "./lib/ui-widgets.ts";

const FORM_FIELDS = [
	{ key: "objective", heading: "Objective" },
	{ key: "target", heading: "Target" },
	{ key: "context", heading: "Context" },
	{ key: "constraints", heading: "Constraints" },
	{ key: "acceptanceCriteria", heading: "Acceptance criteria" },
	{ key: "output", heading: "Output" },
	{ key: "evidence", heading: "Evidence" },
] as const;

const KEYMAP_WIDGET = new ManagedWidget("brief-keymap");

type FieldKey = (typeof FORM_FIELDS)[number]["key"];
type FormValues = Record<FieldKey, string>;

function emptyValues(): FormValues {
	return {
		objective: "",
		target: "",
		context: "",
		constraints: "",
		acceptanceCriteria: "",
		output: "",
		evidence: "",
	};
}

function normalizeSectionText(text: string): string {
	return text.replace(/\r\n/g, "\n").replace(/^\n+|\n+$/g, "");
}

function buildTemplate(prefilledObjective: string): string {
	const header = [
		"Fill in any sections you want.",
		"Leave a section blank to omit it from the final prompt placed in the composer.",
		"When you're done, submit this editor.",
	].join("\n");

	const sections = FORM_FIELDS.map((field) => {
		const initialValue = field.key === "objective" ? prefilledObjective.trim() : "";
		return `${field.heading}:\n${initialValue}`;
	}).join("\n\n");

	return `${header}\n\n${sections}`;
}

function escapeRegExp(value: string): string {
	return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function parseForm(content: string): FormValues {
	const values = emptyValues();
	const fieldMatchers = FORM_FIELDS.map((field) => ({
		key: field.key,
		pattern: new RegExp(`^${escapeRegExp(field.heading)}(?::\\s*(.*))?$`, "i"),
	}));

	let currentKey: FieldKey | null = null;
	const chunks = new Map<FieldKey, string[]>();

	for (const rawLine of content.replace(/\r\n/g, "\n").split("\n")) {
		const match = fieldMatchers
			.map((field) => ({ key: field.key, match: rawLine.match(field.pattern) }))
			.find((result) => result.match);

		if (match?.match) {
			currentKey = match.key;
			if (!chunks.has(match.key)) chunks.set(match.key, []);
			const inlineValue = match.match[1];
			if (inlineValue) {
				chunks.get(match.key)?.push(inlineValue);
			}
			continue;
		}

		if (!currentKey) continue;
		chunks.get(currentKey)?.push(rawLine);
	}

	for (const field of FORM_FIELDS) {
		values[field.key] = normalizeSectionText((chunks.get(field.key) ?? []).join("\n"));
	}

	return values;
}

function formatSectionBody(value: string): string {
	const lines = normalizeSectionText(value).split("\n");
	return lines
		.map((line, index) => {
			const cleanLine = line.replace(/\s+$/g, "");
			return index === 0 ? `  - ${cleanLine}` : `    ${cleanLine}`;
		})
		.join("\n");
}

function buildPrompt(values: FormValues): string {
	const sections = FORM_FIELDS.filter((field) => values[field.key].trim()).map(
		(field) => `- ${field.heading}\n${formatSectionBody(values[field.key])}`,
	);
	return sections.join("\n\n");
}

function setBriefKeymapWidget(ctx: ExtensionContext) {
	if (ctx.mode === "tui") {
		KEYMAP_WIDGET.set(ctx, (_tui, _theme) => ({
			invalidate() {},
			render(width: number): string[] {
				return [
					truncateToWidth(ctx.ui.theme.fg(
						"dim",
						[
							keyHint("tui.input.submit", "submit"),
							keyHint("app.message.followUp", "follow-up"),
							keyHint("tui.input.newLine", "newline"),
							keyHint("app.interrupt", "cancel"),
						].join(" · "),
					), width),
				];
			},
		}));
		return;
	}

	KEYMAP_WIDGET.set(ctx, ["Structured prompt form controls", "submit · follow-up · newline · cancel"]);
}

export default function formExtension(pi: ExtensionAPI) {
	const sessionWork = createSessionWork(pi);
	let activeBrief: AbortController | undefined;
	const clear = (_event: unknown, ctx: ExtensionContext) => {
		activeBrief?.abort();
		activeBrief = undefined;
		KEYMAP_WIDGET.clear(ctx);
	};
	pi.on("session_tree", clear);
	pi.on("session_shutdown", clear);
	const openBrief = async (
		args: string,
		ctx: ExtensionContext,
	) => {
		if (!ctx.hasUI) {
			return;
		}

		activeBrief?.abort();
		const controller = new AbortController();
		activeBrief = controller;
		const signal = ctx.signal ? AbortSignal.any([ctx.signal, controller.signal]) : controller.signal;
		const work = sessionWork.start(signal);
		setBriefKeymapWidget(ctx);
		try {
			// editor() has no public signal option (unlike select/input/confirm).
			// Stop awaiting on invalidation; a late dialog response cannot update the composer.
			const edited = await work.wait(ctx.ui.editor("Structured prompt form", buildTemplate(args.trim())));
			work.assertCurrent();
			work.signal.throwIfAborted();
			if (edited === undefined) {
				ctx.ui.notify("Form cancelled", "info");
				return;
			}
			const prompt = buildPrompt(parseForm(edited));
			if (!prompt) {
				ctx.ui.notify("Form was empty, nothing was added", "warning");
				return;
			}
			ctx.ui.setEditorText(prompt);
			ctx.ui.notify(ctx.isIdle()
				? "Structured prompt ready in the composer — press Enter to send and keep it in ↑ history"
				: "Structured prompt ready in the composer — send or queue it from there for normal ↑ history", "info");
		} catch (error) {
			if (work.isCurrent() && !isCancelledWork(error)) throw error;
		} finally {
			if (activeBrief === controller) {
				activeBrief = undefined;
				if (work.isCurrent()) KEYMAP_WIDGET.clear(ctx);
			}
			work.dispose();
		}
	};

	pi.registerCommand("brief", {
		description: "Open a structured prompt brief and place it in the composer",
		handler: openBrief,
	});

	pi.registerShortcut("alt+q", {
		description: "Open structured prompt brief",
		handler: async (ctx) => {
			await openBrief("", ctx);
		},
	});
}
