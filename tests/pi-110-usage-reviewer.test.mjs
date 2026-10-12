import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { importExtension, mockApi, theme } from "./pi-test-helpers.mjs";
const { buildSubagentMetrics } = await importExtension("lib/subagent-runtime.ts");
const { sumUsages } = await importExtension("lib/usage.ts");
const { runReviewerRequest } = await importExtension("lib/reviewer-request.ts");
const usage = (n) => ({ input: n, output: n, cacheRead: n, cacheWrite: n, totalTokens: n * 4,
  reasoning: n / 2, cacheWrite1h: n / 2, cost: { input: n, output: n, cacheRead: n, cacheWrite: n, total: n * 4 } });
const assistant = (n, extra = {}) => ({ role: "assistant", provider: "test", model: "model", api: "test",
  timestamp: 1000, stopReason: "stop", content: [{ type: "text", text: "report" }], usage: usage(n), ...extra });
const run = (messages, extra = {}) => ({ messages, streamedText: "", stderr: "", exitCode: 0, ...extra });

test("subagent usage aggregates all requests and deduplicates repeated final envelopes", () => {
  const a = assistant(1), b = assistant(2, { stopReason: "error" });
  const metrics = buildSubagentMetrics(run([a, b], { turnEndMessage: structuredClone(b), agentEndMessage: structuredClone(b) }));
  assert.deepEqual(metrics.usage, usage(3));
  assert.equal(metrics.cost.amount, 12);
  assert.equal(metrics.throughput.outputTokens, 3);
  // Two legitimate requests with identical content/timestamps and no response ID.
  assert.deepEqual(buildSubagentMetrics(run([a, structuredClone(a)])).usage, usage(2));
  const withId = assistant(1, { responseId: "response-1" });
  assert.deepEqual(buildSubagentMetrics(run([withId, structuredClone(withId)])).usage, usage(1));
  assert.deepEqual(buildSubagentMetrics(run([withId, { ...withId, model: "other" }])).usage, usage(2));
});

test("child nested usage is included once, pending snapshots are not charged", () => {
  const childResult = { role: "toolResult", toolCallId: "nested-parent", toolName: "codemode", usage: usage(3), content: [], isError: false, timestamp: 1000 };
  const metrics = buildSubagentMetrics(run([assistant(1), childResult, structuredClone(childResult), assistant(100, { stopReason: "pending" })]));
  assert.deepEqual(metrics.usage, usage(4));
  assert.equal(metrics.cost.amount, 16);
  assert.equal(buildSubagentMetrics(run([])), undefined);
  assert.deepEqual(buildSubagentMetrics(run([], { agentEndMessage: assistant(2) })).usage, usage(2));
  assert.deepEqual(sumUsages([metrics.usage, usage(2), undefined]), usage(6));
  assert.equal(sumUsages([undefined]), undefined);
  const a = assistant(1);
  assert.deepEqual(buildSubagentMetrics(run([], { agentEndMessages: [a, structuredClone(a)], agentEndMessage: structuredClone(a) })).usage, usage(2));
  assert.deepEqual(buildSubagentMetrics(run([a], { agentEndMessages: [a, assistant(2)] })).usage, usage(3));
});

function registry(response, seen) {
  return { streamSimple(model, context, options) {
    seen.push({ model, context, options });
    return { async *[Symbol.asyncIterator]() { yield { type: "text_delta", delta: "report" }; }, async result() { return response; } };
  } };
}

