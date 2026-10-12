import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, mkdir, writeFile, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { importExtension, mockApi, renderContext, theme, piSdk, tuiSdk } from "./pi-test-helpers.mjs";

const home = await mkdtemp(join(tmpdir(), "pi-regression-home-"));
const previousHome = process.env.HOME;
process.env.HOME = home;
const workflow = await importExtension("lib/workflow-mode.ts");
const supervisor = await importExtension("supervisor-worker.ts");
process.env.HOME = previousHome;
const previousLedger = process.env.PI_CACHE_HEALTH_LEDGER;
process.env.PI_CACHE_HEALTH_LEDGER = join(home, "ledger.jsonl");
const cacheHealth = await importExtension("cache-health.ts");
if (previousLedger === undefined) delete process.env.PI_CACHE_HEALTH_LEDGER;
else process.env.PI_CACHE_HEALTH_LEDGER = previousLedger;
after(() => rm(home, { recursive: true, force: true }));

const usage = (n) => ({ input: n, output: n, cacheRead: 0, cacheWrite: 0, totalTokens: n * 2,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: n } });
const assistant = (n, extra = {}) => ({ role: "assistant", provider: "test", model: "fixture", api: "test", timestamp: 1000,
  content: [{ type: "text", text: "## Status\n- completed" }], usage: usage(n), stopReason: "stop", ...extra });
const run = (n, extra = {}) => ({ messages: [assistant(n)], streamedText: "", stderr: "", exitCode: 0, toolExecutions: [], ...extra });
const context = (key = "regressions") => ({ cwd: home, mode: "rpc", hasUI: true, model: { provider: "test", id: "fixture" }, scopedModels: [],
  ui: { theme: theme(), notify() {}, setStatus() {}, setWidget() {} }, getContextUsage: () => undefined,
  sessionManager: { getSessionFile: () => key, getSessionId: () => key, getBranch: () => [], buildSessionProjection: () => ({ messages: [] }) },
  modelRegistry: { getAvailable: () => [{ provider: "test", id: "fixture" }] } });

test("context extraction supports all public string/block message shapes", async () => {
  const { textFromMessage } = await importExtension("lib/session-messages.ts");
  for (const role of ["user", "system", "assistant"]) {
    assert.equal(textFromMessage({ role, content: [{ type: "text", text: " hello " }] }), "hello");
  }
  for (const role of ["user", "system"]) assert.equal(textFromMessage({ role, content: " hello " }), "hello");
  assert.equal(textFromMessage({ role: "assistant", content: [{ type: "thinking", thinking: "private" }] }), "");
});

test("native bash final cleanup and component slots survive repeated expansion toggles", async (t) => {
  const sdk = await piSdk(); sdk.initTheme("dark", false);
  const { compactRenderers } = await importExtension("lib/compact-tool-renderers.ts");
  const renderer = compactRenderers("bash", sdk.createBashToolDefinition(home));
  t.mock.timers.enable({ apis: ["setInterval", "Date"], now: 1000 });
  let invalidations = 0;
  const ctx = renderContext({ args: { command: "fixture only; never executed" }, expanded: true, isPartial: true,
    invalidate: () => invalidations++ });
  const call = renderer.renderCall(ctx.args, theme(), ctx);
  const result = { content: [{ type: "text", text: "fixture" }], details: {} };
  const expanded = renderer.renderResult(result, { expanded: true, isPartial: true }, theme(), ctx);
  t.mock.timers.tick(1000); assert.equal(invalidations, 1);
  const hidden = renderer.renderResult(result, { expanded: false, isPartial: false }, theme(),
    { ...ctx, expanded: false, isPartial: false, durationMs: 0, lastComponent: expanded });
  t.mock.timers.tick(10000); assert.equal(invalidations, 1, "final native callback stopped its interval");
  assert.equal(renderer.renderResult(result, { expanded: true, isPartial: false }, theme(),
    { ...ctx, isPartial: false, lastComponent: hidden }), expanded);
  renderer.renderCall(ctx.args, theme(), { ...ctx, expanded: false, lastComponent: call });
  assert.equal(renderer.renderCall(ctx.args, theme(), ctx), call);
});

