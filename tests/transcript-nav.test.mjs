import assert from "node:assert/strict";
import { test } from "node:test";
import { importExtension, mockApi, theme, tuiSdk } from "./pi-test-helpers.mjs";

const { transcriptNodes } = await importExtension("lib/transcript-nodes.ts");
const { TranscriptOverlay } = await importExtension("lib/transcript-overlay.ts");
const { visibleWidth } = await tuiSdk();
const entry = (id, message) => ({ type: "message", id, parentId: null, timestamp: "now", message });
const assistant = (content) => ({ role: "assistant", content });

function fixture() {
  return [
    entry("system", { role: "system", content: "hidden system prompt" }),
    { type: "custom", id: "state", data: "hidden state" },
    { type: "custom_message", id: "hidden", display: false, content: "hidden custom", customType: "x" },
    entry("user", { role: "user", content: [{ type: "text", text: "hello\u001b[31m world\u001b[0m" }, { type: "image", data: "private-base64", mimeType: "image/png" }] }),
    entry("assistant", assistant([{ type: "thinking", thinking: "consider options" }, { type: "text", text: "reading files" },
      { type: "toolCall", id: "read1", name: "read", arguments: { path: "one.py" } },
      { type: "toolCall", id: "edit1", name: "edit", arguments: { path: "one.py" } }])),
    entry("read-result", { role: "toolResult", toolCallId: "read1", toolName: "read", content: [{ type: "text", text: "file contents" }], isError: false }),
    entry("edit-result", { role: "toolResult", toolCallId: "edit1", toolName: "edit", content: [{ type: "text", text: "failed output" }], details: { diff: "+ changed" }, isError: true }),
    entry("orphan", { role: "toolResult", toolCallId: "old", toolName: "bash", content: [{ type: "text", text: "orphan result" }], isError: false }),
    { type: "compaction", id: "compact", summary: "earlier work" },
    { type: "branch_summary", id: "branch", summary: "branch work" },
    entry("bang", { role: "bashExecution", command: "echo hi", output: "hi", exitCode: 0 }),
    entry("final", assistant([{ type: "text", text: "finished" }])),
  ];
}

test("snapshot pairs calls/results, includes thinking/diffs/images and excludes hidden state", () => {
  const entries = fixture();
  const before = structuredClone(entries);
  const nodes = transcriptNodes(entries);
  assert.deepEqual(entries, before);
  assert.equal(nodes.length, 10);
  assert.equal(nodes.filter((node) => node.title.startsWith("read ")).length, 1);
  assert.match(nodes.find((node) => node.title === "read done").body, /one.py[\s\S]*file contents/);
  const edit = nodes.find((node) => node.title.startsWith("edit"));
  assert.equal(edit.error, true);
  assert.match(edit.body, /failed output[\s\S]*Diff:\n\+ changed/);
  assert.match(nodes[0].body, /hello world\n\[image: image\/png\]/);
  assert.doesNotMatch(JSON.stringify(nodes), /hidden|private-base64|\u001b/);
  assert.match(nodes.find((node) => node.id === "orphan").body, /orphan result/);
});

test("bounded previews strip terminal control sequences and preserve error-only assistant messages", () => {
  const nodes = transcriptNodes([entry("a", { ...assistant([{ type: "text", text: "x".repeat(100_001) }]), errorMessage: "provider failed" })]);
  assert.match(nodes[0].body, /preview truncated/);
  assert.equal(nodes[1].error, true);
});

function viewer(nodes = Array.from({ length: 30 }, (_, i) => ({ id: `n${i}`, title: `node ${i}`, body: `body ${i}\n第二行 😀` }))) {
  let closed = 0, redraws = 0, prefix = "";
  let current = nodes;
  const overlay = new TranscriptOverlay(nodes, () => theme(prefix), () => 12, () => redraws++, () => closed++, () => current);
  const lines = (width = 70) => overlay.render(width).map((line) => line.trimEnd());
  const text = () => lines().join("\n");
  const key = (data) => { overlay.handleInput(data); return text(); };
  return { overlay, lines, text, key, closed: () => closed, redraws: () => redraws,
    refresh: (next) => { current = next; }, setTheme: (value) => { prefix = value; } };
}

