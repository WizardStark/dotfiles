import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { codemodeCallLabel, codemodeTreeEntries } from "../home/.pi/agent/extensions/lib/codemode-badge-label.ts";

const root = new URL("../home/.pi/agent/", import.meta.url);

test("codemode badge displays shell commands rather than scripts or JSON", () => {
  const bash = (command, status = "ok") => ({ name: "bash", args: JSON.stringify({ command, timeout: 60 }), status });
  assert.equal(codemodeCallLabel(bash("node --test tests/*.test.mjs")), "bash: node --test tests/*.test.mjs");
  assert.equal(codemodeCallLabel(bash("echo hi\n  && echo bye")), "bash: echo hi && echo bye");
  assert.equal(codemodeCallLabel(bash("exit 1", "error")), "bash: exit 1 ⚠ failed");
  assert.equal(codemodeCallLabel({ name: "models.classify", args: "", status: "ok" }), "models.classify");
  assert.equal(codemodeCallLabel({ name: "bash", args: '{"command":"long...', status: "running" }), 'bash: {"command":"long...');
});

test("nested calls form a bounded tree below the codemode badge", () => {
  const call = (i, status = "ok") => ({ name: "bash", args: JSON.stringify({ command: `echo ${i}` }), status });
  const pair = codemodeTreeEntries([call(1), call(2)], false);
  assert.deepEqual(pair.map(({ branch, label }) => `${branch} ${label}`), ["├─ bash: echo 1", "└─ bash: echo 2"]);
  assert.deepEqual(codemodeTreeEntries([call(1)], true).map(({ branch, label }) => `${branch} ${label}`), [
    "├─ bash: echo 1", "└─ ⚠ codemode failed (expand for details)",
  ]);
  assert.equal(codemodeTreeEntries([call(1, "error")], true).length, 1);
  assert.deepEqual(codemodeTreeEntries([], false), []);
  const many = codemodeTreeEntries(Array.from({ length: 20 }, (_, i) => call(i)), false);
  assert.equal(many.length, 12);
  assert.match(many[0].label, /9 earlier calls/);
  assert.equal(many.at(-1).branch, "└─");
  assert.equal(many.at(-1).label, "bash: echo 19");
});

test("codemode badge resolves builtin rendering without owning execution", async () => {
  const { importExtension, mockApi, renderContext, theme, tuiSdk } = await import("./pi-test-helpers.mjs");
  const { Text } = await tuiSdk();
  const api = mockApi();
  (await importExtension("codemode-badge.ts")).default(api);
  assert.equal(api.tools.size, 0);
  let calls = 0;
  const native = {
    renderCall: () => { calls++; return new Text("native call", 0, 0); },
    renderResult: () => { calls++; return new Text("native result", 0, 0); },
  };
  const resolve = api.renderers[0];
  assert.equal(resolve("other", () => native), native);
  const renderer = resolve("codemode", () => native);
  const ctx = renderContext({ expanded: true });
  assert.match(renderer.renderCall({}, theme(), ctx).render(80).join("\\n"), /native call/);
  assert.match(renderer.renderResult({ content: [], details: {} }, { expanded: true, isPartial: false }, theme(), ctx).render(80).join("\\n"), /native result/);
  assert.equal(calls, 2);
  const settings = JSON.parse(await readFile(new URL("settings.json", root), "utf8"));
  assert.ok(settings.defaultTools.includes("+codemode"));
  assert.ok(!settings.extensions.includes("-builtin:codemode"));
});
