import { createSessionWork, isCancelledWork } from "./lib/session-work.ts";
import type { AssistantMessage, Message, UserMessage } from "@earendil-works/pi-ai";
import { type ExtensionAPI, type ExtensionCommandContext, type Theme } from "@earendil-works/pi-coding-agent";
import { textFromMessage } from "./lib/session-messages.ts";
import { Key, matchesKey, truncateToWidth, wrapTextWithAnsi, type Component, type TUI } from "@earendil-works/pi-tui";

const SYSTEM_PROMPT = `Answer the side question directly and concisely using the primary conversation as background. Do not continue the primary task, call tools, or claim context you do not have. If context is insufficient, say so briefly.`;

type OverlayState = "pending" | "answer" | "error";

class BtwOverlay implements Component {
  private state: OverlayState = "pending";
  private body = "…";
  private scrollOffset = 0;
  private closed = false;

  constructor(
    private readonly question: string,
    private readonly tui: TUI,
    private readonly getTheme: () => Theme,
    private readonly controller: AbortController,
    private readonly done: () => void,
  ) {}

  setAnswer(answer: string): void {
    if (this.closed) return;
    this.state = "answer";
    this.body = answer;
    this.tui.requestRender();
  }

  setError(error: string): void {
    if (this.closed) return;
    this.state = "error";
    this.body = error;
    this.tui.requestRender();
  }

  markClosed(): void {
    this.closed = true;
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.controller.abort();
    this.done();
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape)) {
      this.close();
      return;
    }
    if (matchesKey(data, Key.up)) {
      this.scrollOffset = Math.max(0, this.scrollOffset - 1);
      this.tui.requestRender();
      return;
    }
    if (matchesKey(data, Key.down)) {
      this.scrollOffset += 1;
      this.tui.requestRender();
    }
  }

  render(width: number): string[] {
    const theme = this.getTheme();
    const contentWidth = Math.max(1, width - 4);
    const color = this.state === "error" ? (text: string) => theme.fg("error", text) : undefined;
    const body = this.body.split("\n").flatMap((line) => wrapTextWithAnsi(color ? color(line || " ") : line || " ", contentWidth));
    const footer = theme.fg("dim", "↑/↓ scroll · Esc dismiss");
    const lines = [
      theme.bg("customMessageBg", truncateToWidth(`  /btw ${this.question}`, width, "…", false)),
      "",
      ...body.map((line) => `    ${line}`),
      "",
      `  ${truncateToWidth(footer, Math.max(1, width - 2), "…", false)}`,
    ];
    const maxRows = Math.max(4, Math.floor(((this.tui.terminal as { rows?: number }).rows ?? 24) * 0.85));
    const clipped = lines.map((line) => truncateToWidth(line, width));
    if (lines.length <= maxRows) return clipped;
    const excess = lines.length - maxRows;
    this.scrollOffset = Math.min(this.scrollOffset, excess);
    return clipped.slice(this.scrollOffset, this.scrollOffset + maxRows);
  }

  invalidate(): void {}
}

function textOf(message: AssistantMessage): string {
  return message.content
    .filter((part): part is { type: "text"; text: string } => part.type === "text")
    .map((part) => part.text)
    .join("\n")
    .trim();
}

function projectedMessages(ctx: ExtensionCommandContext): Message[] {
  // The side question owns its system prompt and declares no tools. Flatten the
  // projected conversation into text so historical tool calls/results cannot
  // become dangling tool protocol messages in this no-tools request.
  const background = ctx.sessionManager
    .buildSessionProjection()
    .messages
    .filter((message) => message.role === "user" || message.role === "assistant")
    .map((message) => {
      const text = textFromMessage(message);
      return text ? `${message.role}: ${text}` : "";
    })
    .filter(Boolean)
    .join("\n\n");

  return background
    ? [{
        role: "user",
        content: [{ type: "text", text: `Primary conversation background:\n\n${background}` }],
        timestamp: Date.now(),
      }]
    : [];
}

export default function (pi: ExtensionAPI) {
  const sessionWork = createSessionWork(pi);
  pi.registerCommand("btw", {
    description: "Ask a side question without adding it to the transcript",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/btw requires interactive terminal mode", "error");
        return;
      }
      const question = args.trim();
      if (!question) {
        ctx.ui.notify("Usage: /btw <question>", "warning");
        return;
      }
      if (!ctx.model) {
        ctx.ui.notify("/btw requires an active model", "error");
        return;
      }

      const work = sessionWork.start(ctx.signal);
      let close: (() => void) | undefined;
      try {
        await ctx.waitForIdle();
        work.assertCurrent();
        work.signal.throwIfAborted();
        const model = ctx.model;
        const controller = new AbortController();
        let overlay!: BtwOverlay;
        const visible = ctx.ui.custom<void>(
          (tui, _theme, _keybindings, done) => {
            overlay = new BtwOverlay(question, tui, () => ctx.ui.theme, controller, done);
            close = () => overlay.close();
            work.signal.addEventListener("abort", close, { once: true });
            if (work.signal.aborted) close();
            return overlay;
          },
          {
            overlay: true,
            overlayOptions: { anchor: "bottom-center", width: "100%", maxHeight: "85%", margin: { left: 0, right: 0, bottom: 0 } },
          },
        );

        void visible.then(() => overlay?.markClosed(), () => { controller.abort(); overlay?.markClosed(); });

        const userMessage: UserMessage = {
          role: "user",
          content: [{ type: "text", text: question }],
          timestamp: Date.now(),
        };
        try {
          const stream = ctx.modelRegistry.streamSimple(
            model,
            { systemPrompt: SYSTEM_PROMPT, messages: [...projectedMessages(ctx), userMessage], tools: [] },
            { reasoning: ctx.thinkingLevel === "off" ? undefined : ctx.thinkingLevel, signal: AbortSignal.any([work.signal, controller.signal]) },
          );
          for await (const event of stream) {
            if (event.type === "text_delta" || event.type === "text_end") {
              const answer = textOf(event.partial);
              if (answer) overlay.setAnswer(answer);
            }
          }
          const response = await stream.result();
          if (response.stopReason === "aborted") {
            await visible;
            return;
          }
          if (response.stopReason === "error") {
            overlay.setError(response.errorMessage ?? "The side question failed.");
          } else {
            overlay.setAnswer(textOf(response) || "The side question returned no text.");
          }
        } catch (error) {
          if (!controller.signal.aborted) overlay.setError(error instanceof Error ? error.message : String(error));
        }

        await visible;
      } catch (error) {
        if (work.isCurrent() && !isCancelledWork(error)) throw error;
      } finally {
        if (close) work.signal.removeEventListener("abort", close);
        work.dispose();
      }
    },
  });
}
