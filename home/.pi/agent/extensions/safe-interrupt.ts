import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { CustomEditor } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

const ESCAPE_CONFIRM_WINDOW_MS = 750;

class SafeInterruptEditor extends CustomEditor {
  private lastEscapeAt = 0;

  constructor(
    tui: ConstructorParameters<typeof CustomEditor>[0],
    theme: ConstructorParameters<typeof CustomEditor>[1],
    keybindings: ConstructorParameters<typeof CustomEditor>[2],
    private readonly ctx: ExtensionContext,
  ) {
    super(tui, theme, keybindings);
  }

  resetEscapeConfirmation(): void {
    this.lastEscapeAt = 0;
  }

  handleInput(data: string): void {
    // Keep Ctrl+C's usual editor-clearing behavior while idle. During a turn,
    // it uses app.interrupt and aborts the turn (including its subagents).
    if (matchesKey(data, "ctrl+c") && this.ctx.isIdle()) {
      this.actionHandlers.get("app.clear")?.();
      return;
    }

    // Do not turn autocomplete dismissal into an interrupt confirmation.
    if (matchesKey(data, "escape") && !this.isShowingAutocomplete()) {
      if (this.ctx.isIdle()) {
        this.resetEscapeConfirmation();
        this.onEscape?.();
        return;
      }

      const now = Date.now();
      if (now - this.lastEscapeAt <= ESCAPE_CONFIRM_WINDOW_MS) {
        this.lastEscapeAt = 0;
        this.onEscape?.();
      } else {
        this.lastEscapeAt = now;
        this.ctx.ui.notify("Press Esc again within 0.75s to interrupt.", "info");
      }
      return;
    }

    this.resetEscapeConfirmation();
    super.handleInput(data);
  }
}

export default function (pi: ExtensionAPI) {
  let editor: SafeInterruptEditor | undefined;

  // A confirmation must never carry over from one agent run to the next.
  pi.on("agent_start", () => editor?.resetEscapeConfirmation());

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      editor = new SafeInterruptEditor(tui, theme, keybindings, ctx);
      return editor;
    });
  });
}
