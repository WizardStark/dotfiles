import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setImmediate } from "node:timers/promises";
import { test } from "node:test";
import { importExtension, mockApi, theme } from "./pi-test-helpers.mjs";
const registry = await importExtension("statusline/registry.ts");
const ctx = (key) => ({ mode: "tui", hasUI: true, isIdle: () => false, cwd: process.cwd(),
  ui: { theme: theme("old:"), notify() {}, setWidget() {}, setStatus() {} },
  scopedModels: [], model: { id: "model", provider: "test", contextWindow: 100000 }, thinkingLevel: "high",
  getContextUsage: () => ({ tokens: 1000, contextWindow: 100000 }),
  sessionManager: { getSessionFile: () => key, getBranch: () => [] } });
const content = (id, context, palette = theme()) => {
  const item = registry.listStatuslineItems(context.sessionManager.getSessionFile()).find((item) => item.id === id);
  return item && registry.renderStatuslineContent(item.content, palette);
};

async function flushNotification(path) {
  for (let i = 0; i < 100; i++) {
    await setImmediate();
    try { const text = await readFile(path, "utf8"); if (text.trim()) return text.trim().split("\n").map(JSON.parse); } catch {}
  }
  return [];
}

test("notification watchdog suspends for overlapping prompts, resumes on activity, suppresses abort completion, and cleans up", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "pi-notification-test-"));
  const path = join(directory, "notifications.jsonl");
  const previous = process.env.PI_NOTIFICATION_STORE;
  process.env.PI_NOTIFICATION_STORE = path;
  t.after(async () => { if (previous === undefined) delete process.env.PI_NOTIFICATION_STORE; else process.env.PI_NOTIFICATION_STORE = previous; await rm(directory, { recursive: true, force: true }); });
  const api = mockApi(); (await importExtension("pi-notifications.ts")).default(api);
  const context = ctx("notification-session");
  t.mock.timers.enable({ apis: ["setTimeout", "Date"], now: 1000 });
  await api.emit("session_start", {}, context);
  // A command dialog while idle must not start the watchdog.
  await api.emit("ui_prompt_start", {}, context);
  await api.emit("ui_prompt_end", {}, context);
  t.mock.timers.tick(600000);
  assert.deepEqual(await flushNotification(path), []);
  await api.emit("agent_start", {}, context);
  await api.emit("ui_prompt_start", {}, context);
  await api.emit("ui_prompt_start", {}, context);
  t.mock.timers.tick(600000);
  await api.emit("ui_prompt_end", {}, context);
  await api.emit("message_update", {}, context);
  t.mock.timers.tick(600000);
  assert.deepEqual(await flushNotification(path), []);
  await api.emit("ui_prompt_end", {}, context);
  t.mock.timers.tick(299999);
  assert.deepEqual(await flushNotification(path), []);
  await api.emit("tool_execution_update", {}, context);
  t.mock.timers.tick(299999);
  assert.deepEqual(await flushNotification(path), []);
  t.mock.timers.tick(1);
  assert.equal((await flushNotification(path))[0].kind, "stuck");
  await api.emit("agent_settled", { aborted: true }, context);
  assert.equal((await flushNotification(path)).length, 1);
  await api.emit("agent_start", {}, context);
  await api.emit("agent_settled", { aborted: false }, context);
  for (let i = 0; i < 100 && (await flushNotification(path)).length < 2; i++) await setImmediate();
  assert.deepEqual((await flushNotification(path)).map((record) => record.kind), ["stuck", "completed"]);
  await api.emit("agent_start", {}, context);
  await api.emit("session_shutdown", {}, context);
  t.mock.timers.tick(600000);
  assert.equal((await flushNotification(path)).length, 2);
});

