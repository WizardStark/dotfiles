#!/usr/bin/env node

import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname } from "node:path";
import { spawnSync } from "node:child_process";

interface NotificationRecord {
  type: "notification";
  id: string;
  createdAt?: string;
  kind?: "completed" | "stuck";
  summary?: string;
  sessionName?: string;
  sessionKey?: string;
  sessionFile?: string;
  paneId?: string;
  tmuxServer?: string;
  cwd?: string;
  read?: boolean;
  _fileOrder?: number;
}

interface ReadRecord {
  type: "read";
  notificationId?: string;
  sessionKey?: string;
  createdAt?: string;
}

type StoreRecord = NotificationRecord | ReadRecord | Record<string, unknown>;
type Filter = "inbox" | "all" | "read";
type Target = { type: "session"; sessionKey: string } | { type: "notification"; sessionKey: string; id: string };

interface SessionGroup {
  key: string;
  notifications: NotificationRecord[];
  latest: NotificationRecord;
  unreadCount: number;
}

interface PiTuiModule {
  Key: {
    up: string;
    down: string;
    left: string;
    right: string;
    enter: string;
    escape: string;
    tab: string;
    backspace: string;
    ctrl(key: string): string;
  };
  ProcessTerminal: new () => { rows: number };
  TuiAltScreen: new (terminal: unknown, showHardwareCursor?: boolean, logDirectory?: string, options?: object) => {
    addChild(component: UiComponent): void;
    setFocus(component: UiComponent | null): void;
    start(): void;
    stop(): void;
    requestRender(force?: boolean): void;
    flash(message: string, durationMs?: number): void;
  };
  matchesKey(data: string, key: string): boolean;
  truncateToWidth(text: string, width: number, ellipsis?: string): string;
  visibleWidth(text: string): number;
}

interface UiComponent {
  render(width: number): string[];
  handleInput(data: string): void;
  invalidate(): void;
}

const args = process.argv.slice(2);
const tuiFlag = args.indexOf("--pi-tui");
if (tuiFlag < 0 || !args[tuiFlag + 1]) {
  console.error("Missing --pi-tui path");
  process.exit(2);
}
const tuiPath = args[tuiFlag + 1];
args.splice(tuiFlag, 2);

const STORE = process.env.PI_NOTIFICATION_STORE
  ?? `${homedir()}/.pi/agent/notifications.jsonl`;
const DEFAULT_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const REVERSE = "\x1b[7m";
const FG = {
  text: "\x1b[38;2;205;214;244m",
  muted: "\x1b[38;2;147;153;178m",
  dim: "\x1b[38;2;108;112;134m",
  accent: "\x1b[38;2;203;166;247m",
  success: "\x1b[38;2;166;227;161m",
  warning: "\x1b[38;2;249;226;175m",
  error: "\x1b[38;2;243;139;168m",
};

function loadEvents(): StoreRecord[] {
  if (!existsSync(STORE)) return [];
  const events: StoreRecord[] = [];
  for (const line of readFileSync(STORE, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (event && typeof event === "object") events.push(event);
    } catch {
      // Ignore an incomplete or malformed append; later records remain usable.
    }
  }
  return events;
}

