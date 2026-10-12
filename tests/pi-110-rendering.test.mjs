import assert from "node:assert/strict";
import { test } from "node:test";
import { importExtension, mockApi, renderContext, theme, tuiSdk } from "./pi-test-helpers.mjs";
const { Text, visibleWidth } = await tuiSdk();
const { compactRenderers } = await importExtension("lib/compact-tool-renderers.ts");
const { domainRenderers } = await importExtension("lib/domain-tool-renderers.ts");

for (const file of ["tool-badges.ts", "codemode-badge.ts"]) {
  test(`${file} only registers renderers and composes native expansion`, async () => {
    const api = mockApi();
    (await importExtension(file)).default(api);
    assert.equal(api.tools.size, 0);
    const name = file.startsWith("codemode") ? "codemode" : "read";
    const args = { path: "测试.ts" }, result = { content: [{ type: "text", text: "native result" }], details: { diff: "diff" } };
    const calls = [];
    const native = {
      renderCall(a, _theme, c) { calls.push(["call", a, c]); return new Text("native call", 0, 0); },
      renderResult(r, o, _theme, c) { calls.push(["result", r, o, c]); return new Text("native diff/image/error result", 0, 0); },
    };
    const renderer = api.renderers[0](name, () => native);
    assert.equal(api.renderers[0]("unrelated", () => native), native);
    const context = renderContext({ expanded: true, outputPad: 1 });
    const call = renderer.renderCall(args, theme(), context);
    const rendered = renderer.renderResult(result, { expanded: true, isPartial: false }, theme(), context);
    assert.equal(calls[0][1], args);
    assert.equal(calls[1][1], result);
    assert.match(call.render(50).join("\n"), /native call/);
    assert.match(rendered.render(50).join("\n"), /native diff\/image\/error result/);
    assert.equal(call.render(50)[0].indexOf("native call"), 1);
    assert.equal(renderer.renderCall(args, theme(), { ...context, lastComponent: call }), call);
  });
}

test("compact rendering uses recorded zero/unknown durations, padding, partial state, and component reuse", () => {
  const renderer = compactRenderers("read");
  const ctx = renderContext({ durationMs: 0, outputPad: 1 });
  const first = renderer.renderCall({}, theme(), ctx);
  assert.match(first.render(60).join("\n"), /done · 0ms/);
  assert.equal(first.render(60)[0].indexOf(" read"), 1);
  const second = renderer.renderCall({}, theme("new:"), { ...ctx, lastComponent: first, durationMs: undefined, isPartial: true });
  assert.equal(first, second);
  assert.match(second.render(60).join("\n"), /new:.*running/);
  assert.doesNotMatch(second.render(60).join("\n"), /0ms/);
  const text = Array.from({ length: 80 }, (_, i) => `line ${i}`).join("\n");
  const expanded = renderer.renderResult({ content: [{ type: "text", text }] }, { expanded: true, isPartial: false }, theme(), ctx);
  assert.match(expanded.render(50).join("\n"), /line 79/);
});

test("self-shell native renderers own their padding, and results remain unchanged", () => {
  const native = { renderShell: "self", renderCall: (_a, _t, c) => new Text("native", c.outputPad, 0) };
  const component = compactRenderers("read", native).renderCall({}, theme(), renderContext({ expanded: true, outputPad: 1 }));
  assert.equal(component.render(30)[0].indexOf("native"), 1);
});

test("domain views summarize answers, review, advisor and delegation without mutating details", () => {
  const cases = [
    ["question", { answers: [{ header: "范围", answer: "测试 ✅" }], cancelled: true }, /范围: 测试 ✅/],
    ["review", { reviewer: "test/model", changedFiles: ["a", "b"] }, /2 changed files/],
    ["advisor", { advisor: "test/astra" }, /task packet ready/],
    ["delegation", { status: "blocked", totalCount: 3, completedCount: 2 }, /2\/3 completed/],
  ];
  for (const [kind, details, expected] of cases) {
    const renderer = domainRenderers(kind, kind);
    const result = { content: [{ type: "text", text: "report body" }], details };
    const before = JSON.stringify(result);
    const ctx = renderContext({ outputPad: 1 });
    const component = renderer.renderResult(result, { expanded: false, isPartial: false }, theme(), ctx);
    assert.match(component.render(100).join("\n"), expected);
    for (const line of component.render(12)) assert.ok(visibleWidth(line) <= 12);
    const updated = renderer.renderResult(result, { expanded: true, isPartial: false }, theme("changed:"), { ...ctx, lastComponent: component });
    assert.equal(updated, component);
    assert.match(updated.render(100).join("\n"), /report body/);
    assert.match(updated.render(100).join("\n"), /changed:/);
    assert.equal(JSON.stringify(result), before);
  }
});

test("legacy and partial domain results expose progress and full error text", () => {
  const renderer = domainRenderers("delegation", "Worker");
  const ctx = renderContext({ isPartial: true });
  const partial = renderer.renderResult({ content: [], details: { phase: "finalizing", currentTool: "test" } }, { expanded: false, isPartial: true }, theme(), ctx);
  assert.match(partial.render(100).join("\n"), /finalizing.*test/);
  const error = renderer.renderResult({ content: [{ type: "text", text: "Bad result\nFull cause" }] }, { expanded: true, isPartial: false }, theme(), renderContext({ isError: true, lastComponent: partial }));
  assert.match(error.render(100).join("\n"), /Full cause/);
});

test("real Pi native bash/read/edit definitions retain their expanded diagnostics", async () => {
  const { piSdk, packageDir } = await import("./pi-test-helpers.mjs");
  const sdk = await piSdk();
  sdk.initTheme("dark", false);
  const { pathToFileURL } = await import("node:url");
  const { theme: actualTheme } = await import(pathToFileURL(`${packageDir}/dist/modes/interactive/theme/theme.js`));
  for (const definition of [sdk.createBashToolDefinition(process.cwd()), sdk.createReadToolDefinition(process.cwd()), sdk.createEditToolDefinition(process.cwd())]) {
    const args = definition.name === "bash" ? { command: "printf diagnostic" } : { path: "diagnostic.ts", edits: [{ oldText: "old", newText: "new" }] };
    const ctx = renderContext({ expanded: true, argsComplete: false, outputPad: 1, args, durationMs: 5 });
    const renderers = compactRenderers(definition.name, definition);
    const callComponent = renderers.renderCall(args, actualTheme, ctx);
    assert.match(callComponent.render(80).join("\n"), definition.name === "bash" ? /printf diagnostic/ : /diagnostic\.ts/);
    const result = { content: [{ type: "text", text: "diagnostic result" }], details: definition.name === "edit" ? { diff: "-1 old\n+1 new", firstChangedLine: 1 } : {} };
    const collapsed = renderers.renderResult(result, { expanded: false, isPartial: false }, actualTheme, { ...ctx, expanded: false });
    const expanded = renderers.renderResult(result, { expanded: true, isPartial: false }, actualTheme, { ...ctx, lastComponent: collapsed });
    const view = expanded.render(80).join("\n");
    assert.equal(renderers.renderResult(result, { expanded: true, isPartial: false }, actualTheme, { ...ctx, lastComponent: expanded }), expanded);
    assert.match(callComponent.render(80).join("\n") + view, definition.name === "edit" ? /new/ : /diagnostic result/);
  }
});
