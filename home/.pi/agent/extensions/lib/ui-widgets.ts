import type { ExtensionContext, ExtensionWidgetOptions } from "@earendil-works/pi-coding-agent";

/**
 * Manages the lifecycle of a named UI widget, ensuring it is cleared on shutdown
 * and provides a simple set/clear interface.
 */
export class ManagedWidget {
	constructor(
		private readonly key: string,
		private readonly options?: ExtensionWidgetOptions,
	) {}

	set(ctx: ExtensionContext, content: string[] | ((...args: any[]) => any) | undefined) {
		if (!ctx.hasUI) return;
		ctx.ui.setWidget(this.key, content, this.options);
	}

	clear(ctx: ExtensionContext) {
		if (!ctx.hasUI) return;
		ctx.ui.setWidget(this.key, undefined);
	}
}

/**
 * A helper for widgets that should automatically clear after a timeout.
 */
export class TransientWidget extends ManagedWidget {
	private timer: ReturnType<typeof setTimeout> | undefined;

	set(ctx: ExtensionContext, content: string[] | undefined, timeoutMs = 15000) {
		this.clearTimer();
		super.set(ctx, content);

		if (content !== undefined && timeoutMs > 0) {
			this.timer = setTimeout(() => {
				this.clear(ctx);
				this.timer = undefined;
			}, timeoutMs);
			this.timer.unref?.();
		}
	}

	clear(ctx: ExtensionContext) {
		this.clearTimer();
		super.clear(ctx);
	}

	private clearTimer() {
		if (this.timer) {
			clearTimeout(this.timer);
			this.timer = undefined;
		}
	}
}