function instant(value: unknown): number | undefined {
  if (typeof value !== "string") return undefined;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function notifications(): NotificationRecord[] {
  const events = loadEvents();
  const items = events
    .filter((event): event is NotificationRecord => event.type === "notification" && typeof event.id === "string")
    .map((item, fileOrder) => ({ ...item, _fileOrder: fileOrder }))
    .sort((left, right) => {
      const leftTime = instant(left.createdAt);
      const rightTime = instant(right.createdAt);
      if (leftTime !== undefined && rightTime !== undefined && leftTime !== rightTime) return leftTime - rightTime;
      if (leftTime !== undefined && rightTime === undefined) return -1;
      if (leftTime === undefined && rightTime !== undefined) return 1;
      return (left._fileOrder ?? 0) - (right._fileOrder ?? 0);
    });

  const positions = new Map(items.map((item, index) => [item.id, index]));
  const readThrough = new Map<string, number>();
  for (const event of events) {
    if (event.type !== "read") continue;
    const record = event as ReadRecord;
    const position = record.notificationId ? positions.get(record.notificationId) : undefined;
    if (position === undefined) continue;
    const item = items[position];
    if (!item.sessionKey || item.sessionKey !== record.sessionKey) continue;
    readThrough.set(item.sessionKey, Math.max(readThrough.get(item.sessionKey) ?? -1, position));
  }

  return items.map((item, position) => {
    const { _fileOrder: _, ...copy } = item;
    return { ...copy, read: position <= (readThrough.get(item.sessionKey ?? "") ?? -1) };
  });
}

function groupNotifications(items: NotificationRecord[]): SessionGroup[] {
  const grouped = new Map<string, NotificationRecord[]>();
  for (const item of items) {
    const key = item.sessionKey ?? item.sessionFile ?? item.paneId ?? item.cwd ?? item.id;
    const group = grouped.get(key) ?? [];
    group.push(item);
    grouped.set(key, group);
  }
  return [...grouped.entries()]
    .map(([key, records]) => ({
      key,
      notifications: records,
      latest: records[records.length - 1],
      unreadCount: records.filter((record) => !record.read).length,
    }))
    .sort((left, right) => {
      if ((left.unreadCount > 0) !== (right.unreadCount > 0)) return left.unreadCount > 0 ? -1 : 1;
      return (instant(right.latest.createdAt) ?? 0) - (instant(left.latest.createdAt) ?? 0);
    });
}

function appendRead(item: NotificationRecord): void {
  mkdirSync(dirname(STORE), { recursive: true });
  const event: ReadRecord = {
    type: "read",
    notificationId: item.id,
    sessionKey: item.sessionKey,
    createdAt: new Date().toISOString(),
  };
  appendFileSync(STORE, `${JSON.stringify(event)}\n`, "utf8");
}

function compactPath(path: string | undefined): string {
  if (!path) return "Unknown session";
  const home = homedir();
  return path === home || path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path;
}

function relativeTime(value: string | undefined): string {
  const timestamp = instant(value);
  if (timestamp === undefined) return "unknown";
  const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));
  if (seconds < 60) return "now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

function currentTmuxServer(): string | undefined {
  const parts = (process.env.TMUX ?? "").split(",");
  return parts.length >= 2 ? parts.slice(0, 2).join(",") : undefined;
}

function runTmux(...command: string[]) {
  return spawnSync("tmux", command, { encoding: "utf8" });
}

function openSession(item: NotificationRecord): string | undefined {
  if (!item.paneId || !item.tmuxServer || item.tmuxServer !== currentTmuxServer()) {
    return "The originating tmux server is no longer available";
  }
  const pane = runTmux("display-message", "-p", "-t", item.paneId, "#{pane_dead}");
  if (pane.status !== 0 || pane.stdout.trim() === "1") return "The originating tmux pane is no longer available";

  const session = runTmux("display-message", "-p", "-t", item.paneId, "#{session_name}");
  const window = runTmux("display-message", "-p", "-t", item.paneId, "#{window_index}");
  const client = runTmux("display-message", "-p", "#{client_tty}");
  if (session.status !== 0 || window.status !== 0 || client.status !== 0) return "Could not resolve the tmux target";

  const sessionName = session.stdout.trim();
  const windowIndex = window.stdout.trim();
  const clientTty = client.stdout.trim();
  if (!sessionName || !windowIndex || !clientTty) return "Could not resolve the tmux target";

  for (const command of [
    ["switch-client", "-c", clientTty, "-t", sessionName],
    ["select-window", "-t", `${sessionName}:${windowIndex}`],
    ["select-pane", "-t", item.paneId],
  ]) {
    if (runTmux(...command).status !== 0) return "Could not open the tmux target";
  }
  return undefined;
}

function printRecords(): void {
  for (const item of notifications()) console.log(JSON.stringify(item));
}

const recordsIndex = args.indexOf("--records");
if (recordsIndex >= 0) {
  printRecords();
  process.exit(0);
}
const markIndex = args.indexOf("--mark");
if (markIndex >= 0) {
  const id = args[markIndex + 1];
  const item = notifications().find((candidate) => candidate.id === id);
  if (!item) {
    console.error(`Unknown notification: ${id ?? ""}`);
    process.exit(2);
  }
  appendRead(item);
  process.exit(0);
}

const tuiModule = await import(tuiPath) as PiTuiModule;
const { Key, ProcessTerminal, TuiAltScreen, matchesKey, truncateToWidth, visibleWidth } = tuiModule;
const terminal = new ProcessTerminal();
const tui = new TuiAltScreen(terminal, false, undefined, { mouse: false });

