import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { getEventListeners } from "node:events";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { importExtension, mockApi, theme } from "./pi-test-helpers.mjs";

const home = await mkdtemp(join(tmpdir(), "pi-fixture-process-"));
const previousHome = process.env.HOME;
process.env.HOME = home;
const workflow = await importExtension("lib/workflow-mode.ts");
const supervisor = await importExtension("supervisor-worker.ts");
process.env.HOME = previousHome;
const runtime = await importExtension("lib/subagent-runtime.ts");
const launcher = join(home, "fixture.mjs");
const previousLauncher = process.env.PI_SUBAGENT_CLI;
process.env.PI_SUBAGENT_CLI = launcher;
after(async () => {
  if (previousLauncher === undefined) delete process.env.PI_SUBAGENT_CLI;
  else process.env.PI_SUBAGENT_CLI = previousLauncher;
  await rm(home, { recursive: true, force: true });
});
// This child is only a scripted JSON fixture. It never loads Pi, executes tools, or contacts a provider.
await writeFile(launcher, `import { readFileSync, writeFileSync, statSync } from "node:fs";
import { pathToFileURL } from "node:url";
const args = process.argv.slice(2), task = args.at(-1), emit = event => process.stdout.write(JSON.stringify(event)+"\\n");
let config, mode;
const extension = args[args.indexOf("-e") + 1];
if (args.includes("-e")) {
  mode = statSync(extension).mode & 0o777;
  (await import(pathToFileURL(extension))).default({ registerProvider: (_provider, value) => { config = value; } });
}
let n = 1;
if (process.env.FIXTURE_COUNTER) {
  try { n = Number(readFileSync(process.env.FIXTURE_COUNTER, "utf8")) + 1; } catch {}
  writeFileSync(process.env.FIXTURE_COUNTER, String(n));
}
const usage = {input:n,output:n,cacheRead:0,cacheWrite:0,totalTokens:n*2,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:n}};
const msg = (content, stopReason = "stop") => ({role:"assistant",provider:"test",model:"fixture",api:"fixture",timestamp:n,usage,stopReason,content});
emit({type:"tool_execution_start",toolCallId:"fixture-call",toolName:"bash",args:{command:"fixture only"}});
const finish = () => {
  emit({type:"tool_execution_end",toolCallId:"fixture-call",toolName:"bash",result:{content:[{type:"text",text:"fixture result"}],details:{config,mode,env:process.env.FIXTURE_ENV,noTools:args.includes("--no-tools")}},isError:false});
  const message = msg(task.includes("retry-fixture") && n === 1 ? [] : [{type:"text",text:"## Status\\n- completed"}]);
  emit({type:"message_end",message});
  if (task.includes("abort-fixture")) emit({type:"message_end",message:msg([],"aborted")});
  else { emit({type:"turn_end",message}); emit({type:"agent_end",messages:[message]}); }
};
if (task.includes("delay-fixture")) setTimeout(finish, 10000);
else finish();
`, "utf8");

const ctx = () => ({ cwd: home, mode: "rpc", hasUI: true, model: { provider: "test", id: "fixture" }, scopedModels: [],
  ui: { theme: theme(), notify() {}, setStatus() {}, setWidget() {} }, getSystemPrompt: () => "fixture instructions",
  sessionManager: { getSessionFile: () => "fixture-session", getBranch: () => [], buildSessionProjection: () => ({ messages: [] }) },
  modelRegistry: { getAvailable: () => [{ provider: "test", id: "fixture" }],
    getApiKeyAndHeaders: async () => ({ ok: true }), isUsingOAuth: () => false } });

