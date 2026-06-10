import { estimateTokens } from "@earendil-works/pi-coding-agent";

export function estimateTextTokens(text: string): number {
	return Math.max(1, estimateTokens(text));
}

export function splitOversizedText(text: string, maxTokens: number): string[] {
	const trimmed = text.trim();
	if (!trimmed) return [];
	if (estimateTextTokens(trimmed) <= maxTokens) return [trimmed];

	const parts: string[] = [];
	let remaining = trimmed;

	while (remaining) {
		const estimated = estimateTextTokens(remaining);
		if (estimated <= maxTokens) {
			parts.push(remaining);
			break;
		}

		const ratio = maxTokens / estimated;
		let targetChars = Math.max(500, Math.floor(remaining.length * ratio));
		targetChars = Math.min(targetChars, remaining.length);

		let cut = -1;
		for (const separator of ["\n\n", "\n", ". ", "; ", ", ", " "]) {
			cut = remaining.lastIndexOf(separator, targetChars);
			if (cut >= Math.floor(targetChars * 0.5)) {
				cut += separator.length;
				break;
			}
			cut = -1;
		}
		if (cut <= 0) cut = targetChars;

		const head = remaining.slice(0, cut).trim();
		if (!head) {
			parts.push(remaining.slice(0, targetChars));
			remaining = remaining.slice(targetChars).trimStart();
			continue;
		}

		parts.push(head);
		remaining = remaining.slice(cut).trimStart();
	}

	return parts;
}

export function chunkText(text: string, maxTokens: number): string[] {
	const chunks: string[] = [];
	let current = "";
	let currentTokens = 0;

	for (const rawLine of text.replace(/\r\n/g, "\n").split("\n")) {
		const line = rawLine.length > 0 ? rawLine : " ";
		const segments = splitOversizedText(line, maxTokens);
		if (segments.length === 0) {
			if (current) {
				current += "\n";
			}
			continue;
		}

		for (const segment of segments) {
			const segmentText = current ? `\n${segment}` : segment;
			const segmentTokens = estimateTextTokens(segmentText);
			if (current && currentTokens + segmentTokens > maxTokens) {
				chunks.push(current.trim());
				current = segment;
				currentTokens = estimateTextTokens(segment);
				continue;
			}
			current += segmentText;
			currentTokens += segmentTokens;
		}
	}

	if (current.trim()) chunks.push(current.trim());
	return chunks;
}

export function chunkSections(sections: string[], maxTokens: number): string[] {
	const chunks: string[] = [];
	let current = "";
	let currentTokens = 0;

	for (const section of sections) {
		const sectionText = current ? `\n\n${section}` : section;
		const sectionTokens = estimateTextTokens(sectionText);

		if (current && currentTokens + sectionTokens > maxTokens) {
			chunks.push(current.trim());
			current = section;
			currentTokens = estimateTextTokens(section);
			continue;
		}

		current += sectionText;
		currentTokens += sectionTokens;
	}

	if (current.trim()) chunks.push(current.trim());
	return chunks;
}