test("secret checks use metadata/canonical paths, guards and undo never snapshot dotenv paths", async () => {
  const { isSecretPath, safePaths } = await importExtension("lib/secret-paths.ts");
  // A directory and symlink are enough to verify canonical-name protection; no dotenv file is opened.
  await mkdir(join(home, ".env"));
  await symlink(join(home, ".env"), join(home, "alias"));
  assert.equal(await isSecretPath("alias", home), true);
  assert.deepEqual(await safePaths([".env", ".env.local", "alias", ".env.example", "source.ts"], home), [".env.example", "source.ts"]);
  const guard = mockApi(); (await importExtension("block-dotenv-read.ts")).default(guard);
  const ctx = context();
  for (const path of [".env", "alias"]) {
    assert.equal((await guard.emit("tool_call", { toolName: "read", input: { path } }, ctx)).block, true);
  }
  const undo = mockApi(); (await importExtension("undo-last-turn.ts")).default(undo);
  await undo.emit("session_start", {}, ctx);
  await undo.emit("tool_call", { toolName: "write", input: { path: ".env" } }, ctx);
  await undo.emit("tool_call", { toolName: "edit", input: { path: "alias" } }, ctx);
  await undo.emit("agent_settled", { aborted: false }, ctx);
  assert.deepEqual(undo.entries.at(-1).data, { lastBatch: undefined });
  await undo.emit("session_shutdown", {}, ctx);
});

test("review Git pathspecs exclude staged dotenv data and support string session messages", async () => {
  const directory = await mkdtemp(join(home, "review-paths-"));
  execFileSync("git", ["init", "-q", directory]);
  await writeFile(join(directory, "change.ts"), "visible change\n");
  // Seed the index from stdin, not a dotenv file. The reviewer must never request its patch.
  const marker = "redacted-index-fixture-not-for-review";
  const hash = execFileSync("git", ["hash-object", "-w", "--stdin"], { cwd: directory, input: marker, encoding: "utf8" }).trim();
  execFileSync("git", ["update-index", "--add", "--cacheinfo", `100644,${hash},.env`], { cwd: directory });
  const api = mockApi(); (await importExtension("reviewer-subagent.ts")).default(api);
  const ctx = context(); ctx.cwd = directory;
  ctx.sessionManager.buildSessionProjection = () => ({ messages: [{ role: "user", content: "Review intent", timestamp: 1 }] });
  let prompt;
  ctx.modelRegistry.streamSimple = (_model, request) => {
    prompt = request;
    return { async *[Symbol.asyncIterator]() {}, result: async () => assistant(1) };
  };
  const result = await api.tools.get("review_changes").execute("review-paths", {}, undefined, undefined, ctx);
  assert.equal(result.isError, false);
  assert.match(prompt.messages[0].content[0].text, /visible change/);
  assert.match(prompt.messages[0].content[0].text, /Review intent/);
  assert.doesNotMatch(prompt.messages[0].content[0].text, new RegExp(marker));
  await api.emit("session_shutdown", {}, ctx);
});

for (const event of ["session_tree", "session_shutdown", "session_start"]) {
  test(`review command cancels and rejects stale publication after ${event}`, async () => {
    const directory = await mkdtemp(join(home, "review-cancel-"));
    execFileSync("git", ["init", "-q", directory]);
    await writeFile(join(directory, "change.ts"), "fixture\n");
    const api = mockApi(); (await importExtension("reviewer-subagent.ts")).default(api);
    const ctx = context(); ctx.cwd = directory;
    let start, finish, signal;
    const started = new Promise((resolve) => { start = resolve; });
    const final = new Promise((resolve) => { finish = resolve; });
    ctx.modelRegistry.streamSimple = (_model, _request, options) => {
      signal = options.signal; start();
      return { async *[Symbol.asyncIterator]() { await final; }, result: () => final };
    };
    const pending = api.commands.get("review").handler("", ctx);
    await started; await api.emit(event, {}, ctx);
    assert.equal(signal.aborted, true);
    finish(assistant(1, { stopReason: "aborted" }));
    await pending;
    assert.equal(api.messages.length, 0);
    await api.emit("session_shutdown", {}, ctx);
  });
}

