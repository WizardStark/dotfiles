import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export class StaleSessionWorkError extends Error {
  constructor() {
    super("The session was replaced or its branch changed.");
    this.name = "StaleSessionWorkError";
  }
}

export function isCancelledWork(error: unknown): boolean {
  return error instanceof StaleSessionWorkError ||
    (error instanceof Error && error.name === "AbortError");
}

/** Own asynchronous work even when an idle command has no ctx.signal. */
export function createSessionWork(pi: ExtensionAPI) {
  let epoch = 0;
  const controllers = new Set<AbortController>();
  const invalidate = () => {
    epoch += 1;
    for (const controller of controllers) controller.abort();
    controllers.clear();
  };
  pi.on("session_start", invalidate);
  pi.on("session_tree", invalidate);
  pi.on("session_shutdown", invalidate);
  return {
    start(signal?: AbortSignal) {
      const owner = epoch;
      const controller = new AbortController();
      const abort = () => controller.abort();
      if (signal?.aborted) abort();
      else signal?.addEventListener("abort", abort, { once: true });
      controllers.add(controller);
      return {
        signal: controller.signal,
        async wait<T>(promise: Promise<T>): Promise<T> {
          let abort: (() => void) | undefined;
          const cancelled = new Promise<never>((_resolve, reject) => {
            abort = () => reject(new DOMException("Operation cancelled.", "AbortError"));
            if (controller.signal.aborted) abort();
            else controller.signal.addEventListener("abort", abort, { once: true });
          });
          try {
            return await Promise.race([promise, cancelled]);
          } finally {
            if (abort) controller.signal.removeEventListener("abort", abort);
          }
        },
        isCurrent: () => owner === epoch,
        assertCurrent() {
          if (owner !== epoch) throw new StaleSessionWorkError();
        },
        dispose() {
          signal?.removeEventListener("abort", abort);
          controllers.delete(controller);
        },
      };
    },
  };
}
