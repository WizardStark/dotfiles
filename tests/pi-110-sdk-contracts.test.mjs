import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";
import { packageDir, piSdk } from "./pi-test-helpers.mjs";

// Real installed SDK, explicit faux provider, disposable resources: no private session fields or credentials.
test("public SDK propagates nested usage once across parallel structured calls and permission hooks", async () => {
  const sdk = await piSdk();
  const nodeModules = resolve(packageDir, "../..");
  const ai = await import(pathToFileURL(join(nodeModules, "@earendil-works/pi-ai/dist/index.js")));
  const { Type } = await import(pathToFileURL(join(nodeModules, "typebox/build/index.mjs")));
  const directory = await mkdtemp(join(tmpdir(), "pi-public-sdk-"));
  let session;
  try {
    const faux = ai.fauxProvider({ provider: "audit-offline", models: [{ id: "fixture" }], tokensPerSecond: 100000 });
    faux.setResponses([
      ai.fauxAssistantMessage(ai.fauxToolCall("fixture_parent", {}, { id: "parent" }), { stopReason: "toolUse" }),
      ai.fauxAssistantMessage("offline done"),
    ]);
    const modelRuntime = await sdk.ModelRuntime.create({ authPath: join(directory, "auth.json"), modelsPath: null,
      allowModelNetwork: false, refreshOnCreate: false });
    modelRuntime.registerNativeProvider(faux.provider);
    const hooks = [], updates = [], events = [];
    const usage = n => ({ input: n, output: n, cacheRead: 0, cacheWrite: 0, totalTokens: n * 2,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: n } });
    const resourceLoader = new sdk.DefaultResourceLoader({ cwd: directory, agentDir: directory,
      settingsManager: sdk.SettingsManager.inMemory(), noExtensions: true, noSkills: true,
      noPromptTemplates: true, noThemes: true, noContextFiles: true,
      extensionFactories: [pi => {
        pi.on("tool_call", event => {
          hooks.push({ type: event.type, id: event.toolCallId, parent: event.parentToolCallId });
          if (event.input.n === 99) return { block: true, reason: "fixture permission denied" };
        });
        pi.on("tool_result", event => { hooks.push({ type: event.type, id: event.toolCallId, parent: event.parentToolCallId }); });
        pi.registerTool({ name: "fixture_child", label: "Fixture child", description: "Offline fixture",
          parameters: Type.Object({ n: Type.Number() }), outputSchema: Type.Object({ value: Type.Number() }),
          async execute(_id, { n }) { return { content: [{ type: "text", text: "fixture" }], structuredContent: { value: n }, details: undefined, usage: usage(n) }; } });
        pi.registerTool({ name: "fixture_parent", exposure: "model-only", label: "Fixture parent", description: "Offline nesting fixture",
          parameters: Type.Object({}), async execute(_id, _params, signal, onUpdate, ctx) {
            assert.ok(!ctx.tools.some(tool => tool.name === "fixture_parent"), "model-only tool is not nested-callable");
            const results = await Promise.all([ctx.executeTool("fixture_child", { n: 2 }, { signal }), ctx.executeTool("fixture_child", { n: 3 }, { signal })]);
            assert.deepEqual(results.map(result => result.result.structuredContent), [{ value: 2 }, { value: 3 }]);
            const blocked = await ctx.executeTool("fixture_child", { n: 99 }, { signal });
            assert.equal(blocked.isError, true);
            const invalid = await ctx.executeTool("fixture_child", { n: "invalid" }, { signal });
            assert.equal(invalid.isError, true);
            onUpdate?.({ content: [{ type: "text", text: "partial fixture" }], details: undefined });
            return { content: [{ type: "text", text: "done" }], details: undefined, usage: usage(1) };
          } });
      }],
    });
    await resourceLoader.reload();
    ({ session } = await sdk.createAgentSession({ cwd: directory, agentDir: directory, modelRuntime, model: faux.getModel(),
      resourceLoader, sessionManager: sdk.SessionManager.inMemory(directory), thinkingLevel: "off", tools: ["fixture_parent", "fixture_child"],
      settingsManager: sdk.SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } }) }));
    await session.bindExtensions({ mode: "print" });
    session.subscribe(event => { events.push(event.type); if (event.type === "tool_execution_update") updates.push(event.partialResult); });
    await session.prompt("Offline SDK contract fixture");
    const results = session.messages.filter(message => message.role === "toolResult");
    assert.equal(results.length, 1, "children are not separate transcript results");
    assert.equal(results[0].usage.cost.total, 6); assert.equal(results[0].usage.input, 6);
    assert.equal(results[0].nestedCalls.calls.length, 4);
    assert.equal(session.getSessionStats().cost, 6);
    assert.ok(hooks.some(event => event.type === "tool_call" && event.parent === "parent"));
    assert.ok(hooks.some(event => event.type === "tool_result" && event.parent === "parent"));
    assert.match(updates.at(-1).content[0].text, /partial fixture/);
    assert.equal(events.at(-1), "agent_settled");
  } finally {
    session?.dispose();
    await rm(directory, { recursive: true, force: true });
  }
});
