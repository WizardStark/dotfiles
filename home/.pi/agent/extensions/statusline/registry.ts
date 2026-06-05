export type StatuslineSide = "left" | "right";
export type StatuslineBackground =
  | "selectedBg"
  | "userMessageBg"
  | "customMessageBg"
  | "toolPendingBg"
  | "toolSuccessBg"
  | "toolErrorBg";

export type StatuslineItem = {
  id: string;
  sessionKey?: string;
  side?: StatuslineSide;
  order?: number;
  importance?: number;
  background?: StatuslineBackground;
  content: string;
  compactContent?: string;
};

type StoredStatuslineItem = StatuslineItem & {
  sequence: number;
};

type StatuslineUpdate = Pick<StatuslineItem, "content"> & Partial<Omit<StatuslineItem, "content">>;
type Subscriber = () => void;

class StatuslineRegistry {
  private items = new Map<string, StoredStatuslineItem>();
  private subscribers = new Set<Subscriber>();
  private nextSequence = 0;

  upsert(item: StatuslineItem) {
    const key = this.getKey(item.id, item.sessionKey);
    const previous = this.items.get(key);
    this.items.set(key, {
      sessionKey: item.sessionKey,
      side: "right",
      order: 0,
      importance: 0,
      ...previous,
      ...item,
      sequence: previous?.sequence ?? this.nextSequence++,
    });
    this.emit();
  }

  remove(id: string, sessionKey?: string) {
    if (!this.items.delete(this.getKey(id, sessionKey))) {
      return;
    }
    this.emit();
  }

  list(sessionKey?: string): StatuslineItem[] {
    return [...this.items.values()]
      .filter((item) => (item.sessionKey ?? "default") === (sessionKey ?? "default"))
      .sort((left, right) => {
        const sideCompare = (left.side ?? "right").localeCompare(right.side ?? "right");
        if (sideCompare !== 0) return sideCompare;

        const orderCompare = (left.order ?? 0) - (right.order ?? 0);
        if (orderCompare !== 0) return orderCompare;

        return left.sequence - right.sequence;
      })
      .map(({ sequence: _sequence, ...item }) => item);
  }

  subscribe(subscriber: Subscriber) {
    this.subscribers.add(subscriber);
    return () => {
      this.subscribers.delete(subscriber);
    };
  }

  private emit() {
    for (const subscriber of this.subscribers) {
      subscriber();
    }
  }

  private getKey(id: string, sessionKey?: string) {
    return `${sessionKey ?? "default"}:${id}`;
  }
}

declare global {
  // eslint-disable-next-line no-var
  var __PI_STATUSLINE_REGISTRY__: StatuslineRegistry | undefined;
}

function getRegistry() {
  globalThis.__PI_STATUSLINE_REGISTRY__ ??= new StatuslineRegistry();
  return globalThis.__PI_STATUSLINE_REGISTRY__;
}

export function listStatuslineItems(sessionKey?: string) {
  return getRegistry().list(sessionKey);
}

export function upsertStatuslineItem(item: StatuslineItem) {
  getRegistry().upsert(item);
}

export function clearStatuslineItem(id: string, sessionKey?: string) {
  getRegistry().remove(id, sessionKey);
}

export function subscribeStatusline(subscriber: Subscriber) {
  return getRegistry().subscribe(subscriber);
}

export function getStatuslineSessionKey(ctx: { sessionManager: { getSessionFile(): string | undefined } }) {
  return ctx.sessionManager.getSessionFile() ?? "ephemeral";
}

export function createStatuslineItem(defaults: Omit<StatuslineItem, "content">) {
  return {
    set(update: StatuslineUpdate, sessionKey?: string) {
      upsertStatuslineItem({
        side: "right",
        order: 0,
        importance: 0,
        ...defaults,
        ...update,
        id: defaults.id,
        sessionKey,
      });
    },
    clear(sessionKey?: string) {
      clearStatuslineItem(defaults.id, sessionKey);
    },
  };
}
