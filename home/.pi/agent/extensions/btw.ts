import { completeSimple, type AssistantMessage, type Message, type UserMessage } from "@earendil-works/pi-ai/compat";
import { convertToLlm, type ExtensionAPI, type ExtensionCommandContext, type Theme } from "@earendil-works/pi-coding-agent";
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
    private readonly theme: Theme,
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

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape)) {
      if (this.closed) return;
      this.closed = true;
      this.controller.abort();
      this.done();
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
    const contentWidth = Math.max(1, width - 4);
    const color = this.state === "error" ? (text: string) => this.theme.fg("error", text) : undefined;
    const body = this.body.split("\n").flatMap((line) => wrapTextWithAnsi(color ? color(line || " ") : line || " ", contentWidth));
    const footer = this.theme.fg("dim", "↑/↓ scroll · Esc dismiss");
    const lines = [
      this.theme.bg("customMessageBg", truncateToWidth(`  /btw ${this.question}`, width, "…", false)),
      "",
      ...body.map((line) => `    ${line}`),
      "",
      `  ${truncateToWidth(footer, Math.max(1, width - 2), "…", false)}`,
    ];
    const maxRows = Math.max(4, Math.floor(((this.tui.terminal as { rows?: number }).rows ?? 24) * 0.85));
    if (lines.length <= maxRows) return lines;
    const excess = lines.length - maxRows;
    this.scrollOffset = Math.min(this.scrollOffset, excess);
    return lines.slice(this.scrollOffset, this.scrollOffset + maxRows);
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

function branchMessages(ctx: ExtensionCommandContext): Message[] {
  const messages = ctx.sessionManager
    .getBranch()
    .filter((entry) => entry.type === "message")
    .map((entry) => entry.message);
  return convertToLlm(messages);
}

export default function (pi: ExtensionAPI) {
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

      await ctx.waitForIdle();
      const model = ctx.model;
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
      if (!auth.ok || !auth.apiKey) {
        ctx.ui.notify(auth.ok ? `/btw model ${model.id} has no API key` : `/btw model is misconfigured: ${auth.error}`, "error");
        return;
      }

      const controller = new AbortController();
      let overlay!: BtwOverlay;
      const visible = ctx.ui.custom<void>(
        (tui, theme, _keybindings, done) => {
          overlay = new BtwOverlay(question, tui, theme, controller, done);
          return overlay;
        },
        {
          overlay: true,
          overlayOptions: { anchor: "bottom-center", width: "100%", maxHeight: "85%", margin: { left: 0, right: 0, bottom: 0 } },
        },
      );

      void visible.finally(() => overlay.markClosed());

      const userMessage: UserMessage = {
        role: "user",
        content: [{ type: "text", text: question }],
        timestamp: Date.now(),
      };
      try {
        const response = await completeSimple(
          model,
          { systemPrompt: SYSTEM_PROMPT, messages: [...branchMessages(ctx), userMessage], tools: [] },
          { apiKey: auth.apiKey, headers: auth.headers, env: auth.env, signal: controller.signal },
        );
        if (response.stopReason === "aborted") {
          await visible;
          return;
        }
        if (response.stopReason === "error") {
          overlay.setError(response.errorMessage ?? "The side question failed.");
        } else {
          const answer = textOf(response);
          overlay.setAnswer(answer || "The side question returned no text.");
        }
      } catch (error) {
        if (!controller.signal.aborted) overlay.setError(error instanceof Error ? error.message : String(error));
      }

      await visible;
    },
  });
}
