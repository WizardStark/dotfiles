import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { importExtension, mockApi, piSdk, theme } from "./pi-test-helpers.mjs";

const supervisor = await importExtension("supervisor-worker.ts");
const { SessionManager } = await piSdk();
const main = { provider: "test", id: "main" };
const worker = { provider: "test", id: "worker" };
const scout = { provider: "test", id: "scout" };

async function withSession(directory, run, legacyState) {
  const api = mockApi();
  supervisor.default(api);
  const notices = [];
  const sessionManager = SessionManager.inMemory(directory);
  if (legacyState) sessionManager.appendCustomEntry("supervisor-worker-state", legacyState);
  const context = {
    cwd: directory, mode: "print", hasUI: false, model: main, scopedModels: [],
    modelRegistry: { getAvailable: () => [main, worker, scout] }, sessionManager,
    ui: { theme: theme(), setStatus() {}, setWidget() {}, notify: (...notice) => notices.push(notice) },
  };
  const command = async (role, args = "") => {
    await api.commands.get(`${role}-model`).handler(args, context);
    return notices.at(-1);
  };
  try {
    await api.emit("session_start", {}, context);
    await run(command, () => api.emit("session_tree", {}, context));
  } finally {
    await api.emit("session_shutdown", {}, context);
  }
}

test("delegation models and thinking levels persist across new sessions and explicit resets", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pi-delegation-models-"));
  const agentDir = join(directory, "agent");
  const config = join(agentDir, "delegation-models.json");
  const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = agentDir;
  try {
    await withSession(directory, async (command) => {
      assert.equal((await command("worker", "test/worker high"))[1], "info");
      assert.equal((await command("scout", "test/scout low"))[1], "info");
    });
    assert.deepEqual(JSON.parse(await readFile(config, "utf8")), {
      worker: { model: worker, thinkingLevel: "high" },
      scout: { model: scout, thinkingLevel: "low" },
    });
    await withSession(directory, async (command) => {
      assert.match((await command("worker"))[0], /test\/worker:high \(override\)/);
      assert.match((await command("scout"))[0], /test\/scout:low \(override\)/);
      assert.equal((await command("worker", "default medium"))[1], "info");
    });
    await withSession(directory, async (command, restoreTree) => {
      await restoreTree();
      assert.match((await command("worker"))[0], /test\/main:medium \(default\)/);
      assert.match((await command("scout"))[0], /test\/scout:low \(override\)/);
      assert.equal((await command("scout", "default"))[1], "info");
    }, { override: worker, thinkingLevel: "high" });
    assert.deepEqual(JSON.parse(await readFile(config, "utf8")), {
      worker: { model: null, thinkingLevel: "medium" },
      scout: { model: null, thinkingLevel: "minimal" },
    });
    await writeFile(config, "not valid JSON");
    await withSession(directory, async (command) => {
      assert.match((await command("scout"))[0], /test\/main:minimal \(default\)/);
      assert.equal((await command("scout", "test/scout low"))[1], "error");
      assert.match((await command("scout"))[0], /test\/main:minimal \(default\)/);
    });
    assert.equal(await readFile(config, "utf8"), "not valid JSON");
  } finally {
    if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
    await rm(directory, { recursive: true, force: true });
  }
});
