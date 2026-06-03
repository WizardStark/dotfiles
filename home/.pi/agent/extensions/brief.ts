import { keyHint, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FORM_FIELDS = [
	{ key: "objective", heading: "Objective" },
	{ key: "target", heading: "Target" },
	{ key: "context", heading: "Context" },
	{ key: "constraints", heading: "Constraints" },
	{ key: "acceptanceCriteria", heading: "Acceptance criteria" },
	{ key: "output", heading: "Output" },
	{ key: "evidence", heading: "Evidence" },
] as const;

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
		"Leave a section blank to omit it from the final prompt sent to the agent.",
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

export default function formExtension(pi: ExtensionAPI) {
	pi.registerCommand("brief", {
		description: "Open a structured prompt brief and send it to the agent",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) {
				return;
			}

			const prefilledObjective = args.trim();
			ctx.ui.setWidget("brief-keymap", (_tui, theme) => ({
				invalidate() {},
				render(): string[] {
					return [
						theme.fg(
							"dim",
							[
								keyHint("tui.input.submit", "submit"),
								keyHint("app.message.followUp", "follow-up"),
								keyHint("tui.input.newLine", "newline"),
								keyHint("app.interrupt", "cancel"),
							].join(" · "),
						),
					];
				},
			}));
			let edited: string | undefined;
			try {
				edited = await ctx.ui.editor(
					"Structured prompt form",
					buildTemplate(prefilledObjective),
				);
			} finally {
				ctx.ui.setWidget("brief-keymap", undefined);
			}

			if (edited === undefined) {
				ctx.ui.notify("Form cancelled", "info");
				return;
			}

			const values = parseForm(edited);
			const prompt = buildPrompt(values);

			if (!prompt) {
				ctx.ui.notify("Form was empty, nothing was sent", "warning");
				return;
			}

			if (ctx.isIdle()) {
				pi.sendUserMessage(prompt);
				ctx.ui.notify("Structured prompt sent", "info");
				return;
			}

			pi.sendUserMessage(prompt, { deliverAs: "followUp" });
			ctx.ui.notify("Structured prompt queued as a follow-up", "info");
		},
	});
}