class NotificationInbox implements UiComponent {
  private items = notifications();
  private groups: SessionGroup[] = [];
  private expanded = new Set<string>();
  private filter: Filter = "inbox";
  private showAllAges = false;
  private selectedKey = "";
  private searchMode = false;
  private query = "";
  private poll?: ReturnType<typeof setInterval>;
  private readonly close: () => void;

  constructor(close: () => void) {
    this.close = close;
    this.rebuild();
    this.poll = setInterval(() => {
      const next = notifications();
      if (JSON.stringify(next) !== JSON.stringify(this.items)) {
        const groupIndex = this.groups.findIndex((group) => group.key === this.selectedTarget()?.sessionKey);
        this.items = next;
        this.rebuild(Math.max(0, groupIndex));
        tui.requestRender();
      } else {
        tui.requestRender(); // refresh relative times
      }
    }, 1000);
  }

  dispose(): void {
    if (this.poll) clearInterval(this.poll);
  }

  invalidate(): void {}

  private ageVisibleItems(): NotificationRecord[] {
    if (this.showAllAges) return this.items;
    const cutoff = Date.now() - DEFAULT_MAX_AGE_MS;
    return this.items.filter((item) => {
      const createdAt = instant(item.createdAt);
      return createdAt === undefined || createdAt >= cutoff;
    });
  }

  private rebuild(fallbackGroupIndex = 0): void {
    const query = this.query.toLocaleLowerCase();
    const ageVisibleItems = this.ageVisibleItems();
    const visibleItems = this.filter === "read" ? ageVisibleItems.filter((item) => item.read) : ageVisibleItems;
    this.groups = groupNotifications(visibleItems).filter((group) => {
      if (this.filter === "inbox" && group.unreadCount === 0) return false;
      if (!query) return true;
      return group.notifications.some((item) =>
        `${item.cwd ?? ""} ${item.summary ?? ""}`.toLocaleLowerCase().includes(query));
    });
    const targets = this.targets();
    if (!targets.some((target) => this.targetKey(target) === this.selectedKey)) {
      // If an Inbox action removes the selected session, stay at its former
      // list position instead of jumping back to the first session.
      const fallbackGroup = this.groups[Math.min(Math.max(0, fallbackGroupIndex), this.groups.length - 1)];
      this.selectedKey = fallbackGroup ? `s:${fallbackGroup.key}` : "";
    }
  }

  private visibleHistory(group: SessionGroup): NotificationRecord[] {
    if (this.filter === "read") return group.notifications.filter((item) => item.read);
    return group.notifications;
  }

  private targets(): Target[] {
    const targets: Target[] = [];
    for (const group of this.groups) {
      targets.push({ type: "session", sessionKey: group.key });
      if (this.expanded.has(group.key)) {
        for (const item of [...this.visibleHistory(group)].reverse()) {
          targets.push({ type: "notification", sessionKey: group.key, id: item.id });
        }
      }
    }
    return targets;
  }

  private targetKey(target: Target): string {
    return target.type === "session" ? `s:${target.sessionKey}` : `n:${target.id}`;
  }

  private selectedTarget(): Target | undefined {
    return this.targets().find((target) => this.targetKey(target) === this.selectedKey);
  }

  private selectedGroup(): SessionGroup | undefined {
    const target = this.selectedTarget();
    return target ? this.groups.find((group) => group.key === target.sessionKey) : undefined;
  }

  private selectedNotification(): NotificationRecord | undefined {
    const target = this.selectedTarget();
    const group = this.selectedGroup();
    if (!target || !group) return undefined;
    return target.type === "notification"
      ? group.notifications.find((item) => item.id === target.id)
      : group.latest;
  }

  private move(offset: number): void {
    const targets = this.targets();
    if (targets.length === 0) return;
    const current = Math.max(0, targets.findIndex((target) => this.targetKey(target) === this.selectedKey));
    this.selectedKey = this.targetKey(targets[Math.max(0, Math.min(targets.length - 1, current + offset))]);
  }

  private toggleSelected(expand?: boolean): void {
    const target = this.selectedTarget();
    if (!target) return;
    if (target.type === "notification") {
      if (expand !== false) this.openSelected();
      return;
    }
    const shouldExpand = expand ?? !this.expanded.has(target.sessionKey);
    if (shouldExpand) this.expanded.add(target.sessionKey);
    else this.expanded.delete(target.sessionKey);
    this.rebuild();
  }

