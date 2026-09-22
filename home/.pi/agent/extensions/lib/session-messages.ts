import type { AgentMessage } from "@earendil-works/pi-agent-core";

export function truncate(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n...[truncated ${text.length - maxChars} chars]`;
}

export function textFromMessage(message: AgentMessage): string {
  if (message.role === "assistant" || message.role === "user" || message.role === "system") {
    return (message.content ?? [])
      .map((part) => {
        if (part.type === "text") return part.text ?? "";
        if (part.type === "thinking") return "";
        return "";
      })
      .join("\n")
      .trim();
  }

  if (message.role === "compactionSummary") {
    return message.summary?.trim() ?? "";
  }

  return "";
}