test("turn timer distinguishes waiting/cancellation, survives retries, and does not install headless timers", async (t) => {
  const api = mockApi(); (await importExtension("turn-timer.ts")).default(api);
  const context = ctx("timer-session");
  t.mock.timers.enable({ apis: ["setInterval", "Date"], now: 1000 });
  await api.emit("session_start", {}, context);
  await api.emit("agent_start", {}, context);
  t.mock.timers.tick(500);
  await api.emit("ui_prompt_start", {}, context);
  await api.emit("ui_prompt_start", {}, context);
  assert.match(content("turn-timer", context), /Awaiting input/);
  await api.emit("ui_prompt_end", {}, context);
  assert.match(content("turn-timer", context), /Awaiting input/);
  await api.emit("ui_prompt_end", {}, context);
  assert.match(content("turn-timer", context), /Running/);
  await api.emit("agent_end", {}, context);
  await api.emit("agent_start", {}, context);
  t.mock.timers.tick(500);
  await api.emit("agent_settled", { aborted: true }, context);
  assert.match(content("turn-timer", context), /Interrupted 1.0s/);
  assert.doesNotMatch(content("turn-timer", context), /✓/);
  const saved = content("turn-timer", context);
  t.mock.timers.tick(1000);
  assert.equal(content("turn-timer", context), saved);
  await api.emit("agent_start", {}, context);
  await api.emit("agent_settled", { aborted: false }, context);
  assert.match(content("turn-timer", context), /✓.*Last turn/);
  await api.emit("session_shutdown", {}, context);
  assert.equal(content("turn-timer", context), undefined);
  context.hasUI = false;
  await api.emit("session_start", {}, context);
  await api.emit("agent_start", {}, context);
  t.mock.timers.tick(600000);
  assert.equal(content("turn-timer", context), undefined);
  await api.emit("session_shutdown", {}, context);
});

test("all metric registry producers apply the current theme without new metric events", async () => {
  for (const file of ["copilot-cost.ts", "cache-health.ts", "token-throughput.ts", "turn-timer.ts"]) {
    const api = mockApi(); (await importExtension(file)).default(api);
    const context = ctx(`theme-${file}`);
    await api.emit("session_start", {}, context);
    const items = registry.listStatuslineItems(context.sessionManager.getSessionFile());
    assert.ok(items.length > 0, file);
    for (const item of items) {
      for (const field of ["content", "compactContent"]) {
        if (!item[field]) continue;
        assert.equal(typeof item[field], "function", `${file}:${field}`);
        const before = registry.renderStatuslineContent(item[field], theme("old:"));
        const after = registry.renderStatuslineContent(item[field], theme("new:"));
        assert.notEqual(before, after, file);
        assert.doesNotMatch(after, /old:/);
        assert.match(after, /new:/);
      }
    }
    await api.emit("session_shutdown", {}, context);
  }
});

test("registry retains session isolation, ordering and plain-string compatibility", () => {
  const item = registry.createStatuslineItem({ id: "theme-test", side: "left", order: 2 });
  item.set({ content: (theme) => theme.fg("success", "value"), compactContent: "short" }, "a");
  item.set({ content: "other" }, "b");
  const a = registry.listStatuslineItems("a")[0];
  assert.equal(registry.renderStatuslineContent(a.content, theme("new:")), "new:value");
  assert.equal(registry.renderStatuslineContent(a.compactContent, theme()), "short");
  assert.equal(registry.listStatuslineItems("b")[0].content, "other");
  item.clear("a"); item.clear("b");
});

test("footer and builtin model/reasoning segments recolor on invalidation without new model events", async () => {
  const api = mockApi(); (await importExtension("statusline/index.ts")).default(api);
  const context = ctx("footer-theme-session");
  let factory;
  context.ui.getEditorComponent = () => undefined;
  context.ui.setEditorComponent = () => {};
  context.ui.setFooter = (value) => { factory = value; };
  context.ui.theme.getBgAnsi = () => "";
  await api.emit("session_start", {}, context);
  const footer = factory({ requestRender() {} }, context.ui.theme, { onBranchChange: () => () => {}, getGitBranch: () => "test-branch" });
  const before = footer.render(300).join("\n");
  context.ui.theme = { ...theme("new:"), getBgAnsi: () => "" };
  footer.invalidate();
  const after = footer.render(300).join("\n");
  assert.match(before, /old:/);
  assert.match(after, /new:.*test\/model/);
  assert.doesNotMatch(after, /old:/);
  footer.dispose();
  await api.emit("session_shutdown", {}, context);
});