test("no-text retries charge every attempt, including exhausted and cancelled attempts", async () => {
  const { runSubagentWithNoTextRetry, SubagentFailure } = supervisor;
  let attempts = 0;
  const result = await runSubagentWithNoTextRetry("Worker", async () => ++attempts === 1
    ? run(1, { messages: [assistant(1, { content: [], stopReason: "error" })] }) : run(2));
  assert.equal(result.attempts, 2); assert.equal(result.metrics.usage.cost.total, 3);
  await assert.rejects(runSubagentWithNoTextRetry("Scout", async () => run(2, { messages: [assistant(2, { content: [] })] })),
    (error) => error instanceof SubagentFailure && error.metrics.usage.cost.total === 4);
  attempts = 0;
  await assert.rejects(runSubagentWithNoTextRetry("Worker", async () => {
    attempts++; return run(1, { stopReason: "aborted", messages: [assistant(1, { content: [], stopReason: "aborted" })] });
  }), (error) => error.metrics.usage.cost.total === 1);
  assert.equal(attempts, 1);
});

test("live cache health preserves same-timestamp requests, suppressing only stable IDs/repeated objects", async () => {
  const api = mockApi(); cacheHealth.default(api);
  const ctx = context("cache-regression"); let notice;
  ctx.ui.notify = (text) => { notice = text; };
  await api.emit("session_start", {}, ctx);
  const first = assistant(1, { provider: "github-copilot" });
  const second = structuredClone(first); second.content[0].text = "distinct request";
  const identified = assistant(1, { provider: "github-copilot", responseId: "stable" });
  for (const message of [first, second, first, identified, structuredClone(identified)]) await api.emit("message_end", { message }, ctx);
  await api.commands.get("cache-health").handler("", ctx); assert.match(notice, /Responses: 3/);
  ctx.sessionManager.getBranch = () => [first, second, identified].map((message) => ({ type: "message", message }));
  await api.emit("session_tree", {}, ctx);
  await api.commands.get("cache-health").handler("", ctx); assert.match(notice, /Responses: 3/);
  await api.emit("session_shutdown", {}, ctx);
});

test("pending metrics use request IDs across overlapping batches, duplicates and equal timestamps", async () => {
  const { PendingMetrics } = await importExtension("lib/pending-metrics.ts");
  const pending = new PendingMetrics();
  const a = { id: "a", generatedAt: 1000, subagentMetrics: { usage: usage(1), cost: { amount: 1 } } };
  const b = { id: "b", generatedAt: 1000, subagentMetrics: { usage: usage(2), cost: { amount: 2 } } };
  for (const event of [a, b, structuredClone(a)]) pending.add(event);
  assert.equal(pending.unpersisted([]).length, 2);
  assert.deepEqual(pending.unpersisted([{ type: "message", message: { role: "toolResult", toolCallId: "a", details: a } }]), [b]);
  assert.deepEqual(pending.unpersisted([{ type: "custom", customType: "subagent-usage", data: b }]), []);
  pending.add(a); pending.clear(); assert.deepEqual(pending.unpersisted([]), []);
});

test("metrics layouts fit narrow widths and recolor without metric updates", async () => {
  const api = mockApi(); (await importExtension("token-throughput.ts")).default(api);
  const ctx = context(); ctx.mode = "tui"; let component;
  ctx.ui.custom = async (factory) => { component = factory({}, theme(), {}, () => {}); };
  await api.commands.get("metrics").handler("", ctx);
  const { visibleWidth } = await tuiSdk();
  for (const width of [0, 1, 2, 12, 20, 80]) for (const line of component.render(width)) assert.ok(visibleWidth(line) <= width);
  ctx.ui.theme = theme("new:"); component.invalidate();
  assert.match(component.render(80).join("\n"), /new:/);
  await api.emit("session_shutdown", {}, ctx);
});

