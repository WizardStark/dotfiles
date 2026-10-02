import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readdirSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const extensionsDir = resolve("home/.pi/agent/extensions");

test("all custom extensions load and start with Pi 1.0 in headless mode", async (t) => {
  const piBinary = execFileSync("which", ["pi"], { encoding: "utf8" }).trim();
  const packageDir = resolve(dirname(realpathSync(piBinary)), "../..");
  const pkg = JSON.parse(await (await import("node:fs/promises")).readFile(join(packageDir, "package.json"), "utf8"));
  if (pkg.version !== "1.0.0") return t.skip("requires Pi 1.0.0");

  const { createAgentSession, DefaultResourceLoader, SessionManager } = await import(
    pathToFileURL(join(packageDir, "dist/index.js")).href
  );
  const paths = readdirSync(extensionsDir, { withFileTypes: true })
    .filter((entry) => (entry.isFile() && entry.name.endsWith(".ts")) || (entry.isDirectory() && entry.name === "statusline"))
    .map((entry) => join(extensionsDir, entry.name));
  const agentDir = mkdtempSync(join(tmpdir(), "pi-100-extensions-"));
  let session;
  try {
    const loader = new DefaultResourceLoader({ cwd: process.cwd(), agentDir, additionalExtensionPaths: paths });
    await loader.reload();
    const loaded = loader.getExtensions();
    assert.deepEqual(loaded.errors, []);
    assert.equal(loaded.extensions.length, paths.length);

    ({ session } = await createAgentSession({
      cwd: process.cwd(), resourceLoader: loader, sessionManager: SessionManager.inMemory(),
    }));
    const errors = [];
    await session.bindExtensions({ mode: "print", onError: (error) => errors.push(error) });
    assert.deepEqual(errors, []);

    // Exercise the hook against Pi's real prompt builder, without making a model call.
    const { systemPromptOptions } = await session._extensionRunner.emitBeforeAgentStart(
      "hello", undefined, { cwd: process.cwd() },
    );
    assert.equal(systemPromptOptions.forceSystemPrompt, undefined);
    assert.match(systemPromptOptions.sections.secret_file_guard, /Never read/);
    assert.match(systemPromptOptions.sections.workflow_policy, /Workflow Policy|Delegation Policy/);
    assert.deepEqual(errors, []);
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
