import { packageDir } from "./pi-test-helpers.mjs";
import assert from "node:assert/strict";
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const extensionsDir = resolve("home/.pi/agent/extensions");

test("all custom extensions and builtin codemode load with Pi 1.1+ in headless mode", async () => {
  const pkg = JSON.parse(await (await import("node:fs/promises")).readFile(join(packageDir, "package.json"), "utf8"));
  assert.ok(Number(pkg.version.split(".")[0]) > 1 || (pkg.version.startsWith("1.") && Number(pkg.version.split(".")[1]) >= 1), "requires Pi 1.1+");

  const { createAgentSession, DefaultResourceLoader, SessionManager, createCodemodeExtension, SettingsManager, ModelRuntime } = await import(
    pathToFileURL(join(packageDir, "dist/index.js")).href
  );
  const paths = readdirSync(extensionsDir, { withFileTypes: true })
    .filter((entry) => (entry.isFile() && entry.name.endsWith(".ts")) || (entry.isDirectory() && entry.name === "statusline"))
    .map((entry) => join(extensionsDir, entry.name));
  const agentDir = mkdtempSync(join(tmpdir(), "pi-100-extensions-"));
  let session;
  try {
    const loader = new DefaultResourceLoader({ cwd: process.cwd(), agentDir, settingsManager: SettingsManager.inMemory(), noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true, additionalExtensionPaths: paths, extensionFactories: [createCodemodeExtension()] });
    await loader.reload();
    const loaded = loader.getExtensions();
    assert.deepEqual(loaded.errors, []);
    assert.equal(loaded.extensions.length, paths.length + 1);
    assert.equal(loaded.extensions.flatMap((extension) => [...extension.tools.keys()]).filter((name) => name === "codemode").length, 1);

    const manager = SessionManager.inMemory();
    const ai = await import(pathToFileURL(resolve(packageDir, "../pi-ai/dist/index.js")));
    const faux = ai.fauxProvider({ provider: "extension-smoke", models: [{ id: "offline" }], tokensPerSecond: 100000 });
    faux.setResponses([(request) => {
      assert.match(ai.getCurrentSystemPrompt(request.messages), /Never read/);
      return ai.fauxAssistantMessage("Offline extension smoke complete.");
    }]);
    const modelRuntime = await ModelRuntime.create({ authPath: join(agentDir, "auth.json"), modelsPath: null, allowModelNetwork: false, refreshOnCreate: false });
    modelRuntime.registerNativeProvider(faux.provider);
    ({ session } = await createAgentSession({
      cwd: process.cwd(), agentDir, resourceLoader: loader, sessionManager: manager,
      modelRuntime, model: faux.getModel(),
      settingsManager: SettingsManager.inMemory(),
    }));
    const errors = [];
    await session.bindExtensions({ mode: "print", onError: (error) => errors.push(error) });
    assert.deepEqual(errors, []);

    // Exercise real lifecycle/prompt construction through public APIs and an offline faux stream.
    await session.prompt("hello");
    const systemMessage = session.messages.find((message) => message.role === "system");
    assert.match(systemMessage.sections.secret_file_guard, /Never read/);
    assert.match(systemMessage.sections.workflow_policy, /Workflow Policy|Delegation Policy/);
    assert.deepEqual(errors, []);
    // Pi's own session totals must account for native tool-result usage.
    const usage = { input: 10, output: 5, cacheRead: 2, cacheWrite: 3, totalTokens: 20,
      cost: { input: 0.01, output: 0.02, cacheRead: 0, cacheWrite: 0, total: 0.03 } };
    const before = session.getSessionStats();
    manager.appendMessage({ role: "toolResult", toolName: "review_changes", toolCallId: "test-review",
      content: [{ type: "text", text: "offline review" }], details: {}, usage, isError: false, timestamp: Date.now() });
    const stats = session.getSessionStats();
    assert.equal(stats.cost, before.cost + 0.03);
    assert.equal(stats.tokens.input, before.tokens.input + 10);
    assert.equal(stats.tokens.output, before.tokens.output + 5);
  } finally {
    session?.dispose();
    rmSync(agentDir, { recursive: true, force: true });
  }
});

test("dynamic policies use separate structured sections rather than replacing the prompt", async () => {
  const { readFile } = await import("node:fs/promises");
  for (const [file, section] of [
    ["block-dotenv-read.ts", "secret_file_guard"],
    ["supervisor-worker.ts", "workflow_policy"],
  ]) {
    const source = await readFile(join(extensionsDir, file), "utf8");
    assert.match(source, new RegExp(`event\\.systemPromptOptions\\.sections\\.${section}\\s*=`));
    assert.doesNotMatch(source, /systemPrompt: `\$\{event\.systemPrompt\}/);
  }
});