  private markSelected(all = false): void {
    const group = this.selectedGroup();
    if (!group) return;
    const groupIndex = this.groups.findIndex((candidate) => candidate.key === group.key);
    const item = all ? group.latest : this.selectedNotification();
    if (!item) return;
    appendRead(item);
    this.items = notifications();
    this.rebuild(groupIndex);
    tui.flash(all ? "Session marked read" : "Notification marked read");
  }

  private openSelected(): void {
    const item = this.selectedNotification();
    if (!item) return;
    const group = this.selectedGroup();
    const groupIndex = group ? this.groups.findIndex((candidate) => candidate.key === group.key) : 0;
    appendRead(item);
    const error = openSession(item);
    if (error) {
      this.items = notifications();
      this.rebuild(groupIndex);
      tui.flash(error, 2500);
      return;
    }
    this.close();
  }

  private cycleFilter(): void {
    const filters: Filter[] = ["inbox", "all", "read"];
    this.filter = filters[(filters.indexOf(this.filter) + 1) % filters.length];
    this.rebuild();
  }

  private toggleAge(): void {
    const groupIndex = this.groups.findIndex((group) => group.key === this.selectedTarget()?.sessionKey);
    this.showAllAges = !this.showAllAges;
    this.rebuild(Math.max(0, groupIndex));
  }

  handleInput(data: string): void {
    if (this.searchMode) {
      if (matchesKey(data, Key.escape)) {
        this.searchMode = false;
        this.query = "";
      } else if (matchesKey(data, Key.enter)) {
        this.searchMode = false;
      } else if (matchesKey(data, Key.backspace)) {
        this.query = this.query.slice(0, -1);
      } else if (data.length === 1 && data >= " ") {
        this.query += data;
      }
      this.rebuild();
      tui.requestRender();
      return;
    }

    if (matchesKey(data, Key.up) || data === "k") this.move(-1);
    else if (matchesKey(data, Key.down) || data === "j") this.move(1);
    else if (matchesKey(data, Key.right) || data === "l") this.toggleSelected(true);
    else if (matchesKey(data, Key.left) || data === "h") this.toggleSelected(false);
    else if (matchesKey(data, Key.enter)) this.toggleSelected();
    else if (matchesKey(data, Key.tab)) this.cycleFilter();
    else if (data === "a") this.toggleAge();
    else if (data === "r") this.markSelected(false);
    else if (data === "R") this.markSelected(true);
    else if (data === "o") this.openSelected();
    else if (data === "/") this.searchMode = true;
    else if (data === "q" || matchesKey(data, Key.ctrl("c"))) this.close();
    else if (matchesKey(data, Key.escape)) {
      if (this.expanded.size > 0) {
        this.expanded.clear();
        this.rebuild();
      } else this.close();
    }
    tui.requestRender();
  }

  private fit(left: string, right: string, width: number): string {
    const gap = Math.max(1, width - visibleWidth(left) - visibleWidth(right));
    if (gap === 1 && visibleWidth(left) + visibleWidth(right) + 1 > width) {
      return `${truncateToWidth(left, Math.max(1, width - visibleWidth(right) - 1))} ${right}`;
    }
    return `${left}${" ".repeat(gap)}${right}`;
  }

  private select(line: string, selected: boolean, width: number): string {
    const fitted = truncateToWidth(line, width, "…");
    if (!selected) return fitted;
    const padding = " ".repeat(Math.max(0, width - visibleWidth(fitted)));
    return `${REVERSE}${fitted}${padding}${RESET}`;
  }

  private renderSession(group: SessionGroup, selected: boolean, width: number): string[] {
    const open = this.expanded.has(group.key);
    const state = group.unreadCount > 0 ? `${FG.accent}●${RESET}` : `${FG.dim}○${RESET}`;
    const arrow = open ? "▼" : "▶";
    const location = compactPath(group.latest.cwd ?? group.latest.sessionFile ?? group.latest.paneId);
    const label = group.latest.sessionName ? `${group.latest.sessionName} · ${location}` : location;
    const unread = group.unreadCount > 0 ? `${group.unreadCount} unread` : "read";
    const heading = this.fit(
      ` ${arrow} ${state} ${BOLD}${label}${RESET}`,
      `${group.latest.kind === "stuck" ? `${FG.warning}! stuck${RESET}  ` : ""}${unread}  ${relativeTime(group.latest.createdAt)} `,
      width,
    );
    const summary = `     ${FG.text}${group.latest.summary ?? "Pi task"}${RESET}`;
    return [this.select(heading, selected, width), truncateToWidth(summary, width, "…")];
  }