test("reviewer request is no-tools, registry-authenticated, and retains error/abort usage", async () => {
  for (const stopReason of ["stop", "error", "aborted"]) {
    const seen = [], controller = new AbortController(), phases = [];
    const response = assistant(2, { stopReason });
    const result = await runReviewerRequest(registry(response, seen), { provider: "test", id: "model" }, "high", "review system", "diff", controller.signal, (phase) => phases.push(phase));
    assert.deepEqual(seen[0].context.tools, []);
    assert.equal(seen[0].context.systemPrompt, "review system");
    assert.equal(seen[0].options.signal, controller.signal);
    assert.equal(seen[0].options.reasoning, "high");
    assert.equal(seen[0].options.apiKey, undefined);
    assert.deepEqual(result.messages, [response]);
    assert.deepEqual(buildSubagentMetrics(result).usage, usage(2));
    assert.deepEqual(phases, ["thinking", "responding"]);
    assert.equal(result.exitCode, stopReason === "stop" ? 0 : 1);
  }
  const controller = new AbortController(); controller.abort();
  await assert.rejects(runReviewerRequest({ streamSimple() { assert.fail("must not run"); } }, {}, "high", "", "", controller.signal), { name: "AbortError" });
});

test("review tool preserves stage/scoped model selection and handles terminal failures without losing usage", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pi-review-test-"));
  try {
    execFileSync("git", ["init", "-q", directory]);
    await writeFile(join(directory, "change.ts"), "test change\n");
    const api = mockApi();
    (await importExtension("reviewer-subagent.ts")).default(api);
    const tool = api.tools.get("review_changes");
    const active = { provider: "test", id: "active" }, cheap = { provider: "github-copilot", id: "gpt-6-luna" };
    const seen = [];
    const ctx = { cwd: directory, model: active, scopedModels: [], ui: { theme: theme() },
      sessionManager: { getSessionFile: () => "test-session", buildSessionProjection: () => ({ messages: [] }) },
      modelRegistry: { getAvailable: () => [active, cheap], ...registry(assistant(2), seen) } };
    let updates = [];
    const result = await tool.execute("call", { stage: "interim" }, undefined, (u) => updates.push(u), ctx);
    assert.equal(seen[0].model, cheap);
    assert.equal(seen[0].options.reasoning, "minimal");
    assert.deepEqual(result.usage, usage(2));
    assert.equal(result.isError, false);
    assert.equal(result.details.stage, "interim");
    assert.ok(updates.every((u) => "details" in u));
    for (const stopReason of ["error", "aborted", "stop"]) {
      seen.length = 0;
      ctx.scopedModels = [{ model: active, thinkingLevel: "low" }];
      ctx.modelRegistry.streamSimple = registry(assistant(1, { stopReason, content: stopReason === "stop" ? [] : [{ type: "text", text: "partial text" }] }), seen).streamSimple;
      const failure = await tool.execute("call", { stage: "final" }, undefined, undefined, ctx);
      assert.equal(seen[0].model, active);
      assert.equal(seen[0].options.reasoning, "low");
      assert.equal(failure.isError, true);
      assert.deepEqual(failure.usage, usage(1));
      assert.doesNotMatch(failure.content[0].text, /partial text/);
    }
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test("session shutdown cancels an in-process reviewer and rejects stale completion", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pi-review-cancel-"));
  try {
    execFileSync("git", ["init", "-q", directory]);
    await writeFile(join(directory, "change.ts"), "change\n");
    const api = mockApi(); (await importExtension("reviewer-subagent.ts")).default(api);
    const model = { provider: "test", id: "model" };
    let started, activeSignal;
    const start = new Promise((resolve) => { started = resolve; });
    const context = { cwd: directory, model, scopedModels: [],
      sessionManager: { getSessionFile: () => "session", buildSessionProjection: () => ({ messages: [] }) },
      modelRegistry: { getAvailable: () => [model], streamSimple(_model, _context, { signal }) {
        activeSignal = signal;
        const result = new Promise((resolve) => signal.addEventListener("abort", () => resolve(assistant(1, { stopReason: "aborted" })), { once: true }));
        started();
        return { async *[Symbol.asyncIterator]() { await result; }, result: () => result };
      } } };
    const pending = api.tools.get("review_changes").execute("call", {}, undefined, undefined, context);
    await start;
    await api.emit("session_shutdown", {}, context);
    assert.equal(activeSignal.aborted, true);
    await assert.rejects(pending, /session was replaced/);
    assert.equal(api.messages.length, 0);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
