import type { ToolRenderers } from "@earendil-works/pi-coding-agent";
import { compactCall, toolText } from "./compact-tool-renderers.ts";

type Kind = "question" | "review" | "advisor" | "delegation";
const textValue = (value: unknown) => typeof value === "string" ? value : undefined;
const object = (value: unknown): Record<string, any> => value && typeof value === "object" ? value as Record<string, any> : {};

// Structured summaries stay useful for old results lacking newer details. The
// two render slots each reuse their Text component; colors are never persisted.
export function domainRenderers(kind: Kind, title: string): ToolRenderers {
  return {
    renderShell: "self",
    renderCall(args, theme, context) {
      const input = object(args);
      const subject = kind === "question" ? `${Array.isArray(input.questions) ? input.questions.length : "?"} questions`
        : kind === "review" ? textValue(input.stage) ?? "interim"
        : kind === "delegation" && Array.isArray(input.tasks) ? `${input.tasks.length} tasks`
        : textValue(input.objective) ?? textValue(input.task) ?? "";
      // Keep arbitrary objectives out of the title's collapsed layout.
      const label = `${title}${subject ? ` · ${subject.replace(/\s+/g, " ").slice(0, 100)}` : ""}`;
      if (!context.expanded) return compactCall(label, theme, context);
      return toolText(`${theme.fg("toolTitle", label)}\n${theme.fg("dim", JSON.stringify(args ?? {}, null, 2))}`, context);
    },
    renderResult(result, options, theme, context) {
      const details = object(result.details);
      const content = result.content?.filter((block: any) => block.type === "text").map((block: any) => block.text ?? "").join("\n") ?? "";
      const state = textValue(details.phase) ?? textValue(details.status) ?? (options.isPartial ? "running" : context.isError ? "failed" : "done");
      const cancelled = details.cancelled === true;
      const tone = context.isError ? "error" : cancelled || ["blocked", "escalated", "aborted"].includes(state) ? "warning" : options.isPartial ? "accent" : "success";
      const model = textValue(details.reviewer) ?? textValue(details.advisor) ?? textValue(details.workerModel) ?? textValue(details.scoutModel) ?? textValue(details.model);
      const parts = [cancelled ? "cancelled" : state];
      if (model) parts.push(model);
      if (kind === "review" && Array.isArray(details.changedFiles)) parts.push(`${details.changedFiles.length} changed files`);
      if (kind === "advisor" && !options.isPartial && !context.isError) parts.push("task packet ready");
      if (kind === "delegation") {
        const results = Array.isArray(details.results) ? details.results : [];
        const total = details.totalCount ?? results.length;
        const completed = details.completedCount ?? results.filter((item: any) => item?.status === "completed").length;
        if (total) parts.push(`${completed}/${total} completed`);
        if (textValue(details.currentTool)) parts.push(details.currentTool);
      }
      const lines = [theme.fg(tone, parts.join(" · "))];
      if (kind === "question" && Array.isArray(details.answers)) {
        for (const answer of details.answers) {
          const values = Array.isArray(answer.selected) ? answer.selected.join(", ") : textValue(answer.answer) ?? "—";
          lines.push(theme.fg("toolOutput", `${answer.header ?? answer.question ?? "Answer"}: ${values}`));
        }
      }
      if (kind === "delegation" && Array.isArray(details.activeDelegations)) {
        for (const active of details.activeDelegations.slice(0, 4)) {
          lines.push(theme.fg("dim", `${active.title ?? "Task"} · ${active.phase ?? "running"}${active.currentTool ? ` · ${active.currentTool}` : ""}`));
        }
      }
      if (options.expanded) {
        // Do not hide reports or error causes behind a fixed 20-line preview.
        if (content) lines.push("", theme.fg(context.isError ? "error" : "toolOutput", content));
      } else if (context.isError) {
        lines.push(theme.fg("error", `${content.split("\n").find((line: string) => line.trim())?.slice(0, 160) ?? "Tool failed"} (expand for details)`));
      }
      return toolText(lines.join("\n"), context);
    },
  };
}
