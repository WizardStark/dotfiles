import type { Theme } from "@earendil-works/pi-coding-agent";
import { Input, matchesKey, truncateToWidth, wrapTextWithAnsi, type Component, type Focusable } from "@earendil-works/pi-tui";
import type { TranscriptNode } from "./transcript-nodes.ts";

type Row = { node: number; header: boolean; text: string };

/** Local folds and selection only. No access to the main transcript's components. */
export class TranscriptOverlay implements Component, Focusable {
  focused = false;
  private nodes: TranscriptNode[];
  private selected: number;
  private expanded = new Set<string>();
  private offset = 0;
  private pageHeight = 10;
  private rows: Row[] = [];
  private starts: number[] = [];
  private cachedWidth = -1;
  private reveal = true;
  private prefix = "";
  private searching = false;
  private input = new Input();
  private query = "";
  private status = "";

  constructor(
    nodes: TranscriptNode[],
    private theme: () => Theme,
    private height: () => number,
    private redraw: () => void,
    private done: () => void,
    private refresh: () => TranscriptNode[],
  ) {
    this.nodes = nodes;
    this.selected = Math.max(0, nodes.length - 1);
  }

  invalidate(): void { this.cachedWidth = -1; this.input.invalidate(); }

  private move(index: number): void {
    this.selected = Math.max(0, Math.min(this.nodes.length - 1, index));
    this.reveal = true;
    this.status = "";
  }

  private fold(expand?: boolean): void {
    const node = this.nodes[this.selected];
    if (!node) return;
    const open = expand ?? !this.expanded.has(node.id);
    if (open) this.expanded.add(node.id);
    else this.expanded.delete(node.id);
    this.invalidate();
    this.reveal = true;
  }

  private scroll(direction: number): void {
    const next = Math.max(0, Math.min(Math.max(0, this.rows.length - this.pageHeight),
      this.offset + direction * Math.max(1, Math.floor(this.pageHeight / 2))));
    this.offset = next;
    // Keep selection in the viewport, including when paging inside a long expanded node.
    const visible = this.rows.slice(next, next + this.pageHeight);
    if (!visible.some((row) => row.node === this.selected) && visible.length) this.selected = visible[0].node;
    this.reveal = false;
  }

  private search(direction: number, includeCurrent = false): void {
    if (!this.query || !this.nodes.length) return;
    const query = this.query.toLocaleLowerCase();
    for (let step = includeCurrent ? 0 : 1; step <= this.nodes.length; step++) {
      const index = (this.selected + direction * step + this.nodes.length) % this.nodes.length;
      const node = this.nodes[index];
      if (`${node.title}\n${node.body}`.toLocaleLowerCase().includes(query)) {
        this.move(index);
        this.expanded.add(node.id);
        this.invalidate();
        this.status = `/${this.query}`;
        return;
      }
    }
    this.status = `No match: ${this.query}`;
  }

  handleInput(data: string): void {
    if (this.searching) {
      if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) this.searching = false;
      else if (matchesKey(data, "enter")) {
        this.query = this.input.getValue();
        this.searching = false;
        this.search(1, true);
      } else this.input.handleInput(data);
      this.redraw();
      return;
    }
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "i")) { this.done(); return; }
    const prefix = this.prefix;
    this.prefix = "";
    if (prefix === "g" && matchesKey(data, "g")) this.move(0);
    else if (prefix === "z" && matchesKey(data, "a")) this.fold();
    else if (matchesKey(data, "j") || matchesKey(data, "down")) this.move(this.selected + 1);
    else if (matchesKey(data, "k") || matchesKey(data, "up")) this.move(this.selected - 1);
    else if (matchesKey(data, "ctrl+u") || matchesKey(data, "pageUp")) this.scroll(-1);
    else if (matchesKey(data, "ctrl+d") || matchesKey(data, "pageDown")) this.scroll(1);
    else if (data === "G" || matchesKey(data, "shift+g")) this.move(this.nodes.length - 1);
    else if (matchesKey(data, "g")) this.prefix = "g";
    else if (matchesKey(data, "z")) this.prefix = "z";
    else if (matchesKey(data, "enter")) this.fold();
    else if (matchesKey(data, "h") || matchesKey(data, "left")) this.fold(false);
    else if (matchesKey(data, "l") || matchesKey(data, "right")) this.fold(true);
    else if (matchesKey(data, "/")) {
      this.searching = true;
      this.input.setValue(this.query);
    } else if (data === "N" || matchesKey(data, "shift+n")) this.search(-1);
    else if (matchesKey(data, "n")) this.search(1);
    else if (matchesKey(data, "r")) {
      const id = this.nodes[this.selected]?.id;
      this.nodes = this.refresh();
      const index = this.nodes.findIndex((node) => node.id === id);
      const ids = new Set(this.nodes.map((node) => node.id));
      this.expanded = new Set([...this.expanded].filter((nodeId) => ids.has(nodeId)));
      this.move(index < 0 ? this.nodes.length - 1 : index);
      this.invalidate();
      this.status = "Snapshot refreshed";
    }
    this.redraw();
  }

  render(width: number): string[] {
    const theme = this.theme();
    this.pageHeight = Math.max(1, this.height() - 3);
    if (width !== this.cachedWidth) {
      this.rows = [];
      this.starts = [];
      this.nodes.forEach((node, index) => {
        this.starts.push(this.rows.length);
        this.rows.push({ node: index, header: true, text: node.title });
        if (this.expanded.has(node.id)) {
          for (const line of node.body.split("\n")) {
            for (const wrapped of wrapTextWithAnsi(line, Math.max(1, width - 4))) {
              this.rows.push({ node: index, header: false, text: wrapped });
            }
          }
        }
      });
      this.cachedWidth = width;
    }
    if (this.reveal) {
      const start = this.starts[this.selected] ?? 0;
      if (start < this.offset) this.offset = start;
      else if (start >= this.offset + this.pageHeight) this.offset = start - this.pageHeight + 1;
      this.reveal = false;
    }
    this.offset = Math.max(0, Math.min(this.offset, Math.max(0, this.rows.length - this.pageHeight)));
    const fit = (text: string) => truncateToWidth(text, width, "…", true);
    const position = this.nodes.length ? `${this.selected + 1}/${this.nodes.length}` : "0/0";
    const lines = [fit(theme.fg("accent", `Transcript · read-only snapshot · ${position}`))];
    for (const row of this.rows.slice(this.offset, this.offset + this.pageHeight)) {
      const node = this.nodes[row.node];
      const selected = row.node === this.selected;
      if (row.header) {
        const label = `${selected ? "›" : " "} ${this.expanded.has(node.id) ? "▾" : "▸"} ${row.text}`;
        lines.push(fit(theme.fg(node.error ? "error" : selected ? "accent" : "muted", label)));
      } else lines.push(fit(theme.fg("toolOutput", `    ${row.text}`)));
    }
    if (!this.rows.length) lines.push(fit(theme.fg("dim", "No recorded messages in this branch.")));
    while (lines.length < this.pageHeight + 1) lines.push(fit(""));
    if (this.searching) {
      this.input.focused = this.focused;
      lines.push(fit("/ " + this.input.render(Math.max(1, width - 2))[0]));
    } else lines.push(fit(theme.fg("dim", this.status || "j/k nodes · C-u/d scroll · gg/G ends · Enter/za fold · h/l close/open")));
    lines.push(fit(theme.fg("dim", "/ search · n/N next/prev · r refresh · Esc/i composer (draft preserved)")));
    return lines;
  }
}