test("thinking max restores, and diagnostic delegation entry points are absent", async () => {
  await workflow.writeWorkflowMode("guided");
  const api = mockApi(); supervisor.default(api);
  const ctx = context(); const notices = [];
  ctx.ui.notify = (text) => notices.push(text);
  ctx.sessionManager.getBranch = () => [{ type: "custom", customType: "supervisor-worker-state",
    data: { override: { provider: "test", id: "fixture" }, thinkingLevel: "max", workflowMode: "three-tier" } }];
  await api.emit("session_start", {}, ctx);
  await api.commands.get("worker-model").handler("", ctx);
  assert.match(notices.at(-1), /fixture:max/);
  assert.equal(api.commands.has("noop-subagent"), false);
  // Direct execution also enforces current policy, rather than relying only on tool_call hooks.
  await assert.rejects(api.tools.get("delegate_worker").execute("forbidden", {}, undefined, undefined, ctx), /disabled/);
  await api.emit("session_shutdown", {}, ctx);
});

test("subprocess auth preserves null headers, endpoint and environment, but never derives OAuth forwarding", async () => {
  const { resolveSubagentAuth } = await importExtension("lib/subagent-auth.ts");
  const ctx = context();
  const auth = { ok: true, apiKey: "offline-placeholder", headers: { remove: null, keep: "fixture" }, baseUrl: "https://fixture.invalid", env: { FIXTURE: "1" } };
  ctx.modelRegistry.getApiKeyAndHeaders = async () => auth;
  ctx.modelRegistry.isUsingOAuth = () => false;
  assert.deepEqual(await resolveSubagentAuth(ctx, ctx.model), { apiKey: auth.apiKey, headers: auth.headers, baseUrl: auth.baseUrl, env: auth.env });
  ctx.modelRegistry.isUsingOAuth = () => true;
  assert.deepEqual(await resolveSubagentAuth(ctx, ctx.model), {});
});

test("custom cost reconciles stable pending IDs without dropping concurrent equal-time requests", async () => {
  const api = mockApi(); (await importExtension("copilot-cost.ts")).default(api);
  const registry = await importExtension("statusline/registry.ts");
  const ctx = context("cost-regression"); let branch = [];
  ctx.sessionManager.getBranch = () => branch;
  const label = () => registry.renderStatuslineContent(registry.listStatuslineItems("cost-regression").find(item => item.id === "copilot-cost").content, theme());
  const a = { id: "a", generatedAt: 1000, sessionKey: "cost-regression", subagentMetrics: { cost: { amount: 1 } } };
  const b = { id: "b", generatedAt: 1000, sessionKey: "cost-regression", subagentMetrics: { cost: { amount: 2 } } };
  await api.emit("session_start", {}, ctx);
  for (const event of [a, b, structuredClone(a)]) api.events.emit("subagent:metrics", event);
  assert.match(label(), /Sub \$3\.000/);
  branch = [{ type: "custom_message", details: a }];
  await api.emit("message_end", { message: { role: "custom", details: a } }, ctx);
  assert.match(label(), /Sub \$3\.000/);
  branch.push({ type: "message", message: { role: "toolResult", toolCallId: "b", details: b } });
  await api.emit("message_end", { message: branch[1].message }, ctx);
  assert.match(label(), /Sub \$3\.000/);
  branch = [];
  await api.emit("session_tree", {}, ctx);
  assert.match(label(), /Sub \$0\.0000/);
  await api.emit("session_shutdown", {}, ctx);
});

test("terminal limits/deferred/missing completion cannot masquerade as successful delegation", () => {
  for (const stopReason of ["error", "length", "deferred", "toolUse", undefined]) {
    assert.equal(supervisor.classifySubagentOutcome({ exitCode: 0, stopReason }), "failed");
  }
  assert.equal(supervisor.classifySubagentOutcome({ exitCode: 0, stopReason: "aborted" }), "aborted");
  assert.equal(supervisor.classifySubagentOutcome({ exitCode: 0, stopReason: "stop" }), "completed");
});