  private renderNotification(item: NotificationRecord, selected: boolean, width: number): string[] {
    const state = item.read ? `${FG.dim}○${RESET}` : item.kind === "stuck" ? `${FG.warning}!${RESET}` : `${FG.success}●${RESET}`;
    const meta = `       ${state} ${FG.muted}${relativeTime(item.createdAt).padStart(4)}  ${item.kind === "stuck" ? "Stuck" : "Completed"}${RESET}`;
    const summary = `          ${item.read ? DIM : ""}${item.summary ?? "Pi task"}${RESET}`;
    return [this.select(meta, selected, width), truncateToWidth(summary, width, "…")];
  }

  render(width: number): string[] {
    const safeWidth = Math.max(1, width);
    const ageVisibleItems = this.ageVisibleItems();
    const unread = ageVisibleItems.filter((item) => !item.read).length;
    const hiddenOlder = this.items.length - ageVisibleItems.length;
    const status = unread ? `${FG.accent}${unread} unread${RESET}` : `${FG.dim}all caught up${RESET}`;
    const hiddenStatus = hiddenOlder > 0 ? `${FG.dim} · ${hiddenOlder} older hidden${RESET}` : "";
    const title = this.fit(
      ` ${FG.accent}${BOLD}Pi notifications${RESET}`,
      `${status}${hiddenStatus} `,
      safeWidth,
    );
    const tabs = (["inbox", "all", "read"] as Filter[]).map((filter) =>
      filter === this.filter ? `${FG.accent}${BOLD}[${filter.toUpperCase()}]${RESET}` : `${FG.dim} ${filter.toUpperCase()} ${RESET}`,
    ).join("  ");
    const ageScope = this.showAllAges
      ? `${FG.warning}${BOLD}[ALL TIME]${RESET}`
      : `${FG.dim}[7 DAYS]${RESET}`;
    const lines = [title, ` ${tabs}    ${ageScope}`,  `${FG.dim}${"─".repeat(safeWidth)}${RESET}`];

    const body: string[] = [];
    let selectedBodyLine = 0;
    for (const group of this.groups) {
      if (this.selectedKey === `s:${group.key}`) selectedBodyLine = body.length;
      body.push(...this.renderSession(group, this.selectedKey === `s:${group.key}`, safeWidth));
      if (this.expanded.has(group.key)) {
        for (const item of [...this.visibleHistory(group)].reverse()) {
          if (this.selectedKey === `n:${item.id}`) selectedBodyLine = body.length;
          body.push(...this.renderNotification(item, this.selectedKey === `n:${item.id}`, safeWidth));
        }
      }
      body.push("");
    }
    if (body.length === 0) body.push(` ${FG.dim}No notifications in this view.${RESET}`);

    const footerRows = 3;
    const bodyHeight = Math.max(1, terminal.rows - lines.length - footerRows);
    const start = Math.max(0, Math.min(selectedBodyLine - Math.floor(bodyHeight / 2), Math.max(0, body.length - bodyHeight)));
    lines.push(...body.slice(start, start + bodyHeight));
    while (lines.length < terminal.rows - footerRows) lines.push("");
    lines.push(`${FG.dim}${"─".repeat(safeWidth)}${RESET}`);
    lines.push(this.searchMode
      ? ` ${FG.accent}/${RESET}${this.query}`
      : ` ${FG.dim}j/k move  enter expand/open  o open  r read  R session  tab filter  a all-time  / search  q close${RESET}`);
    lines.push(` ${FG.dim}Expanding does not mark notifications read.${RESET}`);
    return lines.map((line) => truncateToWidth(line, safeWidth, ""));
  }
}

let app: NotificationInbox;
let closing = false;
function close(): void {
  if (closing) return;
  closing = true;
  app.dispose();
  tui.stop();
  process.exit(0);
}

app = new NotificationInbox(close);
tui.addChild(app);
tui.setFocus(app);
process.on("SIGINT", close);
process.on("SIGTERM", close);
tui.start();
