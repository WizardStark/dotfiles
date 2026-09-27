import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const home = await mkdtemp(join(tmpdir(), "pi-workflow-mode-"));
const originalHome = process.env.HOME;
process.env.HOME = home;
const { isWorkflowMode, readWorkflowMode, writeWorkflowMode } = await import("../home/.pi/agent/extensions/lib/workflow-mode.ts");
process.env.HOME = originalHome;

const config = join(home, ".pi", "agent", "workflow-mode.json");

test("workflow modes round-trip and invalid preferences fall back to guided", async () => {
  try {
    assert.equal(await readWorkflowMode(), "guided");
    for (const mode of ["plain", "guided", "three-tier"]) {
      assert.equal(isWorkflowMode(mode), true);
      await writeWorkflowMode(mode);
      assert.equal(await readWorkflowMode(), mode);
      assert.deepEqual(JSON.parse(await readFile(config, "utf8")), { mode });
    }
    for (const mode of ["unknown", 123, null]) assert.equal(isWorkflowMode(mode), false);
    await mkdir(join(home, ".pi", "agent"), { recursive: true });
    await writeFile(config, '{"mode":"unknown"}');
    assert.equal(await readWorkflowMode(), "guided");
    await writeFile(config, "not json");
    assert.equal(await readWorkflowMode(), "guided");
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});