test("Vim node navigation and individual folds are local and selection stays visible", () => {
  const v = viewer();
  assert.match(v.text(), /› ▸ node 29/);
  assert.match(v.key("k"), /› ▸ node 28/);
  v.key("g");
  assert.match(v.key("g"), /› ▸ node 0/);
  assert.match(v.key("j"), /› ▸ node 1/);
  assert.match(v.key("l"), /› ▾ node 1\n\s+body 1/);
  assert.match(v.key("h"), /› ▸ node 1/);
  assert.doesNotMatch(v.key("\r"), /› ▸ node 1/);
  v.key("z");
  assert.match(v.key("a"), /› ▸ node 1/);
  assert.match(v.key("G"), /› ▸ node 29/);
  v.key("\x1b");
  assert.equal(v.closed(), 1);
  assert.ok(v.redraws() > 0);
  const i = viewer(); i.key("i"); assert.equal(i.closed(), 1);
});

test("half-page keys scroll expanded contents rather than snapping to the header", () => {
  const v = viewer([{ id: "long", title: "long node", body: Array.from({ length: 60 }, (_, i) => `line ${i}`).join("\n") }]);
  v.key("l");
  assert.match(v.text(), /line 0/);
  const page = v.key("\x04");
  assert.doesNotMatch(page, /› ▾ long node/);
  assert.match(page, /line 3/);
  assert.match(v.key("\x15"), /› ▾ long node/);
});

test("search wraps, opens matches, supports n/N and cancels without closing", () => {
  const v = viewer([{ id: "a", title: "first", body: "needle" }, { id: "b", title: "second", body: "other" }, { id: "c", title: "third", body: "needle" }]);
  v.text(); v.key("/");
  for (const ch of "needle") v.key(ch);
  assert.match(v.key("\r"), /› ▾ third/);
  assert.match(v.key("n"), /› ▾ first/);
  assert.match(v.key("N"), /› ▾ third/);
  v.key("/"); v.key("\x1b");
  assert.equal(v.closed(), 0);
});

test("refresh preserves node selection/folds, handles empty branches, resize and themes", () => {
  const v = viewer([{ id: "a", title: "日本語 😀", body: "你好 😀 text" }]);
  v.key("l");
  v.refresh([{ id: "a", title: "updated", body: "new body" }, { id: "b", title: "new", body: "more" }]);
  assert.match(v.key("r"), /› ▾ updated[\s\S]*new body/);
  for (const width of [1, 4, 10, 25]) {
    v.overlay.invalidate();
    assert.ok(v.overlay.render(width).every((line) => visibleWidth(line) <= width));
  }
  v.setTheme("THEME:"); v.overlay.invalidate();
  assert.match(v.text(), /THEME:/);
  v.refresh([]); assert.match(v.key("r"), /No recorded messages/);
  for (const key of ["j", "k", "G", "l", "\x04", "n"]) v.key(key);
  assert.match(v.text(), /0\/0/);
});

test("extension opens only through supported UI, preserves draft and closes on branch/session changes", async () => {
  const api = mockApi();
  const shortcuts = new Map();
  api.registerShortcut = (name, value) => shortcuts.set(name, value);
  (await importExtension("transcript-nav.ts")).default(api);
  assert.ok(shortcuts.has("alt+t"));
  assert.equal(api.tools.size, 0);
  let overlay, resolve, openCount = 0;
  const original = fixture(), before = structuredClone(original);
  const ctx = {
    hasUI: true, mode: "tui", sessionManager: { getBranch: () => original },
    ui: { theme: theme(), getEditorText: () => "unfinished draft", setEditorText: () => assert.fail("must not touch draft"),
      custom: (factory, options) => {
        openCount++;
        assert.equal(options.overlay, true);
        return new Promise((done) => {
          resolve = done;
          overlay = factory({ terminal: { rows: 20 }, requestRender() {} }, theme(), {}, done);
        });
      },
    },
  };
  const pending = shortcuts.get("alt+t").handler(ctx);
  assert.ok(overlay.render(70).length);
  await shortcuts.get("alt+t").handler(ctx);
  assert.equal(openCount, 1);
  await api.emit("session_tree"); await pending;
  assert.deepEqual(original, before);
  const second = api.commands.get("transcript").handler("", ctx);
  await api.emit("session_shutdown"); await second;
  assert.equal(openCount, 2);
  await shortcuts.get("alt+t").handler({ ...ctx, mode: "print", hasUI: false });
  assert.equal(openCount, 2);
  resolve();
});
