import assert from "node:assert/strict";
import { mkdtemp, rm, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import childProcess from "node:child_process";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { importExtension, mockApi, theme } from "./pi-test-helpers.mjs";

const directory = await mkdtemp(join(tmpdir(), "pi-command-ownership-"));
after(() => rm(directory, { recursive: true, force: true }));
const context = () => ({ mode: "tui", hasUI: true, cwd: directory, model: { provider: "test", id: "fixture" },
  thinkingLevel: "off", waitForIdle: async () => {}, isIdle: () => true,
  ui: { theme: theme(), notify() {}, setWidget() {} },
  sessionManager: { getSessionFile: () => "command-session", getBranch: () => [], buildSessionProjection: () => ({ messages: [] }) } });
const response = { role: "assistant", provider: "test", model: "fixture", api: "test", timestamp: 1, content: [], stopReason: "aborted",
  usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };

for (const event of ["session_tree", "session_shutdown"]) {
  test(`/btw closes and cancels an idle command-owned stream on ${event}`, async () => {
    const api = mockApi(); (await importExtension("btw.ts")).default(api);
    const ctx = context(); let signal, closeCount = 0, start;
    const started = new Promise(resolve => { start = resolve; });
    ctx.ui.custom = factory => new Promise(resolve => factory({ terminal: { rows: 24 }, requestRender() {} }, theme(), {}, () => { closeCount++; resolve(); }));
    ctx.modelRegistry = { streamSimple(_model, request, options) {
      signal = options.signal; assert.equal(options.reasoning, undefined); assert.deepEqual(request.tools, []);
      const final = new Promise(resolve => signal.addEventListener("abort", () => resolve(response), { once: true }));
      start(); return { async *[Symbol.asyncIterator]() { await final; }, result: () => final };
    } };
    const pending = api.commands.get("btw").handler("fixture question", ctx);
    await started; await api.emit(event, {}, ctx); await pending;
    assert.equal(signal.aborted, true); assert.equal(closeCount, 1); assert.equal(api.messages.length, 0);
    await api.emit("session_shutdown", {}, ctx);
  });

  test(`PR fetching aborts and does not publish or write bundles after ${event}`, async () => {
    const api = mockApi(); (await importExtension("pr-comment-address.ts")).default(api);
    const ctx = context(); let signal, start; const notices = [];
    ctx.ui.notify = text => notices.push(text);
    const started = new Promise(resolve => { start = resolve; });
    api.exec = (_command, _args, options) => {
      signal = options.signal; start();
      return new Promise(resolve => signal.addEventListener("abort", () => resolve({ code: 1, stdout: "", stderr: "fixture cancelled", killed: true }), { once: true }));
    };
    const pending = api.commands.get("pr-comment-address").handler("", ctx);
    await started; const noticeCount = notices.length; await api.emit(event, {}, ctx); await pending;
    assert.equal(signal.aborted, true); assert.equal(notices.length, noticeCount);
    assert.equal(api.messages.length, 0); assert.equal((await readdir(directory)).includes(".pi"), false);
    await api.emit("session_shutdown", {}, ctx);
  });
}

test("brief rejects late editor replies without writing a replacement branch's composer", async () => {
  const api = mockApi(); (await importExtension("brief.ts")).default(api);
  const ctx = context(); let reply, start; const edits = [];
  const started = new Promise(resolve => { start = resolve; });
  ctx.ui.editor = () => { start(); return new Promise(resolve => { reply = resolve; }); };
  ctx.ui.setEditorText = text => edits.push(text);
  const pending = api.commands.get("brief").handler("", ctx);
  await started; await api.emit("session_tree", {}, ctx);
  await pending;
  reply("Objective:\\nlate old-branch reply");
  await Promise.resolve();
  assert.equal(edits.length, 0);
  await api.emit("session_shutdown", {}, ctx);
});

test("copy selection rejects stale replies before any clipboard side effect", async (t) => {
  const api = mockApi(); (await importExtension("copy-smart.ts")).default(api);
  let attempts = 0;
  const forbidden = () => { attempts++; throw new Error("Clipboard backends are forbidden in this test"); };
  t.mock.method(childProcess, "spawn", forbidden);
  t.mock.method(childProcess, "spawnSync", forbidden);
  const originalOpen = fs.openSync;
  t.mock.method(fs, "openSync", (path, ...args) => path === "/dev/tty" ? forbidden() : originalOpen(path, ...args));
  syncBuiltinESMExports();
  try {
    const ctx = context(); ctx.mode = "rpc";
    const fence = String.fromCharCode(96).repeat(3);
    ctx.sessionManager.getBranch = () => [{ type: "message", message: { role: "assistant", content: [
      { type: "text", text: [fence + "js", "one", fence, fence + "ts", "two", fence].join("\n") },
    ] } }];
    let reply, start, choice;
    const started = new Promise(resolve => { start = resolve; });
    ctx.ui.select = (_title, options) => { choice = options[0]; start(); return new Promise(resolve => { reply = resolve; }); };
    const pending = api.commands.get("copy-smart").handler("", ctx);
    await started; await api.emit("session_tree", {}, ctx); reply(choice); await pending;
    assert.equal(attempts, 0);
    await api.emit("session_shutdown", {}, ctx);
  } finally {
    t.mock.restoreAll();
    syncBuiltinESMExports();
  }
});