test("JSON fixture preserves auth metadata, event errors are visible, and abort listeners are released", async () => {
  const controller = new AbortController();
  const run = await runtime.runSubagentProcess({ cwd: home, prompt: "fixture", modelArg: "test/fixture", systemPrompt: "fixture",
    providerName: "test", authHeaders: { remove: null, keep: "fixture" }, authBaseUrl: "https://fixture.invalid",
    authEnv: { FIXTURE_ENV: "present" }, extraArgs: ["--no-tools"], signal: controller.signal,
    onEvent(event) {
      if (event.type === "tool_execution_end") {
        assert.deepEqual(event.result.details.config, { headers: { remove: null, keep: "fixture" }, baseUrl: "https://fixture.invalid" });
        assert.equal(event.result.details.mode, 0o600);
        assert.equal(event.result.details.env, "present");
        assert.equal(event.result.details.noTools, true);
      }
    },
  });
  assert.equal(run.exitCode, 0);
  assert.equal(runtime.buildSubagentMetrics(run).usage.cost.total, 1, "repeated terminal envelopes charged once");
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
  const failure = await runtime.runSubagentProcess({ cwd: home, prompt: "fixture", modelArg: "test/fixture", systemPrompt: "fixture",
    onEvent() { throw new Error("fixture consumer failure"); } });
  assert.equal(failure.exitCode, 1); assert.equal(failure.stopReason, "error");
  assert.match(failure.errorMessage, /fixture consumer failure/);
});

test("worker/scout fixture callbacks populate live activity and terminal failure is authoritative", async () => {
  execFileSync("git", ["init", "-q", home]);
  await workflow.writeWorkflowMode("three-tier");
  const api = mockApi(); supervisor.default(api);
  const context = ctx();
  await api.emit("session_start", {}, context);
  let sawLiveTool = false;
  api.events.on("subagent:metrics", (event) => assert.equal(event.id, "fixture-parent"));
  const result = await api.tools.get("delegate_worker").execute("fixture-parent", { objective: "fixture", tools: [], validationCommands: [] },
    undefined, (update) => { if (update.content[0]?.text?.includes("bash")) sawLiveTool = true; }, context);
  assert.equal(result.isError, false); assert.equal(result.details.status, "completed");
  assert.equal(result.usage.cost.total, 1); assert.equal(result.details.id, "fixture-parent");
  assert.equal(sawLiveTool, true, "the formerly out-of-scope callback reaches the activity recorder");
  const failure = await api.tools.get("delegate_scout").execute("fixture-parent", { objective: "abort-fixture", tools: ["read"] },
    undefined, undefined, context);
  assert.equal(failure.isError, true); assert.equal(failure.details.status, "blocked");
  assert.equal(failure.usage.cost.total, 2, "history text does not hide an aborted response's usage");
  await api.emit("session_shutdown", {}, context);
});

test("worker fixture retry usage reaches native results", async () => {
  await workflow.writeWorkflowMode("three-tier");
  const counter = join(home, "retry.counter");
  const api = mockApi(); supervisor.default(api);
  const context = ctx(); await api.emit("session_start", {}, context);
  const previous = process.env.FIXTURE_COUNTER; process.env.FIXTURE_COUNTER = counter;
  try {
    const result = await api.tools.get("delegate_worker").execute("retry-parent", { objective: "retry-fixture", tools: [], validationCommands: [] },
      undefined, undefined, context);
    assert.equal(result.isError, false); assert.equal(result.usage.cost.total, 3);
  } finally {
    if (previous === undefined) delete process.env.FIXTURE_COUNTER; else process.env.FIXTURE_COUNTER = previous;
    await api.emit("session_shutdown", {}, context);
  }
});

test("branch replacement cancels fixture processes and suppresses all late logs/metrics", async () => {
  await workflow.writeWorkflowMode("three-tier");
  const api = mockApi(); supervisor.default(api);
  const context = ctx(); await api.emit("session_start", {}, context);
  let ready; const started = new Promise(resolve => { ready = resolve; });
  const metrics = []; api.events.on("subagent:metrics", event => metrics.push(event));
  const pending = api.tools.get("delegate_worker").execute("stale-parent", { objective: "delay-fixture", tools: [], validationCommands: [] }, undefined,
    (update) => { if (update.content[0]?.text?.includes("bash")) ready(); }, context);
  const rejected = assert.rejects(pending, /session was replaced/);
  await started; await api.emit("session_tree", {}, context);
  const entryCount = api.entries.length;
  await rejected;
  assert.equal(api.entries.length, entryCount); assert.equal(metrics.length, 0);
  await api.emit("session_shutdown", {}, context);
});
