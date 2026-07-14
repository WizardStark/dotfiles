import type {
  ExtensionUIContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { type TUI, truncateToWidth } from "@earendil-works/pi-tui";

export type DelegationTaskStatus =
  | "in_progress"
  | "finalizing"
  | "completed"
  | "blocked"
  | "escalated";

export type DelegationTaskRole = "worker" | "scout";

export interface DelegationTaskItem {
  id: string;
  title: string;
  status: DelegationTaskStatus;
  role: DelegationTaskRole;
  activeForm?: string;
}

const WIDGET_KEY = "delegation-tasks";
const MAX_WIDGET_LINES = 12;
const OVERLAY_HEADING = "Delegations";
const OVERLAY_MORE = "more";

function overlayStatusGlyph(status: DelegationTaskStatus, theme: Theme): string {
  switch (status) {
    case "in_progress":
      return theme.fg("warning", "◐");
    case "finalizing":
      return theme.fg("warning", "◔");
    case "completed":
      return theme.fg("success", "✓");
    case "blocked":
      return theme.fg("error", "✗");
    case "escalated":
      return theme.fg("warning", "⚠");
  }
}

function formatOverlayTaskLine(task: DelegationTaskItem, theme: Theme): string {
  const glyph = overlayStatusGlyph(task.status, theme);
  const terminal =
    task.status === "completed" ||
    task.status === "blocked" ||
    task.status === "escalated";
  const subjectColor = terminal ? "dim" : "text";
  let subject = theme.fg(subjectColor, task.title);
  if (task.status === "completed") {
    subject = theme.strikethrough(subject);
  }
  let line = `${glyph} ${subject}`;
  if (
    (task.status === "in_progress" || task.status === "finalizing") &&
    task.activeForm
  ) {
    line += ` ${theme.fg("dim", `(${task.activeForm})`)}`;
  }
  return line;
}

function summarizeHiddenTasks(hidden: DelegationTaskItem[]): string {
  const active = hidden.filter((task) => task.status === "in_progress").length;
  const finalizing = hidden.filter(
    (task) => task.status === "finalizing",
  ).length;
  const completed = hidden.filter((task) => task.status === "completed").length;
  const blocked = hidden.filter((task) => task.status === "blocked").length;
  const escalated = hidden.filter((task) => task.status === "escalated").length;
  const parts: string[] = [];
  if (active > 0) parts.push(`${active} active`);
  if (finalizing > 0) parts.push(`${finalizing} finalizing`);
  if (completed > 0) parts.push(`${completed} completed`);
  if (blocked > 0) parts.push(`${blocked} blocked`);
  if (escalated > 0) parts.push(`${escalated} escalated`);
  return parts.length > 0 ? parts.join(", ") : `${hidden.length} hidden`;
}

export class DelegationTaskWidget {
  private uiCtx: ExtensionUIContext | undefined;
  private widgetRegistered = false;
  private tui: TUI | undefined;
  private tasks: DelegationTaskItem[] = [];

  setUICtx(ctx: ExtensionUIContext): void {
    if (ctx !== this.uiCtx) {
      this.uiCtx = ctx;
      this.widgetRegistered = false;
      this.tui = undefined;
    }
  }

  update(tasks: DelegationTaskItem[]): void {
    this.tasks = [...tasks];
    if (!this.uiCtx) return;

    if (this.tasks.length === 0) {
      this.clear();
      return;
    }

    if (!this.widgetRegistered) {
      this.registerWidget();
    } else {
      this.tui?.requestRender();
    }
  }

  private registerWidget(): void {
    if (!this.uiCtx || this.tasks.length === 0) return;
    this.uiCtx.setWidget(
      WIDGET_KEY,
      (tui, theme) => {
        this.tui = tui;
        return {
          render: (width: number) => this.renderWidget(theme, width),
          invalidate: () => {
            this.widgetRegistered = false;
            this.tui = undefined;
            if (this.uiCtx && this.tasks.length > 0) {
              this.registerWidget();
              this.tui?.requestRender();
            }
          },
        };
      },
      { placement: "aboveEditor" },
    );
    this.widgetRegistered = true;
  }

  private renderWidget(theme: Theme, width: number): string[] {
    if (this.tasks.length === 0) return [];
    const truncate = (line: string): string => truncateToWidth(line, width, "…");
    const activeCount = this.tasks.filter(
      (task) => task.status === "in_progress" || task.status === "finalizing",
    ).length;
    const doneCount = this.tasks.length - activeCount;
    const headingColor = activeCount > 0 ? "accent" : "dim";
    const headingIcon = activeCount > 0 ? "●" : "○";
    const headingText = `${OVERLAY_HEADING} (${doneCount}/${this.tasks.length})`;
    const heading = truncate(
      `${theme.fg(headingColor, headingIcon)} ${theme.fg(headingColor, headingText)}`,
    );

    const lines: string[] = [heading];
    const visibleCount = Math.max(1, MAX_WIDGET_LINES - 1);
    const visible = this.tasks.slice(0, visibleCount);
    const hidden = this.tasks.slice(visibleCount);
    for (const task of visible) {
      lines.push(
        truncate(
          `${theme.fg("dim", "├─")} ${formatOverlayTaskLine(task, theme)}`,
        ),
      );
    }

    if (hidden.length === 0) {
      const last = lines.length - 1;
      lines[last] = lines[last].replace("├─", "└─");
      return this.withTrailingSpacer(lines);
    }

    const summary = `+${hidden.length} ${OVERLAY_MORE} (${summarizeHiddenTasks(hidden)})`;
    lines.push(
      truncate(`${theme.fg("dim", "└─")} ${theme.fg("dim", summary)}`),
    );
    return this.withTrailingSpacer(lines);
  }

  private withTrailingSpacer(lines: string[]): string[] {
    if (lines.length === 0) return lines;
    lines.push("");
    return lines;
  }

  clear(): void {
    if (this.uiCtx) this.uiCtx.setWidget(WIDGET_KEY, undefined);
    this.widgetRegistered = false;
    this.tui = undefined;
    this.tasks = [];
  }

  dispose(): void {
    this.clear();
    this.uiCtx = undefined;
  }
}
