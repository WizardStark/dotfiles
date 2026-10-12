import type { ExtensionContext, ExtensionWidgetOptions, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";

type WidgetFactory = (tui: TUI, theme: Theme) => Component & { dispose?(): void };

export class ManagedWidget {
  constructor(private readonly key: string, private readonly options?: ExtensionWidgetOptions) {}

  set(ctx: ExtensionContext, content: string[] | WidgetFactory | undefined) {
    if (!ctx.hasUI) return;
    if (typeof content === "function") ctx.ui.setWidget(this.key, content, this.options);
    else ctx.ui.setWidget(this.key, content, this.options);
  }

  clear(ctx: ExtensionContext) {
    if (ctx.hasUI) ctx.ui.setWidget(this.key, undefined);
  }
}
