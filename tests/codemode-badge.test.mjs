import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { codemodeTreeEntries } from "../home/.pi/agent/extensions/lib/codemode-badge-label.ts";

const root = new URL("../home/.pi/agent/", import.meta.url);

const call = (name, status = "ok", args = '{"path":"private/file.py","offset":283,"limit":79}') => ({ name, args, status });

test("codemode badge groups tools in first-seen order without argument previews", () => {
  const calls = [call("read"), call("bash", "ok", '{"command":"echo private"}'), call("edit"),
    ...Array.from({ length: 5 }, () => call("read")), call("bash", "running", '{"command":"long...')];
  assert.deepEqual(codemodeTreeEntries(calls, false), [
    { branch: "├─", label: "read x6", tone: "toolOutput" },
    { branch: "├─", label: "bash x2", tone: "toolOutput" },
    { branch: "└─", label: "edit", tone: "toolOutput" },
  ]);
  assert.equal(codemodeTreeEntries([call("models.classify", "ok", "")], false)[0].label, "models.classify");
  assert.equal(codemodeTreeEntries(Array.from({ length: 20 }, () => call("read")), false)[0].label, "read x20");
});

test("grouped nested calls retain failures and a bounded tree", () => {
  assert.deepEqual(codemodeTreeEntries([call("bash")], true).map(({ branch, label }) => `${branch} ${label}`), [
    "├─ bash", "└─ ⚠ codemode failed (expand for details)",
  ]);
  assert.deepEqual(codemodeTreeEntries([call("bash", "error"), call("bash")], true), [
    { branch: "└─", label: "bash x2 ⚠ failed", tone: "error" },
  ]);
  assert.deepEqual(codemodeTreeEntries([], false), []);
  assert.equal(codemodeTreeEntries([], true)[0].tone, "error");
  const calls = Array.from({ length: 20 }, (_, i) => call(`tool${i}`));
  const many = codemodeTreeEntries(calls, false);
  assert.equal(many.length, 12);
  assert.match(many[0].label, /9 earlier tools/);
  assert.equal(many.at(-1).branch, "└─");
  assert.equal(many.at(-1).label, "tool19");
  // A failure in an omitted group must still be visible.
  calls[0].status = "error";
  assert.equal(codemodeTreeEntries(calls, true).at(-1).tone, "error");
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
  const collapsed = renderContext();
  const result = { content: [{ type: "text", text: "private output" }], details: {
    calls: [call("read"), call("bash"), call("read"), call("edit")],
  } };
  const output = renderer.renderResult(result, { expanded: false, isPartial: false }, theme(), collapsed).render(80).map((line) => line.trimEnd()).join("\n");
  assert.match(output, /├─ read x2\n├─ bash\n└─ edit/);
  assert.doesNotMatch(output, /private|path|offset|limit|command/);
  assert.equal(calls, 2);
  assert.match(renderer.renderResult(result, { expanded: true, isPartial: false }, theme(), collapsed).render(80).join("\n"), /native result/);
  const settings = JSON.parse(await readFile(new URL("settings.json", root), "utf8"));
  assert.ok(settings.defaultTools.includes("+codemode"));
  assert.ok(!settings.extensions.includes("-builtin:codemode"));
});
