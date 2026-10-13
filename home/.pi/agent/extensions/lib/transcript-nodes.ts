import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences } from "@earendil-works/pi-tui";

export type TranscriptNode = { id: string; title: string; body: string; error?: boolean };
type RecordedResult = { content: unknown; details?: unknown; isError: boolean };
const MAX_BODY = 100_000;

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object";
}

function clean(text: string): string {
  return stripTerminalSequences(text).replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
}

function body(text: string): string {
  const safe = clean(text);
  return safe.length > MAX_BODY ? `${safe.slice(0, MAX_BODY)}\n[preview truncated at ${MAX_BODY} characters]` : safe;
}

function contentText(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.map((part: unknown) => {
    if (!record(part)) return "";
    if (part.type === "text" && typeof part.text === "string") return part.text;
    if (part.type === "image") return `[image${typeof part.mimeType === "string" ? `: ${part.mimeType}` : ""}]`;
    return "";
  }).filter(Boolean).join("\n");
}

function messageNode(id: string, role: string, text: string): TranscriptNode {
  const safe = body(text);
  const preview = safe.split("\n").find((line) => line.trim()) ?? "(empty)";
  return { id, title: `${clean(role).replace(/\s+/g, " ")}: ${preview.replace(/\s+/g, " ")}`, body: safe };
}

/** Snapshot only the active branch; never mutate entries or include hidden state/system prompts. */
export function transcriptNodes(entries: SessionEntry[]): TranscriptNode[] {
  const results = new Map<string, RecordedResult>();
  const paired = new Set<string>();
  for (const entry of entries) {
    if (entry.type === "message" && entry.message.role === "toolResult") {
      results.set(entry.message.toolCallId, entry.message);
    }
  }
  const nodes: TranscriptNode[] = [];
  const toolNode = (id: string, name: string, args: unknown, result?: RecordedResult): TranscriptNode => {
    const argsText = typeof args === "string" ? args : JSON.stringify(args, null, 2);
    const sections = argsText ? [`Arguments:\n${argsText}`] : [];
    if (result) {
      sections.push(`Output:\n${contentText(result.content) || "(no text output)"}`);
      if (record(result.details) && typeof result.details.diff === "string") sections.push(`Diff:\n${result.details.diff}`);
    }
    return { id, title: `${clean(name).replace(/\s+/g, " ")} ${result ? result.isError ? "⚠ failed" : "done" : "(no recorded result)"}`,
      body: body(sections.join("\n\n")), error: result?.isError === true };
  };
  // Mark all paired results before iterating, including unusual result-before-call histories.
  for (const entry of entries) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    for (const part of entry.message.content) if (part.type === "toolCall") paired.add(part.id);
  }
  for (const entry of entries) {
    if (entry.type === "compaction" || entry.type === "branch_summary") {
      nodes.push(messageNode(entry.id, entry.type === "compaction" ? "compaction" : "branch summary", entry.summary));
    } else if (entry.type === "custom_message") {
      if (entry.display) nodes.push(messageNode(entry.id, entry.customType, contentText(entry.content)));
    } else if (entry.type === "message") {
      const message = entry.message;
      if (message.role === "assistant") {
        message.content.forEach((part, index) => {
          const id = `${entry.id}/${index}`;
          if (part.type === "text" && part.text.trim()) nodes.push(messageNode(id, "assistant", part.text));
          else if (part.type === "thinking" && part.thinking.trim()) nodes.push(messageNode(id, "thinking", part.thinking));
          else if (part.type === "toolCall") nodes.push(toolNode(id, part.name, part.arguments, results.get(part.id)));
        });
        if (message.errorMessage) nodes.push({ ...messageNode(`${entry.id}/error`, "assistant error", message.errorMessage), error: true });
      } else if (message.role === "user") {
        nodes.push(messageNode(entry.id, "user", contentText(message.content)));
      } else if (message.role === "toolResult") {
        if (!paired.has(message.toolCallId)) nodes.push(toolNode(entry.id, message.toolName, undefined, results.get(message.toolCallId)));
      } else if (message.role === "bashExecution") {
        nodes.push({ ...messageNode(entry.id, "!bash", `$ ${message.command}\n${message.output}`), error: message.exitCode !== undefined && message.exitCode !== 0 });
      } else if (message.role === "custom" && message.display) {
        nodes.push(messageNode(entry.id, message.customType, contentText(message.content)));
      }
    }
  }
  return nodes;
}
